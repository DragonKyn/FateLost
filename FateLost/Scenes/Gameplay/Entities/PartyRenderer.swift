import SpriteKit

/// Draws the other heroes in a party run, and the markers where the fallen
/// lie, from the party's state. It reads; it never writes.
@MainActor
final class PartyRenderer {
    private final class HeroEntry {
        let view: PlayerView
        let root = SKNode()
        let name: SKLabelNode
        let barBack = SKShapeNode()
        let barFill = SKShapeNode()
        var strideTime: Double = 0
        var lastPosition: CGPoint

        init(view: PlayerView, name: String, position: CGPoint) {
            self.view = view
            self.name = SKLabelNode(text: name)
            lastPosition = position
        }
    }

    private final class MarkerEntry {
        let root: SKNode
        let glow: SKSpriteNode
        let ring: SKShapeNode
        let label: SKLabelNode

        init(root: SKNode, glow: SKSpriteNode, ring: SKShapeNode, label: SKLabelNode) {
            self.root = root
            self.glow = glow
            self.ring = ring
            self.label = label
        }
    }

    private let projection: IsometricProjection
    private let layer: SKNode
    private let glowCatalog: SpriteCatalog
    private var heroes: [Int: HeroEntry] = [:]
    private var markers: [Int: MarkerEntry] = [:]

    init(projection: IsometricProjection, layer: SKNode, catalog: SpriteCatalog) {
        self.projection = projection
        self.layer = layer
        glowCatalog = catalog
    }

    private static let spritesForAHero: [SpriteID] = {
        var ids: [SpriteID] = [.playerAdventurer, .playerBehind, .playerCloak, .playerFront, .shadow, .fxGlow]
        ids.append(contentsOf: StarterWeapons.all.map { $0.spriteID })
        ids.append(contentsOf: FormCatalog.all.map { $0.sprite })
        return ids
    }()

    /// Every hero except the one this phone is playing.
    func update(heroes states: [PartyHeroState], mySlot: Int, roster: [Int: PartyRosterEntry],
                frame: WrappedRenderFrame, dt: CGFloat, time: TimeInterval) {
        var seen = Set<Int>()
        for state in states where state.slot != mySlot {
            seen.insert(state.slot)
            let entry = heroes[state.slot] ?? makeHero(for: state, roster: roster[state.slot])
            heroes[state.slot] = entry

            let screen = projection.toScreen(frame.unwrapped(state.position))
            entry.root.position = screen
            entry.root.zPosition = DepthSorting.z(forScreenY: screen.y)
            entry.root.alpha = state.isConnected ? 1 : 0.4

            var body = PlayerState(position: state.position, maxHealth: max(1, state.maxHealth))
            body.health = state.isDefeated ? 0 : state.health
            body.barrier = state.barrier
            body.velocity = state.velocity
            body.invulnerability = state.isInvulnerable ? 1 : 0
            body.stealth = state.isStealthed ? 1 : 0
            let speed = state.velocity.length
            entry.strideTime += speed > 0.2 ? Double(dt) * Double(speed / 4.2) : 0
            body.strideTime = entry.strideTime
            body.timeSinceHit = 99
            if let weapon = state.weaponSprite { entry.view.setWeapon(weapon) }
            entry.view.setForm(state.form.flatMap { FormCatalog.form($0) })
            entry.view.apply(body, screenVelocity: projection.toScreen(state.velocity), dt: dt)

            let fraction = state.maxHealth > 0 ? CGFloat(max(0, min(1, state.health / state.maxHealth))) : 0
            entry.barBack.isHidden = state.isDefeated
            entry.barFill.isHidden = state.isDefeated
            entry.barFill.xScale = max(0.001, fraction)
            entry.barFill.fillColor = fraction < 0.35 ? UIColor(rgb: 0xD24A3A) : UIColor(rgb: 0x7CCB6A)
        }
        for (slot, entry) in heroes where !seen.contains(slot) {
            entry.root.removeFromParent()
            heroes[slot] = nil
        }
    }

    /// The markers of the fallen. Every marker is drawn, including the local
    /// player's own.
    func update(markers states: [PartyMarkerState], roster: [Int: PartyRosterEntry], frame: WrappedRenderFrame,
                time: TimeInterval) {
        var seen = Set<Int>()
        for state in states {
            seen.insert(state.slot)
            let entry = markers[state.slot] ?? makeMarker(name: roster[state.slot]?.name ?? "")
            markers[state.slot] = entry
            let screen = projection.toScreen(frame.unwrapped(state.position))
            entry.root.position = screen
            entry.root.zPosition = DepthSorting.z(forScreenY: screen.y) + 0.5

            let pulse = 0.65 + 0.25 * CGFloat(sin(time * 3 + Double(state.slot)))
            entry.glow.alpha = state.reviverSlot == nil ? pulse : 1
            entry.ring.isHidden = state.reviverSlot == nil
            if state.reviverSlot != nil {
                entry.ring.path = Self.arc(progress: CGFloat(max(0.02, min(1, state.progress))))
            }
        }
        for (slot, entry) in markers where !seen.contains(slot) {
            entry.root.removeFromParent()
            markers[slot] = nil
        }
    }

