import SwiftUI

struct LobbyView<ViewModel: LobbyViewModel>: View {
    
    // MARK: - Init
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            VStack(spacing: .zero) {
                VStack(spacing: 15.0) {
                    header

                    ScrollView {
                        VStack(spacing: 12.0) {
                            ForEach(viewModel.players) { player in
                                HStack {
                                    Text(player.name)
                                        .font(.pixelifySans(size: 25.0, fontWeight: .bold))
                                        .foregroundColor(.white)

                                    Spacer()

                                    playerStateView(isReady: player.ready)
                                        .font(.pixelifySans(size: 25.0, fontWeight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12.0)
                                        .stroke(player.id == viewModel.myPlayerId ? Color.yellow : Color.clear, lineWidth: 5.0)
                                )
                                .cornerRadius(12.0)
                            }
                        }
                    }
                }

                Spacer()

                if let me = viewModel.players.first(where: { $0.id == viewModel.myPlayerId }) {
                    Button(action: {
                        viewModel.setReady()
                    }) {
                        Text(me.ready == true ? "ОТМЕНА" : "Я ГОТОВ!")
                            .font(.pixelifySans(size: 25.0, fontWeight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(me.ready == true ? Color.red : Color.green)
                            .cornerRadius(15)
                    }
                }
            }
            .padding(.vertical, 15.0)
            .padding(.horizontal, 40.0)
            .blur(radius: viewModel.isReconnecting ? 5 : 0)
            
            // Индикатор загрузки при переподключении
            if viewModel.isReconnecting {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                    Text("Переподключение...")
                        .font(.pixelifySans(size: 25.0, fontWeight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
            }
        }
    }
    
    // MARK: - Private Properties
    
    @ObservedObject private var viewModel: ViewModel
    @State private var isSettingsPresented = false
    
    // MARK: - Private Views
    
    private var header: some View {
        ZStack {
            Text("ЛОББИ")
                .font(.pixelifySans(size: 40.0, fontWeight: .bold))
                .foregroundColor(.white)
            
            HStack {
                Spacer()
                
                Button(
                    action: {
                        isSettingsPresented = true
                    },
                    label: {
                        Images.Icons.settings_size24
                            .renderingMode(.template)
                            .foregroundStyle(.white)
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            GameSettingsView(engine: viewModel.engine)
        }
    }
    
    // MARK: - Private Methods
    
    @ViewBuilder
    private func playerStateView(isReady: Bool?) -> some View {
        if isReady == true {
            Text("ГОТОВ")
        } else {
            Text("ЖДЕМ...")
        }
    }
}

