import SpriteKit

/// One enemy on screen. Pure presentation; reads simulation arrays each frame.
@MainActor
final class EnemyView: SKNode {
    let shadowSprite: SKSpriteNode
    let body: SKSpriteNode
    let hitbox: SKSpriteNode
    fileprivate(set) var spriteID: SpriteID?
    fileprivate var lastSeenFrame = 0
    fileprivate var flash: CGFloat = 0
    fileprivate var facingSign: CGFloat = 1
    fileprivate var phase: CGFloat = 0

    init(catalog: SpriteCatalog) {
        shadowSprite = catalog.makeSprite(.shadow)
        body = SKSpriteNode()
        hitbox = catalog.makeSprite(.fxRing)
        super.init()
        shadowSprite.zPosition = -0.5
        shadowSprite.setScale(0.72)
        addChild(shadowSprite)
        addChild(body)
        hitbox.color = .red
        hitbox.colorBlendFactor = 1
        hitbox.alpha = 0.7
        hitbox.zPosition = 0.2
        hitbox.isHidden = true
        addChild(hitbox)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("EnemyView is created in code")
    }

    fileprivate func configure(sprite id: SpriteID, catalog: SpriteCatalog) {
        guard spriteID != id else { return }
        spriteID = id
        body.texture = catalog.texture(id)
        body.size = catalog.size(id)
        body.anchorPoint = catalog.anchor(id)
    }
}

/// Draws every living enemy, recycling views through a pool.
///
/// Views are keyed by the simulation's stable enemy id. Each frame the
/// renderer walks the enemy arrays once, positions each view at the image of
/// its enemy nearest the camera, and returns views whose enemy is gone to the
/// pool. Nothing is allocated in steady state.
@MainActor
final class EnemyRenderer {
    private let catalog: SpriteCatalog
    private let projection: IsometricProjection
    private weak var layer: SKNode?
    private let pool: NodePool<EnemyView>
    private var views: [Int: EnemyView] = [:]
    private var departed: [Int] = []
    private var frameNumber = 0
    /// Scene points per world unit, for sizing hitbox rings.
    private let pointsPerWorldUnit: CGFloat

    private enum Style {
        static let bobHeight: CGFloat = 1.8
        static let bobFrequency: CGFloat = 9
        static let sway: CGFloat = 0.09
        static let flashDecay: CGFloat = 9
        static let windupTint = UIColor(red: 1, green: 0.25, blue: 0.15, alpha: 1)
    }

    init(catalog: SpriteCatalog, projection: IsometricProjection, layer: SKNode, pointsPerWorldUnit: CGFloat) {
        self.catalog = catalog
        self.projection = projection
        self.layer = layer
        self.pointsPerWorldUnit = pointsPerWorldUnit
        pool = NodePool(prewarm: 120, make: { EnemyView(catalog: catalog) }, prepareForReuse: { view in
            view.flash = 0
            view.body.colorBlendFactor = 0
            view.alpha = 1
        })
    }

    var activeCount: Int { views.count }

    func update(enemies: EnemyStore, frame: WrappedRenderFrame, time: TimeInterval, dt: CGFloat,
                showHitboxes: Bool) {
        frameNumber &+= 1
        guard let layer else { return }
        let seconds = CGFloat(time)

        for index in 0..<enemies.count {
            let id = enemies.ids[index]
            let view: EnemyView
            if let existing = views[id] {
                view = existing
            } else {
                view = pool.acquire()
                view.phase = CGFloat(id % 97) * 0.37
                layer.addChild(view)
                views[id] = view
            }
            view.lastSeenFrame = frameNumber

            let definition = enemies.definition(at: index)
            view.configure(sprite: definition.spriteID, catalog: catalog)

            let screen = projection.toScreen(frame.unwrapped(enemies.positions[index]))
            view.position = screen
            view.zPosition = DepthSorting.z(forScreenY: screen.y)

            // Face the direction of travel on screen.
            let headingX = projection.toScreen(enemies.heading[index]).x
            if abs(headingX) > 4 {
                view.facingSign = headingX >= 0 ? 1 : -1
            }

            // A scurrying waddle, frozen into a crouch while winding up.
            let windingUp = enemies.windup[index] > 0
            let t = seconds * Style.bobFrequency * enemies.speedScale[index] + view.phase
            if windingUp {
                let progress = 1 - CGFloat(enemies.windup[index] / max(definition.attackWindup, 0.001))
                view.body.position = .zero
                view.body.xScale = view.facingSign * (1 + 0.14 * progress)
                view.body.yScale = 1 - 0.12 * progress
                view.body.zRotation = -0.22 * progress * view.facingSign
            } else {
                view.body.position = CGPoint(x: 0, y: abs(sin(t)) * Style.bobHeight)
                view.body.xScale = view.facingSign
                view.body.yScale = 1
                view.body.zRotation = sin(t) * Style.sway
            }

            // White hit flash wins over the red strike telegraph.
            view.flash = max(0, view.flash - Style.flashDecay * dt)
            if view.flash > 0 {
                view.body.color = .white
                view.body.colorBlendFactor = view.flash
            } else if windingUp {
                view.body.color = Style.windupTint
                view.body.colorBlendFactor = 0.45
            } else {
                view.body.colorBlendFactor = 0
            }

            view.hitbox.isHidden = !showHitboxes
            if showHitboxes {
                let diameter = definition.radius * 2 * pointsPerWorldUnit
                view.hitbox.size = CGSize(width: diameter, height: diameter / 2)
            }
        }

        // Return views whose enemy died or was removed.
        departed.removeAll(keepingCapacity: true)
        for (id, view) in views where view.lastSeenFrame != frameNumber {
            departed.append(id)
        }
        for id in departed {
            if let view = views.removeValue(forKey: id) {
                pool.release(view)
            }
        }
    }

    /// Flashes an enemy white after a hit.
    func flash(enemyID: Int) {
        views[enemyID]?.flash = 1
    }

    /// Screen position and look of an enemy, for death effects.
    func snapshot(enemyID: Int) -> (position: CGPoint, spriteID: SpriteID?, facing: CGFloat)? {
        guard let view = views[enemyID] else { return nil }
        return (view.position, view.spriteID, view.facingSign)
    }
}
