import Combine
import Foundation

@MainActor
protocol LobbyViewModel: ObservableObject {
    var players: [PlayerModel] { get }
    var myPlayerId: String? { get }
    var engine: GameEngine { get }
    var isReconnecting: Bool { get }
    
    func setReady()
}

final class LobbyViewModelImpl: LobbyViewModel {
    
    // MARK: - Init
    
    init(engine: GameEngine) {
        self._engine = engine
        
        setupBindings()
    }
    
    // MARK: - Internal Properties
    
    @Published private(set) var players: [PlayerModel] = []
    
    var myPlayerId: String? {
        engine.myPlayerId
    }
    
    var engine: GameEngine {
        _engine
    }
    
    var isReconnecting: Bool {
        engine.isReconnecting
    }
    
    func setReady() {
        _engine.setReady()
    }
    
    // MARK: - Private Properties
    
    private let _engine: GameEngine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        _engine.$players
            .receive(on: DispatchQueue.main)
            .assign(to: &$players)
    }
}

