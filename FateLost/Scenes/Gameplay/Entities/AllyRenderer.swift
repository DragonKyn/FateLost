import SpriteKit

/// Sizes and colours of the slim health bar over a wounded summon.
private enum HealthBarMetrics {
    static let trackSize = CGSize(width: 26, height: 4)
    static let fillSize = CGSize(width: 24, height: 2)
    static let fillColor = UIColor(red: 0.53, green: 0.82, blue: 0.55, alpha: 1)
    static let lowColor = UIColor(red: 0.82, green: 0.25, blue: 0.2, alpha: 1)
    /// Seconds the bar stays fully lit after a blow.
    static let holdSeconds: Double = 2.5
    static let fadeSeconds: CGFloat = 1
}

/// Draws the player's allies: minions, companions and orbiting blades.
@MainActor
final class AllyRenderer {
    @MainActor
    private final class AllyView: SKNode {
        let shadowSprite: SKSpriteNode
        let body = SKSpriteNode()
        /// A restyled companion's extra, planted or hung beside it. Hidden
        /// unless `configure` gives it a texture.
        let extraSprite = SKSpriteNode()
        /// A slim bar above the ally, shown only once it has been hurt.
        private let healthTrack = SKSpriteNode(color: .black, size: HealthBarMetrics.trackSize)
        private let healthFill = SKSpriteNode(color: HealthBarMetrics.fillColor, size: HealthBarMetrics.fillSize)
        var spriteID: SpriteID?
        var lastSeenFrame = 0
        var facing: CGFloat = 1
        var age: CGFloat = 0
        /// A player's chosen size for this companion, in place of its own
        /// catalogue scale; nil where it hasn't been restyled.
        var scaleOverride: CGFloat?

        init(catalog: SpriteCatalog) {
            shadowSprite = catalog.makeSprite(.shadow)
            super.init()
            shadowSprite.zPosition = -0.5
            addChild(shadowSprite)
            addChild(body)
            extraSprite.isHidden = true
            extraSprite.zPosition = 0.4
            addChild(extraSprite)
            healthTrack.zPosition = 6
            healthTrack.alpha = 0
            healthFill.anchorPoint = CGPoint(x: 0, y: 0.5)
            healthFill.position = CGPoint(x: -HealthBarMetrics.fillSize.width / 2, y: 0)
            healthFill.zPosition = 1
            healthTrack.addChild(healthFill)
            addChild(healthTrack)
        }

        /// Fades the bar in while the ally is hurt and recently struck, and
        /// away again once it has been left alone.
        func showHealth(fraction: Double, timeSinceHurt: Double, height: CGFloat) {
            guard fraction < 1 else {
                healthTrack.alpha = 0
                return
            }
            healthTrack.position = CGPoint(x: 0, y: height)
            healthTrack.alpha = timeSinceHurt < HealthBarMetrics.holdSeconds
                ? 1
                : max(0, 1 - CGFloat(timeSinceHurt - HealthBarMetrics.holdSeconds) / HealthBarMetrics.fadeSeconds)
            healthFill.xScale = max(0.001, CGFloat(fraction))
            healthFill.color = fraction < 0.35 ? HealthBarMetrics.lowColor : HealthBarMetrics.fillColor
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
    /// The local player's own restyles. Never applied to another party
    /// member's summons: their own choices aren't part of what syncs over
    /// the wire today.
    private let companions: CompanionCustomization

    init(catalog: SpriteCatalog, projection: IsometricProjection, layer: SKNode,
        companions: CompanionCustomization = CompanionCustomization()) {
        self.catalog = catalog
        self.projection = projection
        self.layer = layer
        self.companions = companions
        pool = NodePool(prewarm: 12, make: { AllyView(catalog: catalog) }, prepareForReuse: { view in
            view.spriteID = nil
            view.age = 0
            view.alpha = 1
            view.scaleOverride = nil
            view.extraSprite.isHidden = true
            view.showHealth(fraction: 1, timeSinceHurt: 99, height: 0)
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

            let scale = view.scaleOverride ?? ally.spec.scale
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
                view.extraSprite.position = CGPoint(x: view.facing * -16 * scale, y: 4)
            }

            if ally.isMortal {
                view.showHealth(fraction: ally.healthFraction, timeSinceHurt: ally.timeSinceHurt,
                                height: view.body.size.height * scale + 6)
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

        let target = CompanionTarget(summonKey: spec.key)
        let look = target.map { companions[$0] }
        let appearance = target.map { CompanionAppearanceCatalog.option(look?.appearanceID ?? "base", for: $0) }
        if let tintID = appearance?.tint {
            view.body.color = UIColor(rgb: HeroPalette.swatch(tintID, in: HeroPalette.trim).hex)
            view.body.colorBlendFactor = spec.sprite == .allyWisp ? 1 : 0.65
        } else if let tint = spec.tint {
            view.body.color = tint.uiColor
            view.body.colorBlendFactor = spec.sprite == .allyWisp ? 1 : 0.65
        } else {
            view.body.colorBlendFactor = 0
        }
        if let target, let look {
            view.scaleOverride = CGFloat(target.catalogueScale * look.scale.multiplier)
            switch look.extra {
            case .none:
                view.extraSprite.isHidden = true
            case .banner:
                view.extraSprite.texture = catalog.texture(.allyExtraBanner)
                view.extraSprite.size = catalog.size(.allyExtraBanner)
                view.extraSprite.anchorPoint = catalog.anchor(.allyExtraBanner)
                view.extraSprite.color = UIColor(rgb: HeroPalette.swatch(appearance?.tint ?? "brass", in: HeroPalette.trim).hex)
                view.extraSprite.colorBlendFactor = 0.6
                view.extraSprite.isHidden = false
            }
        } else {
            view.scaleOverride = nil
            view.extraSprite.isHidden = true
        }
        let isOrbiting: Bool
        if case .orbit = spec.behavior {
            isOrbiting = true
        } else {
            isOrbiting = false
        }
        view.body.blendMode = spec.sprite == .allyWisp ? .add : .alpha
        view.shadowSprite.isHidden = isOrbiting
        view.shadowSprite.setScale(0.6 * (view.scaleOverride ?? spec.scale))
    }
}
