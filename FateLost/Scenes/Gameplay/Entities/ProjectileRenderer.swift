import SpriteKit

/// Draws projectiles in flight, pooled per sprite.
@MainActor
final class ProjectileRenderer {
    private let catalog: SpriteCatalog
    private let projection: IsometricProjection
    private weak var layer: SKNode?
    private var pools: [SpriteID: NodePool<SKSpriteNode>] = [:]
    private var active: [Int: (sprite: SKSpriteNode, spriteID: SpriteID)] = [:]
    private var seen = Set<Int>()
    private var departed: [Int] = []

    /// Height above the ground projectiles fly at, in scene points.
    private let flightHeight: CGFloat = 18

    init(catalog: SpriteCatalog, projection: IsometricProjection, layer: SKNode) {
        self.catalog = catalog
        self.projection = projection
        self.layer = layer
    }

    var activeCount: Int { active.count }

    func update(projectiles: [Projectile], frame: WrappedRenderFrame) {
        guard let layer else { return }
        seen.removeAll(keepingCapacity: true)

        for projectile in projectiles {
            seen.insert(projectile.id)
            let sprite: SKSpriteNode
            if let existing = active[projectile.id] {
                sprite = existing.sprite
            } else {
                sprite = pool(for: projectile.spriteID).acquire()
                layer.addChild(sprite)
                active[projectile.id] = (sprite, projectile.spriteID)
            }
            let screen = projection.toScreen(frame.unwrapped(projectile.position))
            sprite.position = screen + CGPoint(x: 0, y: flightHeight)
            sprite.zPosition = DepthSorting.z(forScreenY: screen.y)
            let heading = projection.toScreen(projectile.velocity)
            sprite.zRotation = atan2(heading.y, heading.x)
        }

        departed.removeAll(keepingCapacity: true)
        for id in active.keys where !seen.contains(id) {
            departed.append(id)
        }
        for id in departed {
            if let entry = active.removeValue(forKey: id) {
                pool(for: entry.spriteID).release(entry.sprite)
            }
        }
    }

    private func pool(for id: SpriteID) -> NodePool<SKSpriteNode> {
        if let pool = pools[id] {
            return pool
        }
        let catalog = catalog
        let pool = NodePool<SKSpriteNode>(prewarm: 8, make: {
            let sprite = catalog.makeSprite(id)
            if id == .projectileArcaneBolt {
                sprite.blendMode = .add
            }
            return sprite
        })
        pools[id] = pool
        return pool
    }
}
