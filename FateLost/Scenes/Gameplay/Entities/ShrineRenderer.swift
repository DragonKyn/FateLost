import SpriteKit

/// Draws the shrines a realm raises, and tells the player what each one wants.
///
/// A shrine is a bargain agreed to by walking onto it, so the terms have to be
/// readable before that happens. The name and the price appear as the player
/// comes near and fade as they leave, which keeps the battlefield clear from
/// a distance and honest up close.
@MainActor
final class ShrineRenderer {
    private struct Entry {
        let root: SKSpriteNode
        let glow: SKSpriteNode
        let terms: SKNode
    }

    /// World units within which the terms are shown.
    private static let readDistance: CGFloat = 5

    private let catalog: SpriteCatalog
    private let projection: IsometricProjection
    private weak var layer: SKNode?
    private var active: [Int: Entry] = [:]
    private var seen = Set<Int>()
    private var departed: [Int] = []

    init(catalog: SpriteCatalog, projection: IsometricProjection, layer: SKNode) {
        self.catalog = catalog
        self.projection = projection
        self.layer = layer
    }

    var activeCount: Int { active.count }

    func update(shrines: [Shrine], playerPosition: CGPoint, frame: WrappedRenderFrame, time: TimeInterval) {
        guard let layer else { return }
        seen.removeAll(keepingCapacity: true)
        let seconds = CGFloat(time)

        for shrine in shrines {
            seen.insert(shrine.id)
            let entry: Entry
            if let existing = active[shrine.id] {
                entry = existing
            } else {
                entry = makeEntry(for: shrine.kind)
                layer.addChild(entry.root)
                active[shrine.id] = entry
            }

            let screen = projection.toScreen(frame.unwrapped(shrine.position))
            entry.root.position = screen
            entry.root.zPosition = DepthSorting.z(forScreenY: screen.y)

            let phase = CGFloat(shrine.id % 7)
            entry.glow.alpha = 0.5 + 0.2 * sin(seconds * 2 + phase)
            entry.glow.setScale(Self.glowScale * (1 + 0.1 * sin(seconds * 2 + phase)))

            // Terms fade in as the player closes.
            let distance = frame.world.distance(shrine.position, playerPosition)
            let near = max(0, min(1, (Self.readDistance - distance) / 1.5))
            entry.terms.alpha = near
        }

        departed.removeAll(keepingCapacity: true)
        for id in active.keys where !seen.contains(id) {
            departed.append(id)
        }
        for id in departed {
            active.removeValue(forKey: id)?.root.removeFromParent()
        }
    }

    // MARK: Building

    private static let glowScale: CGFloat = 1.5

    private func makeEntry(for kind: ShrineKind) -> Entry {
        let root = catalog.makeSprite(Self.spriteID(for: kind))
        let tint = Self.tint(for: kind)

        let glow = catalog.makeSprite(.fxGlow)
        glow.blendMode = .add
        glow.color = tint
        glow.colorBlendFactor = 1
        glow.anchorPoint = CGPoint(x: 0.5, y: 0.3)
        glow.position = CGPoint(x: 0, y: 14)
        glow.zPosition = -0.0005
        root.addChild(glow)

        let terms = SKNode()
        terms.position = CGPoint(x: 0, y: root.size.height * 0.95 + 16)
        terms.zPosition = 1
        terms.alpha = 0

        let name = SKLabelNode(text: kind.name)
        name.fontSize = 14
        name.fontColor = tint
        name.verticalAlignmentMode = .bottom
        name.position = CGPoint(x: 0, y: 12)
        let price = SKLabelNode(text: kind.bargain)
        price.fontSize = 11
        price.fontColor = UIColor(rgb: 0xF3E9D8)
        price.verticalAlignmentMode = .bottom
        price.position = CGPoint(x: 0, y: 0)
        terms.addChild(name)
        terms.addChild(price)
        root.addChild(terms)

        return Entry(root: root, glow: glow, terms: terms)
    }

    private static func spriteID(for kind: ShrineKind) -> SpriteID {
        switch kind {
        case .blood: return .shrineBlood
        case .fortune: return .shrineFortune
        case .ruin: return .shrineRuin
        }
    }

    static func tint(for kind: ShrineKind) -> UIColor {
        switch kind {
        case .blood: return UIColor(rgb: 0xE0505A)
        case .fortune: return UIColor(rgb: 0xF0D58A)
        case .ruin: return UIColor(rgb: 0xB07CFF)
        }
    }
}
