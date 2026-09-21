import SpriteKit

/// Draws the portals: a glowing ring on the ground, a column of light you can
/// see from across the field, sparks circling it, and its name.
///
/// A portal is rare and worth a detour, so it has to be readable from far
/// away, and a way home has to be told apart from a way in.
@MainActor
final class PortalRenderer {
    @MainActor
    private final class Entry {
        let root = SKNode()
        let glow: SKSpriteNode
        let pillar: SKSpriteNode
        let ring: SKShapeNode
        let core: SKShapeNode
        let sparks: [SKSpriteNode]
        let label = SKLabelNode()

        init(catalog: SpriteCatalog, radius: CGFloat, tint: UIColor) {
            glow = catalog.makeSprite(.fxGlow)
            glow.blendMode = .add
            glow.color = tint
            glow.colorBlendFactor = 1
            glow.setScale(2.6)
            glow.zPosition = -0.002

            pillar = catalog.makeSprite(.fxPillar)
            pillar.blendMode = .add
            pillar.color = tint
            pillar.colorBlendFactor = 1
            pillar.anchorPoint = CGPoint(x: 0.5, y: 0.05)
            pillar.zPosition = 0.002

            let rect = CGRect(x: -radius, y: -radius / 2, width: radius * 2, height: radius)
            ring = SKShapeNode(ellipseIn: rect)
            ring.strokeColor = tint
            ring.lineWidth = 4
            ring.fillColor = tint.withAlphaComponent(0.16)
            ring.zPosition = -0.001
            core = SKShapeNode(ellipseIn: rect.insetBy(dx: radius * 0.42, dy: radius * 0.21))
            core.strokeColor = UIColor(white: 1, alpha: 0.9)
            core.lineWidth = 2
            core.fillColor = tint.withAlphaComponent(0.4)
            core.zPosition = 0

            var spinning: [SKSpriteNode] = []
            for _ in 0..<6 {
                let spark = catalog.makeSprite(.fxSpark)
                spark.blendMode = .add
                spark.color = tint
                spark.colorBlendFactor = 0.6
                spark.zPosition = 0.003
                spinning.append(spark)
            }
            sparks = spinning

            label.fontName = "AvenirNext-Heavy"
            label.fontSize = 12
            label.fontColor = tint
            label.verticalAlignmentMode = .center
            label.zPosition = 0.004

            root.addChild(glow)
            root.addChild(ring)
            root.addChild(core)
            root.addChild(pillar)
            for spark in sparks { root.addChild(spark) }
            root.addChild(label)
        }
    }

    private let catalog: SpriteCatalog
    private let projection: IsometricProjection
    private let radius: CGFloat
    private weak var layer: SKNode?
    private var entries: [Int: Entry] = [:]
    private var seen = Set<Int>()
    private var departed: [Int] = []

    init(catalog: SpriteCatalog, projection: IsometricProjection, pointsPerWorldUnit: CGFloat, layer: SKNode) {
        self.catalog = catalog
        self.projection = projection
        radius = pointsPerWorldUnit * RiftTuning.touchDistance
        self.layer = layer
    }

    var activeCount: Int { entries.count }

    func update(portals: [Portal], frame: WrappedRenderFrame, time: TimeInterval) {
        guard let layer else { return }
        seen.removeAll(keepingCapacity: true)
        let seconds = CGFloat(time)

        for portal in portals {
            seen.insert(portal.id)
            let entry: Entry
            if let existing = entries[portal.id] {
                entry = existing
            } else {
                // A way home is pale gold; a way in is the colour of what is behind it.
                let tint = portal.isReturn ? UIColor(rgb: 0xFFE9A8) : UIColor(rgb: portal.kind.tint)
                entry = Entry(catalog: catalog, radius: radius, tint: tint)
                entry.label.text = portal.isReturn ? "WAY HOME" : portal.kind.name.uppercased()
                layer.addChild(entry.root)
                entries[portal.id] = entry
            }
            let screen = projection.toScreen(frame.unwrapped(portal.position))
            entry.root.position = screen
            entry.root.zPosition = DepthSorting.z(forScreenY: screen.y)

            let phase = CGFloat(portal.id % 7)
            let pulse = 0.5 + 0.5 * sin(seconds * 2.2 + phase)
            entry.glow.alpha = 0.5 + 0.25 * pulse
            entry.pillar.alpha = 0.55 + 0.2 * pulse
            entry.pillar.setScale(1.6 + 0.2 * pulse)
            entry.ring.alpha = 0.75 + 0.25 * pulse
            entry.core.setScale(0.85 + 0.15 * sin(seconds * 3.4 + phase))
            entry.label.position = CGPoint(x: 0, y: radius * 0.5 + 34)
            for (index, spark) in entry.sparks.enumerated() {
                let angle = seconds * 1.6 + CGFloat(index) * (2 * .pi / 6)
                let lift = 10 + 6 * sin(seconds * 3 + CGFloat(index))
                spark.position = CGPoint(x: cos(angle) * radius * 0.8, y: sin(angle) * radius * 0.4 + lift)
                spark.alpha = 0.6 + 0.4 * sin(seconds * 5 + CGFloat(index) * 1.3)
            }
        }

        departed.removeAll(keepingCapacity: true)
        for id in entries.keys where !seen.contains(id) {
            departed.append(id)
        }
        for id in departed {
            entries.removeValue(forKey: id)?.root.removeFromParent()
        }
    }
}
