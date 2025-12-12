import SwiftUI
import SpriteKit

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
                    Spacer()
                    controllerView
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 50)
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Private Properties
    
    @ObservedObject private var viewModel: ViewModel
    @State private var scene: GameScene

    // MARK: - Private Views
    
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