    // MARK: Building

    private func makeHero(for state: PartyHeroState, roster: PartyRosterEntry?) -> HeroEntry {
        let look = roster?.look ?? .standard
        let catalog = SpriteCatalog(preloading: Self.spritesForAHero, hero: look)
        let weapon = state.weaponSprite ?? StarterWeapons.definition(for: roster?.weapon ?? "")?.spriteID
            ?? StarterWeapons.sword.spriteID
        let view = PlayerView(catalog: catalog, weaponSprite: weapon, hand: look.build.hand, cloth: look.cloak.clothiness,
                              shoulders: look.build.shoulderHeight)
        let entry = HeroEntry(view: view, name: roster?.name ?? "Ally", position: state.position)
        entry.root.addChild(view)

        entry.name.fontName = "AvenirNext-DemiBold"
        entry.name.fontSize = 11
        entry.name.fontColor = UIColor(rgb: 0xF2E8D0)
        entry.name.verticalAlignmentMode = .bottom
        entry.name.position = CGPoint(x: 0, y: 66)
        entry.name.zPosition = 2
        entry.root.addChild(entry.name)

        let back = CGPath(roundedRect: CGRect(x: -16, y: -2, width: 32, height: 4), cornerWidth: 2, cornerHeight: 2,
                          transform: nil)
        entry.barBack.path = back
        entry.barBack.fillColor = UIColor(white: 0, alpha: 0.6)
        entry.barBack.strokeColor = .clear
        entry.barBack.position = CGPoint(x: 0, y: 62)
        entry.barBack.zPosition = 2
        entry.root.addChild(entry.barBack)
        let fill = CGPath(rect: CGRect(x: 0, y: -2, width: 32, height: 4), transform: nil)
        entry.barFill.path = fill
        entry.barFill.strokeColor = .clear
        entry.barFill.fillColor = UIColor(rgb: 0x7CCB6A)
        entry.barFill.position = CGPoint(x: -16, y: 62)
        entry.barFill.zPosition = 2.1
        entry.root.addChild(entry.barFill)

        layer.addChild(entry.root)
        return entry
    }

    private func makeMarker(name: String) -> MarkerEntry {
        let root = SKNode()
        let glow = glowCatalog.makeSprite(.fxGlow)
        glow.blendMode = .add
        glow.color = UIColor(rgb: 0xB8A0F0)
        glow.colorBlendFactor = 1
        glow.size = CGSize(width: 64, height: 40)
        glow.position = CGPoint(x: 0, y: 4)
        root.addChild(glow)

        // A simple grave cross on a mound: it reads at a glance and belongs to
        // the same dark-fantasy hand as the shrines.
        let cross = SKShapeNode(path: Self.crossPath())
        cross.fillColor = UIColor(rgb: 0xDCD2F0)
        cross.strokeColor = UIColor(rgb: 0x2A2036)
        cross.lineWidth = 1.5
        cross.position = CGPoint(x: 0, y: 6)
        cross.zPosition = 1
        root.addChild(cross)

        let mound = SKShapeNode(ellipseOf: CGSize(width: 34, height: 12))
        mound.fillColor = UIColor(rgb: 0x2B2530)
        mound.strokeColor = UIColor(rgb: 0x120E16)
        mound.position = CGPoint(x: 0, y: 2)
        mound.zPosition = 0.5
        root.addChild(mound)

        let ring = SKShapeNode()
        ring.strokeColor = UIColor(rgb: 0x9BE88A)
        ring.lineWidth = 4
        ring.lineCap = .round
        ring.position = CGPoint(x: 0, y: 26)
        ring.zPosition = 3
        ring.isHidden = true
        root.addChild(ring)

        let label = SKLabelNode(text: name)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 11
        label.fontColor = UIColor(rgb: 0xDCD2F0)
        label.verticalAlignmentMode = .bottom
        label.position = CGPoint(x: 0, y: 44)
        label.zPosition = 3
        root.addChild(label)

        layer.addChild(root)
        return MarkerEntry(root: root, glow: glow, ring: ring, label: label)
    }

    private static func crossPath() -> CGPath {
        let path = CGMutablePath()
        path.addRect(CGRect(x: -2.5, y: 0, width: 5, height: 28))
        path.addRect(CGRect(x: -9, y: 16, width: 18, height: 5))
        return path
    }

    /// A ring that fills clockwise from the top.
    private static func arc(progress: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 13, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi * progress,
                    clockwise: true)
        return path
    }
}
