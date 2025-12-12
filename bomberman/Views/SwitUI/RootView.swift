//
//  RootView.swift
//  bomberman
//
//  Created by тимур on 12.12.2025.
//

import SwiftUI

struct RootView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            switch engine.gameState {
            case "CONNECTING":
                VStack {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(2)
                    Text("Подключение...").foregroundColor(.white).padding(.top)
                }

            case "WAITING":
                LobbyView(engine: engine)

            case "IN_PROGRESS":
                GameView(engine: engine)

            case "GAME_OVER":
                ZStack {
                    GameView(engine: engine)
                        .blur(radius: 10)
                        .disabled(true)
                    GameOverView(engine: engine)
                }

            default:
                Text("Error: \(engine.gameState)").foregroundColor(.red)
            }
        }
        .animation(.easeInOut, value: engine.gameState)
    }
}


#Preview {
    let socketService = WebSocketService()
    RootView(engine: GameEngine(socketService: socketService))
}
