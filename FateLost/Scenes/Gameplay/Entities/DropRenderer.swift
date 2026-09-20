import SpriteKit

/// Draws what lies in the world besides experience: vials, magnets and
/// chests.
///
/// Chests get a pulsing glow the colour of what they hold, because a chest is
/// something the player has to decide to walk toward across a crowded floor,
/// and it should be readable from there.
@MainActor
final class DropRenderer {
    private struct Entry {
        let root: SKSpriteNode
        let glow: SKSpriteNode?
    }

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

    func update(drops: [Drop], frame: WrappedRenderFrame, time: TimeInterval) {
        guard let layer else { return }
        seen.removeAll(keepingCapacity: true)
        let seconds = CGFloat(time)

        for drop in drops {
            seen.insert(drop.id)
            let entry: Entry
            if let existing = active[drop.id] {
                entry = existing
            } else {
                entry = makeEntry(for: drop.kind)
                layer.addChild(entry.root)
                active[drop.id] = entry
            }

            let screen = projection.toScreen(frame.unwrapped(drop.position))
            let phase = CGFloat(drop.id % 11)
            let lift: CGFloat
            switch drop.kind {
            case .chest:
                lift = 0
            case .vial, .magnet:
                lift = drop.attracted ? 10 : 4 + sin(seconds * 3 + phase) * 2
            }
            entry.root.position = screen + CGPoint(x: 0, y: lift)
            entry.root.zPosition = DepthSorting.z(forScreenY: screen.y)

            if let glow = entry.glow, case .chest(let tier) = drop.kind {
                let base = Self.glowScale(for: tier)
                glow.setScale(base * (1 + 0.12 * sin(seconds * 2.4 + phase)))
                glow.alpha = 0.55 + 0.2 * sin(seconds * 2.4 + phase)
            }
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

    private func makeEntry(for kind: DropKind) -> Entry {
        let root = catalog.makeSprite(Self.spriteID(for: kind))
        guard case .chest(let tier) = kind else {
            return Entry(root: root, glow: nil)
        }
        let glow = catalog.makeSprite(.fxGlow)
        glow.blendMode = .add
        glow.color = Self.glowColor(for: tier).uiColor
        glow.colorBlendFactor = 1
        glow.anchorPoint = CGPoint(x: 0.5, y: 0.35)
        glow.position = CGPoint(x: 0, y: 8)
        glow.zPosition = -0.0005
        root.addChild(glow)
        return Entry(root: root, glow: glow)
    }

    private static func spriteID(for kind: DropKind) -> SpriteID {
        switch kind {
        case .vial: return .dropVial
        case .magnet: return .dropMagnet
        case .chest(let tier):
            switch tier {
            case .cache: return .dropChestCache
            case .chest: return .dropChestChest
            case .hoard: return .dropChestHoard
            }
        }
    }

    private static func glowColor(for tier: LootTier) -> RGBA {
        switch tier {
        case .cache: return ItemRarity.common.color
        case .chest: return ItemRarity.rare.color
        case .hoard: return ItemRarity.legendary.color
        }
    }

    private static func glowScale(for tier: LootTier) -> CGFloat {
        switch tier {
        case .cache: return 0.9
        case .chest: return 1.3
        case .hoard: return 1.8
        }
    }
}
