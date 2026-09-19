import SpriteKit

/// Draws the player's allies: minions, companions and orbiting blades.
@MainActor
final class AllyRenderer {
    @MainActor
    private final class AllyView: SKNode {
        let shadowSprite: SKSpriteNode
        let body = SKSpriteNode()
        var spriteID: SpriteID?
        var lastSeenFrame = 0
        var facing: CGFloat = 1
        var age: CGFloat = 0

        init(catalog: SpriteCatalog) {
            shadowSprite = catalog.makeSprite(.shadow)
            super.init()
            shadowSprite.zPosition = -0.5
            addChild(shadowSprite)
            addChild(body)
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("AllyView is created in code")
        }
    }

    private let catalog: SpriteCatalog
    private let projection: IsometricProjection
    private weak var layer: SKNode?
    private let pool: NodePool<AllyView>
    private var views: [Int: AllyView] = [:]
    private var departed: [Int] = []
    private var frameNumber = 0

    init(catalog: SpriteCatalog, projection: IsometricProjection, layer: SKNode) {
        self.catalog = catalog
        self.projection = projection
        self.layer = layer
        pool = NodePool(prewarm: 12, make: { AllyView(catalog: catalog) }, prepareForReuse: { view in
            view.spriteID = nil
            view.age = 0
            view.alpha = 1
        })
    }

    var activeCount: Int { views.count }

    func update(allies: [Ally], frame: WrappedRenderFrame, time: TimeInterval, dt: CGFloat) {
        frameNumber &+= 1
        guard let layer else { return }
        let seconds = CGFloat(time)

        for ally in allies {
            let view: AllyView
            if let existing = views[ally.id] {
                view = existing
            } else {
                view = pool.acquire()
                layer.addChild(view)
                views[ally.id] = view
                configure(view, for: ally.spec, id: ally.id)
            }
            view.lastSeenFrame = frameNumber
            view.age += dt

            let screen = projection.toScreen(frame.unwrapped(ally.position))
            view.position = screen
            view.zPosition = DepthSorting.z(forScreenY: screen.y)

            let scale = ally.spec.scale
            // A quick lunge when striking.
            let lunge = CGFloat(max(0, 1 - ally.timeSinceAttack / 0.18))
            let screenHeading = projection.toScreen(ally.heading)

            if case .orbit = ally.spec.behavior {
                view.body.zRotation = atan2(screenHeading.y, screenHeading.x)
                view.body.position = CGPoint(x: 0, y: 18 + sin(seconds * 6 + CGFloat(ally.id)) * 2)
                view.body.setScale(scale * (1 + 0.25 * lunge))
            } else {
                if abs(screenHeading.x) > 0.2 {
                    view.facing = screenHeading.x >= 0 ? 1 : -1
                }
                let bob = abs(sin(seconds * 8 + CGFloat(ally.id))) * 1.6
                view.body.position = CGPoint(x: view.facing * lunge * 5, y: bob)
                view.body.xScale = view.facing * scale * (1 + 0.1 * lunge)
                view.body.yScale = scale * (1 - 0.06 * lunge)
                view.body.zRotation = 0
            }

            // Summons rise in and fade as they expire.
            let fadeIn = min(1, view.age / 0.25)
            let fadeOut = ally.remaining.isFinite ? CGFloat(min(1, ally.remaining / 0.6)) : 1
            view.alpha = fadeIn * fadeOut * CGFloat(ally.spec.tint?.alpha ?? 1)
        }

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

    private func configure(_ view: AllyView, for spec: SummonSpec, id: Int) {
        let sprite = spec.sprite(forAlly: id)
        view.spriteID = sprite
        view.body.texture = catalog.texture(sprite)
        view.body.size = catalog.size(sprite)
        view.body.anchorPoint = catalog.anchor(sprite)
        if let tint = spec.tint {
            view.body.color = tint.uiColor
            view.body.colorBlendFactor = spec.sprite == .allyWisp ? 1 : 0.65
        } else {
            view.body.colorBlendFactor = 0
        }
        let isOrbiting: Bool
        if case .orbit = spec.behavior {
            isOrbiting = true
        } else {
            isOrbiting = false
        }
        view.body.blendMode = spec.sprite == .allyWisp ? .add : .alpha
        view.shadowSprite.isHidden = isOrbiting
        view.shadowSprite.setScale(0.6 * spec.scale)
    }
}
