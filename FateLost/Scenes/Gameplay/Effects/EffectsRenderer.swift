import SpriteKit

/// Short-lived combat visuals: slashes, sparks, damage numbers, falling
/// bodies, stains and bursts.
///
/// Every effect remembers its *world* position and is re-placed each frame
/// through the render frame, so effects stay glued to the ground across wrap
/// seams and render-frame rebases. Nodes come from per-kind pools and each
/// kind has a ceiling, so a screen-filling brawl costs a bounded amount.
@MainActor
final class EffectsRenderer {
    private enum Kind {
        case slash
        case spark
        case number
        case corpse
        case dust
        case splat
        case burst
        case shockwave
    }

    private struct Effect {
        let kind: Kind
        let node: SKNode
        let worldPosition: CGPoint
        var age: CGFloat = 0
        let lifetime: CGFloat
        /// Kind-specific: slash sweep sign, corpse fall direction, number drift.
        let variant: CGFloat
        /// Kind-specific size: slash range, burst radius (world units).
        let magnitude: CGFloat
    }

    private enum Limit {
        static let numbers = 40
        static let splats = 90
        static let corpses = 40
    }

    private let catalog: SpriteCatalog
    private let projection: IsometricProjection
    /// Scene points per world unit along a world axis.
    private let pointsPerWorldUnit: CGFloat
    private weak var standingLayer: SKNode?
    private weak var decalLayer: SKNode?
    private weak var overlayLayer: SKNode?

    private var effects: [Effect] = []
    private var pools: [Kind: [SKNode]] = [:]
    private var counts: [Kind: Int] = [:]

    init(catalog: SpriteCatalog, projection: IsometricProjection, pointsPerWorldUnit: CGFloat,
         standingLayer: SKNode, decalLayer: SKNode, overlayLayer: SKNode) {
        self.catalog = catalog
        self.projection = projection
        self.pointsPerWorldUnit = pointsPerWorldUnit
        self.standingLayer = standingLayer
        self.decalLayer = decalLayer
        self.overlayLayer = overlayLayer
        effects.reserveCapacity(256)
    }

    var activeCount: Int { effects.count }

    // MARK: - Spawning

    /// A crescent sweeping through the swing arc, lying on the ground.
    func slash(at position: CGPoint, direction: CGPoint, range: CGFloat) {
        guard let container = acquire(.slash), let blade = container.children.first else { return }
        // Ground-plane orientation: world angle, then the isometric squash
        // (see `groundContainer`).
        let angle = atan2(direction.y, direction.x)
        blade.zRotation = angle + .pi / 4
        blade.setScale(1)
        let diameter = range * 2
        (blade as? SKSpriteNode)?.size = CGSize(width: diameter, height: diameter)
        container.alpha = 1
        add(Effect(kind: .slash, node: container, worldPosition: position, lifetime: 0.2,
                   variant: angle, magnitude: range), layer: overlayLayer)
    }

    func spark(at position: CGPoint, isCritical: Bool) {
        guard let sprite = acquire(.spark) as? SKSpriteNode else { return }
        sprite.color = isCritical ? UIColor(rgb: 0xFFD27A) : UIColor(rgb: 0xFFF6E8)
        sprite.colorBlendFactor = 1
        sprite.zRotation = CGFloat.random(in: 0 ... .pi)
        add(Effect(kind: .spark, node: sprite, worldPosition: position, lifetime: isCritical ? 0.2 : 0.13,
                   variant: isCritical ? 1.6 : 1, magnitude: 0), layer: overlayLayer)
    }

    func damageNumber(_ amount: Double, at position: CGPoint, isCritical: Bool) {
        // Under load, ordinary numbers give way so crits still show.
        if counts[.number, default: 0] >= Limit.numbers {
            guard isCritical, recycleOldest(.number) else { return }
        }
        guard let label = acquire(.number) as? SKLabelNode else { return }
        label.text = isCritical ? "\(Int(amount.rounded()))!" : "\(Int(amount.rounded()))"
        label.fontSize = isCritical ? 21 : 15
        label.fontColor = isCritical ? UIColor(rgb: 0xFFC24A) : UIColor(rgb: 0xF3E9D8)
        add(Effect(kind: .number, node: label, worldPosition: position, lifetime: isCritical ? 0.85 : 0.6,
                   variant: CGFloat.random(in: -10...10), magnitude: 0), layer: overlayLayer)
    }

