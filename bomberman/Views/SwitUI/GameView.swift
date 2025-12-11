import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject private var engine: GameEngine
    @State private var scene: GameScene

    init(gameEngine: GameEngine) {
        _engine = StateObject(wrappedValue: gameEngine)

        let initialScene = GameScene()
        initialScene.scaleMode = .resizeFill
        initialScene.engine = gameEngine
        _scene = State(initialValue: initialScene)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 115/255, green: 117/255, blue: 45/255)
                    .edgesIgnoringSafeArea(.all)

                SpriteView(scene: scene)
                    .onAppear {
                        scene.size = CGSize(width: geometry.size.width, height: geometry.size.height)
                        scene.engine = self.engine
                        scene.bindEngineEvents()
                        scene.updateVisuals()
                    }
                    .onChange(of: engine.players) { _ in scene.updateVisuals() }
                    .onChange(of: engine.bombs.count) { _ in scene.updateVisuals() }

                VStack {
                    Spacer()
                    controllerView
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 50)
            }
            .ignoresSafeArea()
        }
    }

    private var controllerView: some View {
        HStack {
            Button(action: { engine.placeBomb() }) { ControllerButton(imageName: "button_b") }

            Spacer()

            ZStack {
                VStack(spacing: 0) {
                    Button(action: { engine.movePlayer(dx: 0, dy: -1) }) { ControllerButton(imageName: "button_up") }

                    Spacer().frame(width: 30, height: 30)

                    Button(action: { engine.movePlayer(dx: 0, dy: 1) }) { ControllerButton(imageName: "button_down") }
                }

                HStack(spacing: 0) {
                    Button(action: { engine.movePlayer(dx: -1, dy: 0) }) { ControllerButton(imageName: "button_left") }
                    Spacer().frame(width: 30, height: 30)
                    Button(action: { engine.movePlayer(dx: 1, dy: 0) }) { ControllerButton(imageName: "button_right") }
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

#Preview {
    GameView(gameEngine: GameEngine(socketService: WebSocketService()))
}
