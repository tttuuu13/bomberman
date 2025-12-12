import SwiftUI
import Combine

class GameEngine: ObservableObject {
    @Published var players: [PlayerModel] = []
    @Published var grid: [[TileType]] = []
    @Published var bombs: [BombModel] = []
    @Published var gameState: String = "CONNECTING"

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

        socket.messages
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] message in
                self?.handleServerMessage(jsonString: message)
            })
            .store(in: &cancellables)

        let randomName = "Player\(Int.random(in: 100...999))"
        joinGame(name: randomName)
    }

    func joinGame(name: String) {
        socket.connect()
        let joinMsg = JoinMessage(role: "player", name: name)
        send(message: joinMsg)
    }

    private func handleServerMessage(jsonString: String) {
        print(jsonString)
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
                self.myPlayerId = payload
            }
        case "game_state":
            if let payloadData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
               let wrapper = try? JSONDecoder().decode(ServerMessageWrapper.self, from: payloadData),
               let state = wrapper.payload {
                self.players = state.players
                self.bombs = state.bombs
                
                let isNewRound = state.state == "IN_PROGRESS" && previousGameState != "IN_PROGRESS"
                previousGameState = state.state
                
                self.gameState = state.state
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
