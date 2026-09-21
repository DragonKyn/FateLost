import SpriteKit

/// Paints the ground a champion has marked (see `Hazard`).
///
/// The mark is the whole warning, so it has to be honest: it is exactly the
/// ground that will hurt, it fills as the time runs out, and it flashes white
/// as it lands. A player who has read it and stepped out has nothing to fear.
@MainActor
final class HazardRenderer {
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

    func update(hazards: [Hazard], frame: WrappedRenderFrame, time: TimeInterval) {
        frameNumber &+= 1
        guard let layer else { return }
        let seconds = CGFloat(time)

        for hazard in hazards {
            let node: SKShapeNode
            if let existing = views[hazard.id] {
                node = existing
            } else {
                node = spare.popLast() ?? Self.makeNode()
                layer.addChild(node)
                views[hazard.id] = node
            }
            seen[hazard.id] = frameNumber

            node.path = path(for: hazard, frame: frame)
            let progress = CGFloat(hazard.progress)
            let sinceLanding = hazard.age - hazard.warning
            if hazard.isGuide {
                // Only shows where something is about to sweep: faint, and steady.
                let fade = hazard.age < hazard.warning ? 1 : max(0, 1 - CGFloat(sinceLanding / Hazard.afterglow))
                node.fillColor = UIColor(red: 0.86, green: 0.1, blue: 0.08, alpha: 0.09 * fade)
                node.strokeColor = UIColor(red: 1, green: 0.45, blue: 0.25, alpha: 0.35 * fade)
                node.lineWidth = 1.5
            } else if hazard.age < hazard.warning {
                let flicker = 0.88 + 0.12 * sin(seconds * 20)
                node.fillColor = UIColor(red: 0.86, green: 0.1, blue: 0.08, alpha: (0.1 + 0.34 * progress) * flicker)
                node.strokeColor = UIColor(red: 1, green: 0.45, blue: 0.25, alpha: 0.5 + 0.4 * progress)
                node.lineWidth = 2
            } else if sinceLanding < Hazard.afterglow {
                // Landed: a white flash that drains away.
                let fade = max(0, 1 - CGFloat(sinceLanding / Hazard.afterglow))
                node.fillColor = UIColor(red: 1, green: 0.85, blue: 0.62, alpha: 0.7 * fade)
                node.strokeColor = UIColor(white: 1, alpha: 0.9 * fade)
                node.lineWidth = 3
            } else if hazard.isActive {
                let tint = Self.tint(for: hazard.visual)
                if hazard.shape == .lane {
                    // A beam: a hot core with the colour of what it is.
                    node.fillColor = tint.withAlphaComponent(0.55 + 0.15 * sin(seconds * 30))
                    node.strokeColor = UIColor(white: 1, alpha: 0.9)
                    node.lineWidth = 3
                } else {
                    // A pool: the colour of what burns in it, breathing.
                    node.fillColor = tint.withAlphaComponent(0.26 + 0.1 * sin(seconds * 4 + CGFloat(hazard.id)))
                    node.strokeColor = tint.withAlphaComponent(0.8)
                    node.lineWidth = 2
                }
            } else {
                node.fillColor = .clear
                node.strokeColor = .clear
            }
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

    /// The marked ground as a polygon on the isometric floor.
    private func path(for hazard: Hazard, frame: WrappedRenderFrame) -> CGPath {
        let origin = frame.unwrapped(hazard.position)
        let axis = hazard.direction.lengthSquared > 0.0001 ? hazard.direction.normalized : CGPoint(x: 1, y: 0)
        var corners: [CGPoint] = []
        switch hazard.shape {
        case .circle:
            let steps = 28
            for step in 0..<steps {
                let angle = 2 * CGFloat.pi * CGFloat(step) / CGFloat(steps)
                corners.append(origin + CGPoint(x: cos(angle), y: sin(angle)) * hazard.size)
            }
        case .cone:
            let centre = atan2(axis.y, axis.x)
            corners.append(origin)
            let steps = 12
            for step in 0...steps {
                let angle = centre - hazard.width + 2 * hazard.width * CGFloat(step) / CGFloat(steps)
                corners.append(origin + CGPoint(x: cos(angle), y: sin(angle)) * hazard.size)
            }
        case .lane:
            let side = CGPoint(x: -axis.y, y: axis.x)
            corners = [
                origin + side * hazard.width,
                origin + axis * hazard.size + side * hazard.width,
                origin + axis * hazard.size - side * hazard.width,
                origin - side * hazard.width,
            ]
        }
        let path = CGMutablePath()
        path.move(to: projection.toScreen(corners[0]))
        for corner in corners.dropFirst() {
            path.addLine(to: projection.toScreen(corner))
        }
        path.closeSubpath()
        return path
    }

    /// What a burning pool or beam looks like for what is burning in it.
    private static func tint(for visual: VisualStyle) -> UIColor {
        switch visual {
        case .fire: return UIColor(red: 1, green: 0.5, blue: 0.12, alpha: 1)
        case .poison, .nature: return UIColor(red: 0.5, green: 0.85, blue: 0.2, alpha: 1)
        case .frost: return UIColor(red: 0.5, green: 0.85, blue: 1, alpha: 1)
        case .shadow, .arcane, .fate: return UIColor(red: 0.7, green: 0.4, blue: 1, alpha: 1)
        case .holy: return UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)
        case .lightning, .sonic: return UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 1)
        case .physical, .blood: return UIColor(red: 0.9, green: 0.3, blue: 0.25, alpha: 1)
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