    /// The enemy's body topples and fades where it fell.
    func corpse(at position: CGPoint, spriteID: SpriteID, facing: CGFloat, tint: UIColor) {
        if counts[.corpse, default: 0] >= Limit.corpses {
            guard recycleOldest(.corpse) else { return }
        }
        guard let sprite = acquire(.corpse) as? SKSpriteNode else { return }
        sprite.texture = catalog.texture(spriteID)
        sprite.size = catalog.size(spriteID)
        sprite.anchorPoint = catalog.anchor(spriteID)
        sprite.xScale = facing
        sprite.yScale = 1
        sprite.zRotation = 0
        sprite.color = tint
        sprite.colorBlendFactor = 0.55
        sprite.alpha = 1
        add(Effect(kind: .corpse, node: sprite, worldPosition: position, lifetime: 0.75,
                   variant: facing, magnitude: 0), layer: standingLayer)

        if let dust = acquire(.dust) as? SKSpriteNode {
            dust.color = UIColor(rgb: 0x8A8078)
            dust.colorBlendFactor = 1
            add(Effect(kind: .dust, node: dust, worldPosition: position, lifetime: 0.45, variant: 0,
                       magnitude: 0), layer: overlayLayer)
        }
    }

    /// A stain on the ground that lingers, then fades.
    func splat(at position: CGPoint, color: UIColor) {
        if counts[.splat, default: 0] >= Limit.splats {
            guard recycleOldest(.splat) else { return }
        }
        guard let sprite = acquire(.splat) as? SKSpriteNode else { return }
        sprite.color = color
        sprite.colorBlendFactor = 1
        sprite.xScale = CGFloat.random(in: 0.8...1.2) * (Bool.random() ? 1 : -1)
        sprite.yScale = CGFloat.random(in: 0.8...1.1)
        add(Effect(kind: .splat, node: sprite, worldPosition: position, lifetime: 9, variant: 0, magnitude: 0),
            layer: decalLayer)
    }

    /// A flash and expanding ring on the ground for area damage.
    func burst(at position: CGPoint, radius: CGFloat, color: UIColor) {
        if let glow = acquire(.burst) as? SKSpriteNode {
            glow.color = color
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            add(Effect(kind: .burst, node: glow, worldPosition: position, lifetime: 0.32, variant: 0,
                       magnitude: radius), layer: overlayLayer)
        }
        if let container = acquire(.shockwave), let ring = container.children.first as? SKSpriteNode {
            ring.color = color
            ring.colorBlendFactor = 1
            add(Effect(kind: .shockwave, node: container, worldPosition: position, lifetime: 0.35, variant: 0,
                       magnitude: radius), layer: overlayLayer)
        }
    }

    /// Clears everything, e.g. when a run restarts.
    func removeAll() {
        for effect in effects {
            release(effect)
        }
        effects.removeAll(keepingCapacity: true)
    }

    // MARK: - Frame update

    func update(frame: WrappedRenderFrame, dt: CGFloat) {
        var index = effects.count - 1
        while index >= 0 {
            effects[index].age += dt
            let effect = effects[index]
            if effect.age >= effect.lifetime {
                release(effect)
                effects.swapRemove(at: index)
            } else {
                apply(effect, frame: frame)
            }
            index -= 1
        }
    }

