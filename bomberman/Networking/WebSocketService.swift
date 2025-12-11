import Foundation
import Combine

class WebSocketService: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    // private let serverURL = URL(string: "ws://localhost:8765")!
    private let serverURL = URL(string: "ws://192.168.1.2:8765")!

    let messages = PassthroughSubject<String, Error>()

    func connect() {
        print("Connecting to \(serverURL)...")
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()
        listen()
    }

    func disconnect() {
        print("Disconnecting...")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("Error: \(error)")
                self?.messages.send(completion: .failure(error))
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.messages.send(text)
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    fatalError()
                }
                self?.listen()
            }
        }
    }

    func send(message: String) {
        print("Sending: \(message)")
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("Sending error: \(error)")
            }
        }
    }
}
