import SwiftUI

@main
struct BombermanApp: App {
    private let socketService = WebSocketService()

    @StateObject private var gameEngine: GameEngine

    init() {
        let engine = GameEngine(socketService: socketService)
        _gameEngine = StateObject(wrappedValue: engine)
    }

    var body: some Scene {
        WindowGroup {
            RootView(engine: gameEngine)
        }
    }
}
