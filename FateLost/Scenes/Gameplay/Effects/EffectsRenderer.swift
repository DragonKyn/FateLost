import SpriteKit

/// Short-lived combat visuals: slashes, sparks, damage numbers, falling
/// bodies, stains, bursts, cones, chains, strike warnings, pillars of light,
/// dash afterimages and floating text.
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
        case cone
        case chain
        case telegraph
        case pillar
        case ghost
        case mote
        case text
    }

    private struct Effect {
        let kind: Kind
        let node: SKNode
        let worldPosition: CGPoint
        var age: CGFloat = 0
        let lifetime: CGFloat
        /// Kind-specific: slash angle, corpse fall direction, number drift,
        /// mote drift.
        let variant: CGFloat
        /// Kind-specific size: slash range, burst radius (world units).
        let magnitude: CGFloat
        /// Seconds before the effect appears.
        var delay: CGFloat = 0
    }

    private enum Limit {
        static let numbers = 40
        static let splats = 90
        static let corpses = 40
        static let chains = 24
        static let telegraphs = 60
        static let motes = 80
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

    // MARK: - Weapon and hit effects

    /// A crescent sweeping through the swing arc, lying on the ground.
    func slash(at position: CGPoint, direction: CGPoint, range: CGFloat) {
        guard let container = acquire(.slash), let blade = container.children.first as? SKSpriteNode else { return }
        // Ground-plane orientation: world angle, then the isometric squash
        // (see `groundContainer`).
        let angle = atan2(direction.y, direction.x)
        blade.zRotation = angle + .pi / 4
        blade.setScale(1)
        let diameter = range * 2
        blade.size = CGSize(width: diameter, height: diameter)
        container.alpha = 1
        add(Effect(kind: .slash, node: container, worldPosition: position, lifetime: 0.2,
                   variant: angle, magnitude: range), layer: overlayLayer)
    }

    func spark(at position: CGPoint, isCritical: Bool, color: UIColor? = nil) {
        guard let sprite = acquire(.spark) as? SKSpriteNode else { return }
        sprite.color = color ?? (isCritical ? UIColor(rgb: 0xFFD27A) : UIColor(rgb: 0xFFF6E8))
        sprite.colorBlendFactor = 1
        sprite.zRotation = CGFloat.random(in: 0 ... .pi)
        add(Effect(kind: .spark, node: sprite, worldPosition: position, lifetime: isCritical ? 0.2 : 0.13,
                   variant: isCritical ? 1.6 : 1, magnitude: 0), layer: overlayLayer)
    }

    func damageNumber(_ amount: Double, at position: CGPoint, isCritical: Bool, color: UIColor? = nil,
                      small: Bool = false) {
        // Under load, ordinary numbers give way so crits still show.
        if counts[.number, default: 0] >= Limit.numbers {
            guard isCritical, recycleOldest(.number) else { return }
        }
        guard let label = acquire(.number) as? SKLabelNode else { return }
        label.text = isCritical ? "\(Int(amount.rounded()))!" : "\(Int(amount.rounded()))"
        label.fontSize = isCritical ? 21 : (small ? 12 : 15)
        label.fontColor = isCritical ? UIColor(rgb: 0xFFC24A) : (color ?? UIColor(rgb: 0xF3E9D8))
        add(Effect(kind: .number, node: label, worldPosition: position, lifetime: isCritical ? 0.85 : 0.6,
                   variant: CGFloat.random(in: -10...10), magnitude: 0), layer: overlayLayer)
    }

    /// Words that float up from a point: "Dodge", healing, "Level 4".
    func floatingText(_ text: String, at position: CGPoint, color: UIColor, size: CGFloat = 16,
                      lifetime: CGFloat = 0.9) {
        guard let label = acquire(.text) as? SKLabelNode else { return }
        label.text = text
        label.fontSize = size
        label.fontColor = color
        add(Effect(kind: .text, node: label, worldPosition: position, lifetime: lifetime, variant: 0,
                   magnitude: size), layer: overlayLayer)
    }

    /// The enemy's body topples and fades where it fell.
    func corpse(at position: CGPoint, spriteID: SpriteID, facing: CGFloat, tint: UIColor, scale: CGFloat = 1) {
        if counts[.corpse, default: 0] >= Limit.corpses {
            guard recycleOldest(.corpse) else { return }
        }
        guard let sprite = acquire(.corpse) as? SKSpriteNode else { return }
        sprite.texture = catalog.texture(spriteID)
        sprite.size = catalog.size(spriteID)
        sprite.anchorPoint = catalog.anchor(spriteID)
        sprite.xScale = facing * scale
        sprite.yScale = scale
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

    // MARK: - Skill effects

    /// A flash and expanding ring on the ground for area damage.
    func burst(at position: CGPoint, radius: CGFloat, color: UIColor, glows: Bool = true) {
        if let glow = acquire(.burst) as? SKSpriteNode {
            glow.color = color
            glow.colorBlendFactor = 1
            glow.blendMode = glows ? .add : .alpha
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

    /// A widening shockwave ring alone, optionally after a delay.
    func ring(at position: CGPoint, radius: CGFloat, color: UIColor, lifetime: CGFloat = 0.45, delay: CGFloat = 0) {
        guard let container = acquire(.shockwave), let ring = container.children.first as? SKSpriteNode else { return }
        ring.color = color
        ring.colorBlendFactor = 1
        add(Effect(kind: .shockwave, node: container, worldPosition: position, lifetime: lifetime, variant: 0,
                   magnitude: radius, delay: delay), layer: overlayLayer)
    }

    /// A wedge of force on the ground.
    func cone(at position: CGPoint, direction: CGPoint, range: CGFloat, arcDegrees: Double, color: UIColor) {
        guard let container = acquire(.cone), let wedge = container.children.first as? SKSpriteNode else { return }
        let angle = atan2(direction.y, direction.x)
        wedge.size = CGSize(width: range * 2, height: range * 2)
        wedge.xScale = 1
        wedge.yScale = min(1.9, CGFloat(arcDegrees) / 90)
        wedge.zRotation = angle + .pi / 4
        wedge.color = color
        wedge.colorBlendFactor = 1
        add(Effect(kind: .cone, node: container, worldPosition: position, lifetime: 0.3, variant: angle,
                   magnitude: range), layer: overlayLayer)
    }

    /// A jagged arc of energy through a chain of points (continuous across
    /// the wrap seam, relative to the first).
    func chain(through points: [CGPoint], color: UIColor, frame: WrappedRenderFrame) {
        guard points.count > 1 else { return }
        if counts[.chain, default: 0] >= Limit.chains {
            guard recycleOldest(.chain) else { return }
        }
        guard let shape = acquire(.chain) as? SKShapeNode else { return }
        let first = points[0]
        let path = CGMutablePath()
        let lift = CGPoint(x: 0, y: 16)
        path.move(to: lift)
        for index in 1..<points.count {
            let from = projection.toScreen(points[index - 1] - first) + lift
            let to = projection.toScreen(points[index] - first) + lift
            // Two jittered kinks per leap.
            let normal = CGPoint(x: -(to.y - from.y), y: to.x - from.x).normalized
            for fraction in [CGFloat(0.33), 0.66] {
                let point = from + (to - from) * fraction + normal * CGFloat.random(in: -9...9)
                path.addLine(to: point)
            }
            path.addLine(to: to)
        }
        shape.path = path
        shape.strokeColor = color
        add(Effect(kind: .chain, node: shape, worldPosition: first, lifetime: 0.22, variant: 0, magnitude: 0),
            layer: overlayLayer)
    }

    /// A warning circle that fills until the impact lands.
    func telegraph(at position: CGPoint, radius: CGFloat, delay: CGFloat, color: UIColor) {
        if counts[.telegraph, default: 0] >= Limit.telegraphs {
            guard recycleOldest(.telegraph) else { return }
        }
        guard let container = acquire(.telegraph), let disc = container.children.first as? SKSpriteNode else { return }
        disc.color = color
        disc.colorBlendFactor = 1
        add(Effect(kind: .telegraph, node: container, worldPosition: position, lifetime: max(delay, 0.1), variant: 0,
                   magnitude: radius), layer: decalLayer)
    }

    /// A shaft of light from above.
    func pillar(at position: CGPoint, color: UIColor, width: CGFloat = 1, height: CGFloat = 1,
                lifetime: CGFloat = 0.4) {
        guard let sprite = acquire(.pillar) as? SKSpriteNode else { return }
        sprite.color = color
        sprite.colorBlendFactor = 1
        sprite.xScale = width
        sprite.yScale = height
        add(Effect(kind: .pillar, node: sprite, worldPosition: position, lifetime: lifetime, variant: width,
                   magnitude: height), layer: overlayLayer)
    }

    /// Fading silhouettes along a dash.
    func afterimages(from start: CGPoint, to end: CGPoint, spriteID: SpriteID, color: UIColor, facing: CGFloat) {
        let steps = 4
        for step in 0..<steps {
            guard let ghost = acquire(.ghost) as? SKSpriteNode else { return }
            ghost.texture = catalog.texture(spriteID)
            ghost.size = catalog.size(spriteID)
            ghost.anchorPoint = catalog.anchor(spriteID)
            ghost.xScale = facing
            ghost.color = color
            ghost.colorBlendFactor = 0.8
            let t = CGFloat(step) / CGFloat(steps)
            let point = start + (end - start) * t
            add(Effect(kind: .ghost, node: ghost, worldPosition: point, lifetime: 0.35, variant: 0, magnitude: 0,
                       delay: t * 0.08), layer: standingLayer)
        }
    }

    /// Sparks of light rising from a point.
    func motes(at position: CGPoint, count: Int, color: UIColor, spread: CGFloat = 1, lifetime: CGFloat = 1) {
        for _ in 0..<count {
            if counts[.mote, default: 0] >= Limit.motes {
                guard recycleOldest(.mote) else { return }
            }
            guard let sprite = acquire(.mote) as? SKSpriteNode else { return }
            sprite.color = color
            sprite.colorBlendFactor = 1
            let angle = CGFloat.random(in: 0 ..< 2 * .pi)
            let distance = CGFloat.random(in: 0...spread)
            let offset = CGPoint(x: cos(angle), y: sin(angle)) * distance
            add(Effect(kind: .mote, node: sprite, worldPosition: position + offset,
                       lifetime: lifetime * CGFloat.random(in: 0.7...1.2),
                       variant: CGFloat.random(in: -14...14), magnitude: CGFloat.random(in: 50...110),
                       delay: CGFloat.random(in: 0...0.2)), layer: overlayLayer)
        }
    }

    /// The level-up eruption: a column of fate-light, rings racing outward
    /// across the burst's reach, and embers rising.
    func levelUp(at position: CGPoint, radius: CGFloat) {
        let gold = VisualStyle.fate.color
        pillar(at: position, color: gold, width: 2.4, height: 1.6, lifetime: 0.9)
        pillar(at: position, color: .white, width: 1.1, height: 1.9, lifetime: 0.6)
        burst(at: position, radius: radius, color: gold)
        ring(at: position, radius: radius * 1.05, color: gold, lifetime: 0.6)
        ring(at: position, radius: radius * 0.75, color: UIColor(rgb: 0xFFF3C8), lifetime: 0.55, delay: 0.12)
        ring(at: position, radius: radius * 1.25, color: UIColor(rgb: 0xFF9A3A), lifetime: 0.7, delay: 0.2)
        motes(at: position, count: 26, color: gold, spread: radius * 0.6, lifetime: 1.3)
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
            if effects[index].delay > 0 {
                effects[index].delay -= dt
                effects[index].node.alpha = 0
                index -= 1
                continue
            }
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
        case .text:
            let rise = 38 * (1 - (1 - t) * (1 - t))
            node.position = base + CGPoint(x: 0, y: 46 + rise)
            node.setScale(t < 0.15 ? 0.7 + t * 2 : 1)
            node.alpha = t < 0.65 ? 1 : 1 - (t - 0.65) / 0.35
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
        case .cone:
            if let wedge = node.children.first {
                wedge.xScale = 0.75 + 0.3 * t
            }
            node.alpha = t < 0.2 ? 1 : 1 - (t - 0.2) / 0.8
        case .chain:
            node.alpha = t < 0.3 ? 1 : 1 - (t - 0.3) / 0.7
        case .telegraph:
            if let disc = node.children.first as? SKSpriteNode {
                let diameter = effect.magnitude * 2 * (0.25 + 0.75 * t)
                disc.size = CGSize(width: diameter, height: diameter)
            }
            if let rim = node.children.last as? SKSpriteNode {
                rim.size = CGSize(width: effect.magnitude * 2, height: effect.magnitude * 2)
            }
            node.alpha = 0.35 + 0.45 * t
        case .pillar:
            node.xScale = effect.variant * (t < 0.2 ? t / 0.2 : 1 - (t - 0.2) * 0.4)
            node.yScale = effect.magnitude
            node.alpha = t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85
            node.zPosition = 20
        case .ghost:
            node.alpha = 0.55 * (1 - t)
            node.zPosition = DepthSorting.z(forScreenY: base.y) - 0.01
        case .mote:
            let rise = effect.magnitude * t
            node.position = base + CGPoint(x: effect.variant * t, y: 10 + rise)
            node.setScale(0.5 + 0.4 * (1 - t))
            node.alpha = t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8
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
        case .cone:
            return groundContainer(holding: catalog.makeSprite(.fxCone), zPosition: 1)
        case .telegraph:
            let container = groundContainer(holding: catalog.makeSprite(.fxDisc), zPosition: 0.5)
            let rim = catalog.makeSprite(.fxRing)
            rim.blendMode = .add
            rim.color = .white
            rim.colorBlendFactor = 0.4
            container.addChild(rim)
            return container
        case .spark:
            let sprite = catalog.makeSprite(.fxSpark)
            sprite.blendMode = .add
            sprite.zPosition = 3
            return sprite
        case .number, .text:
            let label = SKLabelNode(fontNamed: "Georgia-Bold")
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 10
            return label
        case .corpse, .ghost:
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
        case .chain:
            let shape = SKShapeNode()
            shape.lineWidth = 2.6
            shape.lineCap = .round
            shape.lineJoin = .round
            shape.blendMode = .add
            shape.zPosition = 15
            return shape
        case .pillar:
            let sprite = catalog.makeSprite(.fxPillar)
            sprite.blendMode = .add
            return sprite
        case .mote:
            let sprite = catalog.makeSprite(.fxSpark)
            sprite.blendMode = .add
            sprite.zPosition = 12
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