    private func apply(_ effect: Effect, frame: WrappedRenderFrame) {
        let t = effect.age / effect.lifetime
        let base = projection.toScreen(frame.unwrapped(effect.worldPosition))
        let node = effect.node
        node.position = base

        switch effect.kind {
        case .slash:
            // Sweeps a little through the arc and thins out as it goes.
            if let blade = node.children.first {
                blade.zRotation = effect.variant + .pi / 4 + (t - 0.5) * 0.5
                blade.setScale(0.85 + 0.2 * t)
            }
            node.alpha = t < 0.25 ? 1 : 1 - (t - 0.25) / 0.75
        case .spark:
            node.setScale((0.6 + 0.8 * t) * effect.variant)
            node.alpha = 1 - t
            node.position = base + CGPoint(x: 0, y: 16)
        case .number:
            let rise = 30 * (1 - (1 - t) * (1 - t))
            node.position = base + CGPoint(x: effect.variant * t, y: 30 + rise)
            node.setScale(t < 0.12 ? 1.35 - t * 2.9 : 1)
            node.alpha = t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4
        case .corpse:
            // Topples away from the killing blow, then fades into the ground.
            let fall = min(1, t / 0.35)
            let eased = 1 - (1 - fall) * (1 - fall)
            node.zRotation = -effect.variant * eased * (.pi / 2) * 0.9
            node.position = base + CGPoint(x: 0, y: -4 * eased)
            node.alpha = t < 0.5 ? 1 : 1 - (t - 0.5) / 0.5
            node.zPosition = DepthSorting.z(forScreenY: base.y)
        case .dust:
            node.setScale(0.35 + 0.5 * t)
            node.alpha = 0.55 * (1 - t)
            node.position = base + CGPoint(x: 0, y: 8 + 10 * t)
        case .splat:
            node.alpha = t < 0.7 ? 0.85 : 0.85 * (1 - (t - 0.7) / 0.3)
        case .burst:
            let size = effect.magnitude * 2 * pointsPerWorldUnit * (0.6 + 0.5 * t)
            (node as? SKSpriteNode)?.size = CGSize(width: size, height: size * 0.6)
            node.alpha = 0.9 * (1 - t)
        case .shockwave:
            if let ring = node.children.first as? SKSpriteNode {
                let diameter = effect.magnitude * 2 * (0.3 + 0.8 * t)
                ring.size = CGSize(width: diameter, height: diameter)
            }
            node.alpha = 1 - t
        }
    }

    // MARK: - Pooling

    private func add(_ effect: Effect, layer: SKNode?) {
        guard let layer else { return }
        if effect.node.parent !== layer {
            effect.node.removeFromParent()
            layer.addChild(effect.node)
        }
        counts[effect.kind, default: 0] += 1
        effects.append(effect)
        // Hidden until this frame's update places it.
        effect.node.alpha = 0
    }

    private func acquire(_ kind: Kind) -> SKNode? {
        if let node = pools[kind]?.popLast() {
            node.isHidden = false
            return node
        }
        return make(kind)
    }

    private func release(_ effect: Effect) {
        effect.node.removeFromParent()
        effect.node.isHidden = true
        pools[effect.kind, default: []].append(effect.node)
        counts[effect.kind, default: 1] -= 1
    }

    /// Ends the oldest effect of a kind early to make room.
    private func recycleOldest(_ kind: Kind) -> Bool {
        guard let index = effects.firstIndex(where: { $0.kind == kind }) else { return false }
        release(effects[index])
        effects.remove(at: index)
        return true
    }

    private func make(_ kind: Kind) -> SKNode {
        switch kind {
        case .slash:
            return groundContainer(holding: catalog.makeSprite(.fxSlash), zPosition: 1)
        case .shockwave:
            return groundContainer(holding: catalog.makeSprite(.fxRing), zPosition: 1)
        case .spark:
            let sprite = catalog.makeSprite(.fxSpark)
            sprite.blendMode = .add
            sprite.zPosition = 3
            return sprite
        case .number:
            let label = SKLabelNode(fontNamed: "Georgia-Bold")
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 10
            return label
        case .corpse:
            return SKSpriteNode()
        case .dust:
            let sprite = catalog.makeSprite(.fxGlow)
            sprite.size = CGSize(width: 40, height: 26)
            sprite.zPosition = 2
            return sprite
        case .splat:
            let sprite = catalog.makeSprite(.fxSplat)
            sprite.zPosition = 1
            return sprite
        case .burst:
            let sprite = catalog.makeSprite(.fxGlow)
            sprite.zPosition = 2
            return sprite
        }
    }

    /// A node whose child, sized in world units and rotated by a world
    /// angle + π/4, appears lying flat on the isometric ground.
    ///
    /// The projection is `diag(k, -k/2) · rotation(45°)` with `k` the scene
    /// points per world unit, so the container applies the scale and the
    /// child supplies the rotation.
    private func groundContainer(holding child: SKSpriteNode, zPosition: CGFloat) -> SKNode {
        let container = SKNode()
        container.xScale = pointsPerWorldUnit
        container.yScale = -pointsPerWorldUnit / 2
        container.zPosition = zPosition
        child.blendMode = .add
        container.addChild(child)
        return container
    }
}
