import Combine
import Foundation

@MainActor
protocol LobbyViewModel: ObservableObject {
    var players: [PlayerModel] { get }
    var myPlayerId: String? { get }
    
    func setReady()
}

final class LobbyViewModelImpl: LobbyViewModel {
    
    // MARK: - Init
    
    init(engine: GameEngine) {
        self.engine = engine
        
        setupBindings()
    }
    
    // MARK: - Internal Properties
    
    @Published private(set) var players: [PlayerModel] = []
    
    var myPlayerId: String? {
        engine.myPlayerId
    }
    
    func setReady() {
        engine.setReady()
    }
    
    // MARK: - Private Properties
    
    private let engine: GameEngine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        engine.$players
            .receive(on: DispatchQueue.main)
            .assign(to: &$players)
    }
}

