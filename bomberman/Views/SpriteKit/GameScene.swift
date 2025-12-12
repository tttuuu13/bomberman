import SpriteKit
import Combine

class GameScene: SKScene {
    var engine: GameEngine?

    private var tileNodes: [[SKSpriteNode?]] = []
    private var playerNodes: [String: SKSpriteNode] = [:]
    private var bombNodes: [String: SKSpriteNode] = [:]
    private var explosionAnimationFrames: [SKTexture] = []

    private var playerWalkAnims: [Direction: SKAction] = [:]
    private var playerIdleAnims: [Direction: SKAction] = [:]
    private var playerDeathAnim: SKAction?

    private var lastKnownPositions: [String: (x: Int, y: Int)] = [:]

    private var cancellables = Set<AnyCancellable>()

    private var tileSize: CGFloat = 0
    private var mapOffset: CGPoint = .zero
    private let perspectiveFactor: CGFloat = 0.8
    
    private var lastBuiltRoundId: Int = -1

    private let worldNode = SKNode()

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0, y: 1)
        backgroundColor = UIColor(red: 115/255, green: 117/255, blue: 45/255, alpha: 1.0)

        addChild(worldNode)

        loadExplosionAnimation()
        loadPlayerAnimationsFromSheet()
    }

    private func loadExplosionAnimation() {
        let textureAtlas = SKTextureAtlas(named: "explosion")
        var frames: [SKTexture] = []

        let numImages = textureAtlas.textureNames.count
        for i in 1...numImages {
            let textureName = "frame\(i)"
            let texture = textureAtlas.textureNamed(textureName)
            frames.append(texture)
        }
        self.explosionAnimationFrames = frames
    }

    private func loadPlayerAnimationsFromSheet() {
        let sheetName = "player_sheet"
        let frameSize = CGSize(width: 32, height: 32)
        playerWalkAnims[.down] = loadAnimation(from: sheetName, frameSize: frameSize, row: 6, frameCount: 2, timePerFrame: 0.15, repeats: false)
        playerWalkAnims[.up] = loadAnimation(from: sheetName, frameSize: frameSize, row: 8, frameCount: 2, timePerFrame: 0.15, repeats: false)
        playerWalkAnims[.right] = loadAnimation(from: sheetName, frameSize: frameSize, row: 7, frameCount: 2, timePerFrame: 0.15, repeats: false)
        playerWalkAnims[.left] = playerWalkAnims[.right]

        playerIdleAnims[.down] = loadAnimation(from: sheetName, frameSize: frameSize, row: 11, frameCount: 2, timePerFrame: 0.5, repeats: true)

        playerDeathAnim = loadAnimation(
            from: "player_sheet",
            frameSize: CGSize(width: 32, height: 32),
            row: 1,
            frameCount: 3,
            timePerFrame: 0.15,
            repeats: false
        )
    }

    private func loadAnimation(from sheetName: String, frameSize: CGSize, row: Int, frameCount: Int, timePerFrame: TimeInterval, repeats: Bool) -> SKAction {
        let sheet = SKTexture(imageNamed: sheetName)
        var frames: [SKTexture] = []

        let frameWidth = frameSize.width
        let frameHeight = frameSize.height

        for i in 0..<frameCount {
            let x = CGFloat(i) * frameWidth
            let y = CGFloat(row) * frameHeight

            let normalizedRect = CGRect(
                x: x / sheet.size().width,
                y: y / sheet.size().height,
                width: frameWidth / sheet.size().width,
                height: frameHeight / sheet.size().height
            )

            let frameTexture = SKTexture(rect: normalizedRect, in: sheet)
            frameTexture.filteringMode = .nearest
            frames.append(frameTexture)
        }

        let anim = SKAction.animate(with: frames, timePerFrame: timePerFrame)

        return repeats ? SKAction.repeatForever(anim) : anim
    }

    func bindEngineEvents() {
        cancellables.removeAll()
        
        engine?.explosionEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] payload in
                self?.handleExplosion(payload: payload)
            }
            .store(in: &cancellables)
        
        engine?.mapResetEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.forceRebuildMap()
            }
            .store(in: &cancellables)
        
        engine?.$gameState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                if newState == "IN_PROGRESS" {
                    self?.forceRebuildMap()
                }
            }
            .store(in: &cancellables)
    }
    
    func forceRebuildMap() {
        guard let engine = engine, engine.rows > 0, engine.cols > 0, let view = self.view else { return }
        
        let mapIsEmpty = tileNodes.isEmpty || worldNode.children.isEmpty
        guard mapIsEmpty || lastBuiltRoundId != engine.roundId else { return }
        lastBuiltRoundId = engine.roundId
        
        calculateSceneDimensions(view: view)
        setupMap()
        updatePlayers()
        updateBombs()
    }

    func updateVisuals() {
        guard let engine = engine, engine.rows > 0, engine.cols > 0 else { return }

        if tileNodes.count != engine.rows || tileNodes.first?.count != engine.cols {
            guard let view = self.view else { return }
            calculateSceneDimensions(view: view)
            setupMap()
        }
        
        updateMap()
        updatePlayers()
        updateBombs()
    }

    private func handleExplosion(payload: ExplosionPayload) {
        guard let centerCell = payload.cells.first else { return }

        playCameraShake()

        playExplosionAnimation(atX: centerCell.x, atY: centerCell.y)

        for coord in payload.cells {
            scorchTile(at: coord)
        }
    }

    private func calculateSceneDimensions(view: SKView) {
        guard let engine = engine, engine.rows > 0, engine.cols > 0 else { return }

        let viewWidth = view.bounds.width
        let viewHeight = view.bounds.height

        let sizeX = viewWidth / CGFloat(engine.cols)
        let sizeY = viewHeight / (CGFloat(engine.rows) * perspectiveFactor)
        self.tileSize = min(sizeX, sizeY)

        let totalMapWidth = CGFloat(engine.cols) * tileSize
        let totalMapHeight = CGFloat(engine.rows) * (tileSize * perspectiveFactor)

        let offsetX = (viewWidth - totalMapWidth) / 2
        let offsetY = (viewHeight - totalMapHeight) / 2

        self.mapOffset = CGPoint(x: offsetX, y: -offsetY - tileSize / 2)
    }

    func setupMap() {
        guard let engine = engine, tileSize > 0 else { return }
        worldNode.removeAllChildren()

        tileNodes = Array(repeating: Array(repeating: nil, count: engine.cols), count: engine.rows)
        playerNodes.removeAll()
        bombNodes.removeAll()

        for r in 0..<engine.rows {
            for c in 0..<engine.cols {
                let type = engine.grid[r][c]
                let basePos = gridPositionForBase(col: c, row: r)

                let grassPos = CGPoint(x: basePos.x, y: basePos.y + (tileSize * perspectiveFactor) / 2)
                let grassNode = SKSpriteNode(imageNamed: "grass\(Int.random(in: 1...5))")
                grassNode.size = CGSize(width: tileSize, height: tileSize)
                grassNode.position = grassPos
                grassNode.zPosition = -100
                worldNode.addChild(grassNode)

                if type != .empty {
                    let imageName = (type == .wall) ? "wall1" : "obstacle\(Int.random(in: 1...4))"
                    let node = SKSpriteNode(imageNamed: imageName)
                    node.size = CGSize(width: tileSize, height: tileSize * 1.4)
                    node.anchorPoint = CGPoint(x: 0.5, y: 0.0)
                    node.position = basePos
                    node.zPosition = CGFloat(r) * 10
                    worldNode.addChild(node)
                    tileNodes[r][c] = node
                }
            }
        }
    }

    func updateMap() {
        guard let engine = engine else { return }

        for r in 0..<engine.rows {
            for c in 0..<engine.cols {
                let type = engine.grid[r][c]
                let node = tileNodes[r][c]

                if (type == .empty || type == .spawn) && node != nil {
                    node?.removeFromParent()
                    tileNodes[r][c] = nil
                }
            }
        }
    }

    private func updatePlayers() {
        guard let engine = engine else { return }

        let currentIDs = Set(engine.players.map { $0.id })
        for (id, node) in playerNodes {
            if !currentIDs.contains(id) {
                node.removeFromParent()
                playerNodes.removeValue(forKey: id)
                lastKnownPositions.removeValue(forKey: id)
            }
        }

        for player in engine.players {
            if !player.alive {
                if let node = playerNodes[player.id] {
                    if node.name != "deadBody" {
                        node.removeAllActions()

                        if let deathAnim = playerDeathAnim {
                            let waitAction = SKAction.wait(forDuration: 0.5)

                            let dropToFloor = SKAction.run {
                                node.position.x -= self.tileSize * 0.2
                                node.zPosition = CGFloat(player.y) * 10 + 1
                            }

                            let sequence = SKAction.sequence([waitAction, dropToFloor, deathAnim])

                            node.run(sequence)
                        }

                        node.name = "deadBody"
                    }
                }

                continue
            }

            let node: SKSpriteNode

            if let existing = playerNodes[player.id] {
                node = existing
            } else {
                let newNode = SKSpriteNode()
                newNode.size = CGSize(width: tileSize * 2.5, height: tileSize * 2.5)
                newNode.anchorPoint = CGPoint(x: 0.5, y: 0.2)
                newNode.position = gridPositionForBase(col: player.x, row: player.y)
                newNode.color = getColor(for: player.id)
                newNode.colorBlendFactor = 0.3
                worldNode.addChild(newNode)
                playerNodes[player.id] = newNode

                if let idle = playerIdleAnims[.down] {
                    newNode.run(idle, withKey: "mainAnim")
                }

                lastKnownPositions[player.id] = (player.x, player.y)
                node = newNode
            }

            let oldPos = lastKnownPositions[player.id]!
            let newPos = (x: player.x, y: player.y)

            if oldPos.x != newPos.x || oldPos.y != newPos.y {

                var direction: Direction = .down
                if newPos.x > oldPos.x { direction = .right }
                else if newPos.x < oldPos.x { direction = .left }
                else if newPos.y > oldPos.y { direction = .up }
                else if newPos.y < oldPos.y { direction = .down }

                let walkAnim = playerWalkAnims[direction] ?? playerWalkAnims[.down]!
                let idleAnim = playerIdleAnims[.down]!
                let targetPoint = gridPositionForBase(col: newPos.x, row: newPos.y)

                let moveAction = SKAction.move(to: targetPoint, duration: 0.2)

                let walkAction = SKAction.group([moveAction, walkAnim])

                node.removeAllActions()
                node.xScale = (direction == .left) ? -1.0 : 1.0

                node.run(walkAction) {
                    node.removeAllActions()
                    node.run(idleAnim, withKey: "mainAnim")
                }

                lastKnownPositions[player.id] = newPos
            }

            node.zPosition = CGFloat(player.y) * 10 + 5
        }
    }

    private func updateBombs() {
        guard let engine = engine else { return }

        let currentBombIDs = Set(engine.bombs.map { $0.id })

        for (id, node) in bombNodes {
            if !currentBombIDs.contains(id) {
                node.removeFromParent()
                bombNodes.removeValue(forKey: id)
            }
        }

        for bomb in engine.bombs {
            if bombNodes[bomb.id] == nil {
                let node = SKSpriteNode(imageNamed: "bomb")
                node.size = CGSize(width: tileSize * 1.5, height: tileSize * 1.5)
                node.anchorPoint = CGPoint(x: 0.5, y: 0.1)
                node.position = gridPositionForBase(col: bomb.x, row: bomb.y)
                node.zPosition = CGFloat(bomb.y) * 10 + 6
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
                node.run(SKAction.repeatForever(pulse), withKey: "pulse")

                worldNode.addChild(node)
                bombNodes[bomb.id] = node
            }
        }
    }

    // MARK: - Animations

    private func scorchTile(at coord: Coordinate) {
        let scorchNode = SKSpriteNode(imageNamed: "scorch_overlay")

        scorchNode.size = CGSize(width: tileSize, height: tileSize)
        let basePos = gridPositionForBase(col: coord.x, row: coord.y)
        scorchNode.position = CGPoint(x: basePos.x, y: basePos.y + (tileSize * perspectiveFactor) / 2)
        scorchNode.zPosition = -50

        let fadeIn = SKAction.fadeIn(withDuration: 0.1)

        let wait = SKAction.wait(forDuration: 3.0)

        let fadeOut = SKAction.fadeOut(withDuration: 3.0)

        let remove = SKAction.removeFromParent()

        let sequence = SKAction.sequence([fadeIn, wait, fadeOut, remove])

        worldNode.addChild(scorchNode)
        scorchNode.run(sequence)
    }

    private func playExplosionAnimation(atX x: Int, atY y: Int) {
        guard !explosionAnimationFrames.isEmpty else { return }

        let node = SKSpriteNode(texture: explosionAnimationFrames.first)

        node.size = CGSize(width: tileSize * 7, height: tileSize * 7)
        node.anchorPoint = CGPoint(x: 0.5, y: 0.3)
        node.position = gridPositionForBase(col: x, row: y)
        node.zPosition = 1000

        let animationAction = SKAction.animate(with: explosionAnimationFrames, timePerFrame: 0.08, resize: false, restore: false)

        let removeAction = SKAction.removeFromParent()

        node.run(SKAction.sequence([animationAction, removeAction]))

        worldNode.addChild(node)
    }

    private func playCameraShake() {
        guard worldNode.action(forKey: "cameraShake") == nil else { return }

        let shakeAmount: CGFloat = 5.0
        let shakeDuration: Double = 0.2

        let numberOfShakes = 6
        var actions: [SKAction] = []

        for _ in 0..<numberOfShakes {
            let dx = CGFloat.random(in: -shakeAmount...shakeAmount)
            let dy = CGFloat.random(in: -shakeAmount...shakeAmount)

            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: shakeDuration / Double(numberOfShakes))
            let moveBackAction = moveAction.reversed()

            actions.append(moveAction)
            actions.append(moveBackAction)
        }

        let returnToCenter = SKAction.move(to: .zero, duration: 0)
        actions.append(returnToCenter)

        let sequence = SKAction.sequence(actions)

        worldNode.run(sequence, withKey: "cameraShake")
    }

    private func gridPositionForBase(col: Int, row: Int) -> CGPoint {
        let rowHeight = tileSize * perspectiveFactor

        let x = mapOffset.x + CGFloat(col) * tileSize + tileSize / 2
        let y = mapOffset.y - (CGFloat(row) * rowHeight) - rowHeight

        return CGPoint(x: x, y: y)
    }

    private func getColor(for playerId: String) -> UIColor {
        let hash = playerId.utf8.reduce(0) { $0 + Int($1) }

        let colors: [UIColor] = [
            .red,
            .cyan,
            .green,
            .yellow,
            .magenta,
            .orange,
            .white
        ]

        let index = hash % colors.count
        return colors[index]
    }
}
