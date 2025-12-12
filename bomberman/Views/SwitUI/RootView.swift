//
//  RootView.swift
//  bomberman
//
//  Created by тимур on 12.12.2025.
//

import SwiftUI

struct RootView: View {
    
    // MARK: - Init
    
    init(engine: GameEngine) {
        self.engine = engine
        self._lobbyViewModel = StateObject(wrappedValue: LobbyViewModelImpl(engine: engine))
        self._gameplayViewModel = StateObject(wrappedValue: GameplayViewModelImpl(engine: engine))
        self._gameOverViewModel = StateObject(wrappedValue: GameOverViewModelImpl(engine: engine))
    }
    
    // MARK: - Body

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
                LobbyView(viewModel: lobbyViewModel)

            case "IN_PROGRESS":
                GameplayView(viewModel: gameplayViewModel)
                    .id("gameplay_round_\(engine.roundId)")

            case "GAME_OVER":
                ZStack {
                    GameplayView(viewModel: gameplayViewModel)
                        .blur(radius: 10)
                        .disabled(true)
                        .id("gameplay_round_\(engine.roundId)_gameover")
                    GameOverView(viewModel: gameOverViewModel)
                }

            default:
                Text("Error: \(engine.gameState)").foregroundColor(.red)
            }
        }
        .animation(.easeInOut, value: engine.gameState)
    }
    
    // MARK: - Private Properties
    
    @ObservedObject private var engine: GameEngine
    @StateObject private var lobbyViewModel: LobbyViewModelImpl
    @StateObject private var gameplayViewModel: GameplayViewModelImpl
    @StateObject private var gameOverViewModel: GameOverViewModelImpl
}


#Preview {
    let socketService = WebSocketService()
    RootView(engine: GameEngine(socketService: socketService))
}
