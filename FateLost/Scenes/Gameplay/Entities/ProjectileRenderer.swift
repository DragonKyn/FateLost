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
    /// Body radius a sprite is drawn for; bigger projectiles scale up.
    private let referenceRadius: CGFloat = 0.2

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
                style(sprite, for: projectile)
            }
            let screen = projection.toScreen(frame.unwrapped(projectile.position))
            sprite.position = screen + CGPoint(x: 0, y: flightHeight)
            sprite.zPosition = DepthSorting.z(forScreenY: screen.y)
            let heading = projection.toScreen(projectile.velocity)
            if projectile.spriteID == .projectileBoomerang {
                // A thrown boomerang spins as it flies, whichever way it is going.
                let turns = CACurrentMediaTime() * 16 + Double(projectile.id % 7)
                sprite.zRotation = CGFloat(turns.truncatingRemainder(dividingBy: 2 * .pi))
            } else {
                sprite.zRotation = atan2(heading.y, heading.x)
            }
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

    /// Tints energy projectiles by their style and sizes big ones up.
    private func style(_ sprite: SKSpriteNode, for projectile: Projectile) {
        let isEnergy = projectile.spriteID == .projectileBolt
        if isEnergy {
            sprite.color = projectile.visual.color
            sprite.colorBlendFactor = 1
        } else {
            sprite.colorBlendFactor = 0
        }
        let scale = max(0.8, projectile.radius / referenceRadius)
        sprite.setScale(projectile.spriteID == .projectileBoomerang ? scale * 1.5 : scale)
    }

    private func pool(for id: SpriteID) -> NodePool<SKSpriteNode> {
        if let pool = pools[id] {
            return pool
        }
        let catalog = catalog
        let pool = NodePool<SKSpriteNode>(prewarm: 8, make: {
            let sprite = catalog.makeSprite(id)
            if id == .projectileArcaneBolt || id == .projectileBolt || id == .projectileShard {
                sprite.blendMode = .add
            }
            return sprite
        })
        pools[id] = pool
        return pool
    }
}
