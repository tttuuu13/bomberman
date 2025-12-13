import SwiftUI
import SpriteKit
import UIKit

struct GameplayView<ViewModel: GameplayViewModel>: View {
    
    // MARK: - Init
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        
        let initialScene = GameScene()
        initialScene.scaleMode = .resizeFill
        initialScene.engine = viewModel.engine
        _scene = State(initialValue: initialScene)
    }
    
    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 115/255, green: 117/255, blue: 45/255)
                    .edgesIgnoringSafeArea(.all)

                SpriteView(scene: scene)
                    .onAppear {
                        scene.size = CGSize(width: geometry.size.width, height: geometry.size.height)
                        scene.engine = viewModel.engine
                        scene.bindEngineEvents()
                        scene.updateVisuals()
                    }
                    .onChange(of: viewModel.gameState) { _ in scene.updateVisuals() }
                    .onChange(of: viewModel.grid) { _ in scene.updateVisuals() }
                    .onChange(of: viewModel.players) { _ in scene.updateVisuals() }
                    .onChange(of: viewModel.bombs.count) { _ in scene.updateVisuals() }

                VStack {
                    if viewModel.gameState == "IN_PROGRESS", let time = viewModel.timeRemaining {
                        timerView(time: Int(time))
                    }
                    
                    Spacer()
                    
                    if viewModel.isCurrentPlayerAlive {
                        controllerView
                    }
                    
                    if viewModel.shouldShowSpectatorBadge {
                        spectatorBadge
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 50)
            }
            .ignoresSafeArea()
            .onChange(of: viewModel.isCurrentPlayerAlive) { isAlive in
                if !isAlive {
                    triggerDeathHaptic()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func triggerDeathHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Private Properties
    
    @ObservedObject private var viewModel: ViewModel
    @State private var scene: GameScene

    // MARK: - Private Views
    
    private func timerView(time: Int) -> some View {
        let isExpired = time <= 0
        
        return Text(String(time))
            .font(.custom("PixelifySans-Bold", size: 28))
            .foregroundColor(isExpired ? .red : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
    
    private var spectatorBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.system(size: 16, weight: .semibold))
            
            Text("SPECTATOR")
                .font(.custom("PixelifySans-SemiBold", size: 18))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var controllerView: some View {
        HStack {
            Button(action: { viewModel.placeBomb() }) {
                ControllerButton(imageName: "button_b")
            }

            Spacer()

            ZStack {
                VStack(spacing: 0) {
                    Button(action: { viewModel.movePlayer(dx: 0, dy: -1) }) {
                        ControllerButton(imageName: "button_up")
                    }

                    Spacer().frame(width: 30, height: 30)

                    Button(action: { viewModel.movePlayer(dx: 0, dy: 1) }) {
                        ControllerButton(imageName: "button_down")
                    }
                }

                HStack(spacing: 0) {
                    Button(action: { viewModel.movePlayer(dx: -1, dy: 0) }) {
                        ControllerButton(imageName: "button_left")
                    }
                    Spacer().frame(width: 30, height: 30)
                    Button(action: { viewModel.movePlayer(dx: 1, dy: 0) }) {
                        ControllerButton(imageName: "button_right")
                    }
                }
            }
        }
    }
}

struct ControllerButton: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .interpolation(.none)
            .resizable()
            .frame(width: 80, height: 80)
            .opacity(0.4)
    }
}

