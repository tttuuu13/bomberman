import Combine
import Foundation

@MainActor
protocol GameplayViewModel: ObservableObject {
    var players: [PlayerModel] { get }
    var bombs: [BombModel] { get }
    var grid: [[TileType]] { get }
    var rows: Int { get }
    var cols: Int { get }
    var explosionEvents: PassthroughSubject<ExplosionPayload, Never> { get }
    
    var engine: GameEngine { get }
    
    func movePlayer(dx: Int, dy: Int)
    func placeBomb()
}

final class GameplayViewModelImpl: GameplayViewModel {
    
    // MARK: - Init
    
    init(engine: GameEngine) {
        self._engine = engine
        
        setupBindings()
    }
    
    // MARK: - Internal Properties
    
    @Published private(set) var players: [PlayerModel] = []
    @Published private(set) var bombs: [BombModel] = []
    @Published private(set) var grid: [[TileType]] = []
    
    var rows: Int {
        _engine.rows
    }
    
    var cols: Int {
        _engine.cols
    }
    
    var explosionEvents: PassthroughSubject<ExplosionPayload, Never> {
        _engine.explosionEvents
    }
    
    var engine: GameEngine {
        _engine
    }
    
    func movePlayer(dx: Int, dy: Int) {
        _engine.movePlayer(dx: dx, dy: dy)
    }
    
    func placeBomb() {
        _engine.placeBomb()
    }
    
    // MARK: - Private Properties
    
    private let _engine: GameEngine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        _engine.$players
            .receive(on: DispatchQueue.main)
            .assign(to: &$players)
        
        _engine.$bombs
            .receive(on: DispatchQueue.main)
            .assign(to: &$bombs)
        
        _engine.$grid
            .receive(on: DispatchQueue.main)
            .assign(to: &$grid)
    }
}

