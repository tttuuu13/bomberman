import Foundation
import Combine

class WebSocketService: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let serverURL = URL(string: "ws://localhost:8765")!

    private var _messages = PassthroughSubject<String, Error>()
    var messages: PassthroughSubject<String, Error> {
        _messages
    }

    func connect() {
        if webSocketTask != nil {
            print("Закрываем старое соединение перед новым подключением...")
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
            _messages = PassthroughSubject<String, Error>()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self._connect()
            }
        } else {
            _connect()
        }
    }
    
    private func _connect() {
        print("Connecting to \(serverURL)...")
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.listen()
        }
    }

    func disconnect() {
        print("Disconnecting...")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func listen() {
        guard let task = webSocketTask else {
            return
        }
        
        task.receive { [weak self] result in
            guard let self = self else { return }
            
            guard let currentTask = self.webSocketTask, currentTask === task else {
                return
            }
            
            switch result {
            case .failure(let error):
                let errorCode = (error as NSError).code
                if errorCode != 57 {
                    print("WebSocket receive error: \(error)")
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    self.messages.send(text)
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    fatalError()
                }
                self.listen()
            }
        }
    }

    func send(message: String) {
        guard let task = webSocketTask else {
            print("⚠ Нельзя отправить сообщение: WebSocket не подключен")
            return
        }
        
        let state = task.state
        guard state == .running || state == .suspended else {
            print("⚠ Нельзя отправить сообщение: состояние WebSocket = \(state.rawValue)")
            return
        }
        
        print("Sending: \(message)")
        task.send(.string(message)) { error in
            if let error = error {
                print("Sending error: \(error)")
            }
        }
    }
}
