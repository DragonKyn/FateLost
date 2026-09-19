import SpriteKit

/// Draws experience embers lying in the world, bobbing and glowing, larger
/// for larger values.
@MainActor
final class PickupRenderer {
    private let projection: IsometricProjection
    private weak var layer: SKNode?
    private let pool: NodePool<SKSpriteNode>
    private var active: [Int: SKSpriteNode] = [:]
    private var seen = Set<Int>()
    private var departed: [Int] = []

    init(catalog: SpriteCatalog, projection: IsometricProjection, layer: SKNode) {
        self.projection = projection
        self.layer = layer
        pool = NodePool(prewarm: 60, make: {
            let sprite = catalog.makeSprite(.fxEmber)
            sprite.blendMode = .add
            return sprite
        })
    }

    var activeCount: Int { active.count }

    func update(orbs: [ExperienceOrb], frame: WrappedRenderFrame, time: TimeInterval) {
        guard let layer else { return }
        seen.removeAll(keepingCapacity: true)
        let seconds = CGFloat(time)

        for orb in orbs {
            seen.insert(orb.id)
            let sprite: SKSpriteNode
            if let existing = active[orb.id] {
                sprite = existing
            } else {
                sprite = pool.acquire()
                layer.addChild(sprite)
                active[orb.id] = sprite
            }
            let screen = projection.toScreen(frame.unwrapped(orb.position))
            let phase = CGFloat(orb.id % 13)
            let bob = orb.attracted ? 10 : 7 + sin(seconds * 3 + phase) * 2.5
            sprite.position = screen + CGPoint(x: 0, y: bob)
            sprite.zPosition = DepthSorting.z(forScreenY: screen.y)
            sprite.setScale(Self.scale(for: orb.value) * (1 + 0.08 * sin(seconds * 6 + phase)))
        }

        departed.removeAll(keepingCapacity: true)
        for id in active.keys where !seen.contains(id) {
            departed.append(id)
        }
        for id in departed {
            if let sprite = active.removeValue(forKey: id) {
                pool.release(sprite)
            }
        }
    }

    private static func scale(for value: Int) -> CGFloat {
        switch value {
        case ..<2: return 0.75
        case ..<5: return 0.95
        case ..<10: return 1.2
        default: return min(2, 1.2 + CGFloat(value) / 60)
        }
    }
}
