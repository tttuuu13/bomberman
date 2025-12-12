import Combine
import Foundation

@MainActor
protocol GameOverViewModel: ObservableObject {
    var players: [PlayerModel] { get }
    var winner: PlayerModel? { get }
}

final class GameOverViewModelImpl: GameOverViewModel {
    
    // MARK: - Init
    
    init(engine: GameEngine) {
        self.engine = engine
        
        setupBindings()
    }
    
    // MARK: - Internal Properties
    
    @Published private(set) var players: [PlayerModel] = []
    
    var winner: PlayerModel? {
        players.first(where: { $0.alive })
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

