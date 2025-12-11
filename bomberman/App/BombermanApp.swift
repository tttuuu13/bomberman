import SwiftUI

@main
struct BombermanApp: App {
    @StateObject private var socketService = WebSocketService()

    var body: some Scene {
        WindowGroup {
            GameView(gameEngine: GameEngine(socketService: socketService))
        }
    }
}
