import SpriteKit

/// Recycles nodes instead of allocating and discarding them.
///
/// Creating SpriteKit nodes mid-combat causes allocation spikes; a run with
/// hundreds of enemies, projectiles and pickups must reuse them. Decorations
/// use this today, and enemies/projectiles will use one pool per visual type.
@MainActor
final class NodePool<Node: SKNode> {
    private var available: [Node] = []
    private let make: () -> Node
    private let prepareForReuse: (Node) -> Void

    private(set) var createdCount = 0

    init(prewarm: Int = 0, make: @escaping () -> Node, prepareForReuse: @escaping (Node) -> Void = { _ in }) {
        self.make = make
        self.prepareForReuse = prepareForReuse
        available.reserveCapacity(prewarm)
        for _ in 0..<prewarm {
            available.append(make())
            createdCount += 1
        }
    }

    var availableCount: Int { available.count }

    func acquire() -> Node {
        if let node = available.popLast() {
            return node
        }
        createdCount += 1
        return make()
    }

    func release(_ node: Node) {
        node.removeFromParent()
        prepareForReuse(node)
        available.append(node)
    }
}
