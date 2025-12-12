import SwiftUI
import Combine

class GameEngine: ObservableObject {
    @Published var players: [PlayerModel] = []
    @Published var grid: [[TileType]] = []
    @Published var bombs: [BombModel] = []
    @Published var gameState: String = "CONNECTING"
    @Published var isReconnecting: Bool = false

    var myPlayerId: String?

    private var socket: WebSocketService
    private var cancellables = Set<AnyCancellable>()
    let explosionEvents = PassthroughSubject<ExplosionPayload, Never>()
    let mapResetEvent = PassthroughSubject<Void, Never>()
    
    private var previousGameState: String = ""
    @Published var roundId: Int = 0 

    var rows: Int = 0
    var cols: Int = 0

    init(socketService: WebSocketService) {
        self.socket = socketService

        setupSocketSubscription()

        let defaults = UserDefaults.standard
        var playerName = defaults.string(forKey: "playerName")
        if playerName == nil || playerName?.isEmpty == true {
            playerName = "Player\(Int.random(in: 1000...9999))"
            defaults.set(playerName, forKey: "playerName")
        }
        
        joinGame(name: playerName ?? "Player\(Int.random(in: 1000...9999))")
    }
    
    private func setupSocketSubscription() {
        cancellables.removeAll()
        
        socket.messages
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        print("WebSocket соединение закрыто")
                    case .failure(let error):
                        print("WebSocket ошибка: \(error)")
                        self?.isReconnecting = false
                    }
                },
                receiveValue: { [weak self] message in
                    self?.handleServerMessage(jsonString: message)
                }
            )
            .store(in: &cancellables)
    }

    func joinGame(name: String) {
        print("Подключение к игре с именем: \(name)")
        
        if gameState != "CONNECTING" {
            gameState = "CONNECTING"
        }
        
        socket.connect()
        
        attemptJoin(name: name, attempt: 1, maxAttempts: 3)
    }
    
    private func attemptJoin(name: String, attempt: Int, maxAttempts: Int) {
        let delay = Double(attempt) * 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            guard self.gameState == "CONNECTING" || self.isReconnecting else {
                print("⚠ Состояние изменилось (\(self.gameState)), не отправляем join")
                return
            }
            
            let joinMsg = JoinMessage(role: "player", name: name)
            print("Попытка \(attempt)/\(maxAttempts) отправки join сообщения с именем: \(name)")
            
            if let data = try? JSONEncoder().encode(joinMsg),
               let jsonString = String(data: data, encoding: .utf8) {
                self.socket.send(message: jsonString)
                print("✓ Join сообщение отправлено (попытка \(attempt))")
                
                if attempt < maxAttempts {
                    print("Планируем следующую попытку через \(delay + 1.0) секунд...")
                    self.attemptJoin(name: name, attempt: attempt + 1, maxAttempts: maxAttempts)
                }
            } else {
                print("✗ Ошибка кодирования join сообщения")
                if attempt < maxAttempts {
                    print("Повторная попытка отправки join...")
                    self.attemptJoin(name: name, attempt: attempt + 1, maxAttempts: maxAttempts)
                }
            }
        }
    }

    private func handleServerMessage(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }

        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for jsonObject in jsonArray {
                    processSingleJsonObject(jsonObject)
                }
            } else if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                processSingleJsonObject(jsonObject)
            }
        } catch {
            print("JSON Parsing Error: \(error)")
        }
    }

    private func processSingleJsonObject(_ jsonObject: [String: Any]) {
        guard let type = jsonObject["type"] as? String else { return }

        switch type {
        case "explosion_event":
            if let payload = jsonObject["payload"],
               let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: []),
               let payload = try? JSONDecoder().decode(ExplosionPayload.self, from: payloadData) {
                explosionEvents.send(payload)
            }
        case "assign_id":
            if let payload = jsonObject["payload"] as? String {
                let wasReconnecting = isReconnecting
                self.myPlayerId = payload
                if wasReconnecting {
                    print("✓ Переподключение успешно завершено, новый ID: \(payload)")
                    isReconnecting = false
                }
            }
        case "game_state":
            if let payloadData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
               let wrapper = try? JSONDecoder().decode(ServerMessageWrapper.self, from: payloadData),
               let state = wrapper.payload {
                let oldState = self.gameState
                self.players = state.players
                self.bombs = state.bombs
                
                let isNewRound = state.state == "IN_PROGRESS" && previousGameState != "IN_PROGRESS"
                previousGameState = state.state
                
                self.gameState = state.state
                
                print("Получено game_state: состояние=\(state.state), игроков=\(state.players.count)")
                
                if isReconnecting {
                    if oldState == "CONNECTING" && state.state == "WAITING" {
                        print("✓ Переподключение завершено, состояние: WAITING, игроков: \(state.players.count)")
                        isReconnecting = false
                    } else {
                        print("Переподключение в процессе: старое состояние=\(oldState), новое=\(state.state)")
                    }
                }
                
                parseMap(from: state.map)
                
                if isNewRound {
                    roundId += 1
                    mapResetEvent.send()
                }
            }
        default:
            break
        }
    }

    func movePlayer(dx: Int, dy: Int) {
        let moveMsg = MoveMessage(dx: dx, dy: dy)
        send(message: moveMsg)
    }

    func setReady() {
        send(message: ClientMessage(type: "ready"))
    }

    func placeBomb() {
        send(message: ClientMessage(type: "place_bomb"))
    }
    
    func reconnectWithNewName() {
        guard gameState == "WAITING", !isReconnecting else {
            print("Переподключение невозможно: состояние игры \(gameState), isReconnecting: \(isReconnecting)")
            return
        }
        
        isReconnecting = true
        print("Начало переподключения...")
        
        myPlayerId = nil
        players = []
        
        socket.disconnect()
        
        players = []
        bombs = []
        grid = []
        rows = 0
        cols = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self = self else { return }
            
            guard self.isReconnecting else {
                print("Переподключение отменено")
                return
            }
            
            let defaults = UserDefaults.standard
            let playerName = defaults.string(forKey: "playerName") ?? "Player\(Int.random(in: 1000...9999))"
            print("═══════════════════════════════════════")
            print("Начинаем переподключение с именем: \(playerName)")
            print("═══════════════════════════════════════")
            
            self.setupSocketSubscription()
            
            self.gameState = "CONNECTING"
            
            self.joinGame(name: playerName)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
                guard let self = self else { return }
                if self.isReconnecting && (self.gameState == "CONNECTING" || self.myPlayerId == nil) {
                    print("⚠⚠⚠ ТАЙМАУТ ПЕРЕПОДКЛЮЧЕНИЯ ⚠⚠⚠")
                    print("  - Состояние: \(self.gameState)")
                    print("  - ID игрока: \(self.myPlayerId ?? "nil")")
                    print("  - Игроков: \(self.players.count)")
                    self.isReconnecting = false
                    if self.gameState == "CONNECTING" {
                        self.gameState = "WAITING"
                    }
                }
            }
        }
    }

    private func send<T: Encodable>(message: T) {
        if let data = try? JSONEncoder().encode(message), let jsonString = String(data: data, encoding: .utf8) {
            socket.send(message: jsonString)
        }
    }

    private func parseMap(from stringMatrix: [[String]]) {
        self.rows = stringMatrix.count
        self.cols = stringMatrix.first?.count ?? 0

        var newGrid: [[TileType]] = []
        for rowArray in stringMatrix {
            let row = rowArray.map { TileType(rawValue: $0) ?? .empty }
            newGrid.append(row)
        }
        self.grid = newGrid
    }
}
