import SwiftUI

struct LobbyView: View {
    
    // MARK: - Init
    
    init(engine: GameEngine) {
        self.engine = engine
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0.0) {
            VStack(spacing: 15.0) {
                Text("ЛОББИ")
                    .font(.pixelifySans(size: 40.0, fontWeight: .bold))
                    .foregroundColor(.white)

                ScrollView {
                    VStack(spacing: 12.0) {
                        ForEach(engine.players) { player in
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
                                    .stroke(player.id == engine.myPlayerId ? Color.yellow : Color.clear, lineWidth: 5.0)
                            )
                            .cornerRadius(12.0)
                        }
                    }
                }
            }

            Spacer()

            if let me = engine.players.first(where: { $0.id == engine.myPlayerId }) {
                Button(action: {
                    engine.setReady()
                }) {
                    Text(me.ready == true ? "ОТМЕНА" : "Я ГОТОВ!")
                        .font(.pixelifySans(size: 30.0, fontWeight: .bold))
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
    }
    
    // MARK: - Private Properties
    
    @ObservedObject private var engine: GameEngine
    
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
