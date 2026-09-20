import SpriteKit

/// Paints the ground a charging enemy is about to cross.
///
/// A charger commits to a line when its windup begins, so the lane drawn here
/// is the truth: the enemy will run exactly that far, along exactly that
/// line, and whatever is standing in it is hit. The lane fills as the windup
/// runs out, which is how the player reads how long is left. Only elites and
/// bosses get one; a pack of hounds telegraphs with its own wind-up, and a
/// lane under every one of them would bury the fight.
@MainActor
final class ChargeLaneRenderer {
    private let projection: IsometricProjection
    private weak var layer: SKNode?
    private var views: [Int: SKShapeNode] = [:]
    private var spare: [SKShapeNode] = []
    private var departed: [Int] = []
    private var frameNumber = 0
    private var seen: [Int: Int] = [:]

    init(projection: IsometricProjection, layer: SKNode) {
        self.projection = projection
        self.layer = layer
    }

    var activeCount: Int { views.count }

    func update(enemies: EnemyStore, playerRadius: CGFloat, frame: WrappedRenderFrame, time: TimeInterval) {
        frameNumber &+= 1
        guard let layer else { return }
        let seconds = CGFloat(time)

        for index in 0..<enemies.count where enemies.windup[index] > 0 {
            let definition = enemies.definition(at: index)
            guard case .charger(_, _, let travel) = definition.behavior,
                  definition.rank == .elite || definition.rank == .boss else { continue }
            let aim = enemies.aim[index]
            guard aim != .zero else { continue }

            let id = enemies.ids[index]
            let node: SKShapeNode
            if let existing = views[id] {
                node = existing
            } else {
                node = spare.popLast() ?? Self.makeNode()
                layer.addChild(node)
                views[id] = node
            }
            seen[id] = frameNumber

            let origin = frame.unwrapped(enemies.positions[index])
            let half = definition.radius + definition.attackReach + playerRadius
            let length = travel + definition.radius
            let side = CGPoint(x: -aim.y, y: aim.x)

            let path = CGMutablePath()
            let corners = [
                origin + side * half,
                origin + aim * length + side * half,
                origin + aim * length - side * half,
                origin - side * half,
            ]
            path.move(to: projection.toScreen(corners[0]))
            for corner in corners.dropFirst() {
                path.addLine(to: projection.toScreen(corner))
            }
            path.closeSubpath()
            node.path = path

            let total = max(definition.attackWindup, 0.01)
            let filled = 1 - CGFloat(enemies.windup[index] / total)
            let flicker = 0.85 + 0.15 * sin(seconds * 24)
            node.fillColor = UIColor(red: 0.85, green: 0.12, blue: 0.08, alpha: (0.14 + 0.36 * filled) * flicker)
            node.strokeColor = UIColor(red: 1, green: 0.42, blue: 0.25, alpha: 0.55 + 0.35 * filled)
        }

        departed.removeAll(keepingCapacity: true)
        for (id, lastFrame) in seen where lastFrame != frameNumber {
            departed.append(id)
        }
        for id in departed {
            seen.removeValue(forKey: id)
            if let node = views.removeValue(forKey: id) {
                node.removeFromParent()
                spare.append(node)
            }
        }
    }

    private static func makeNode() -> SKShapeNode {
        let node = SKShapeNode()
        node.lineWidth = 2
        node.isAntialiased = true
        node.zPosition = 1
        return node
    }
}
