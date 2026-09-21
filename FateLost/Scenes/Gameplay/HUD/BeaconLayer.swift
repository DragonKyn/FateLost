import SpriteKit

/// Something worth walking toward, as an offset from the middle of the screen
/// in HUD units.
struct BeaconMark {
    let id: Int
    let offset: CGPoint
    let color: UIColor
    /// A name to show beside the arrow: the fallen teammate it points to.
    var label: String? = nil
    /// Drawn as a cross, so a friend who needs reviving is never mistaken for
    /// a shrine or a chest.
    var isFallenAlly = false
    /// A living friend: steady rather than pulsing, and ringed in white, so a
    /// teammate is never mistaken for a chest.
    var isParty = false
}

/// Chevrons at the edge of the screen pointing at chests and shrines that
/// are out of view.
///
/// A chest is worth crossing a fight for, but only if the player can tell
/// which way it lies. A beacon whose target is on screen hides itself: the
/// glow on the thing itself is the better signal.
@MainActor
final class BeaconLayer: SKNode {
    /// Room kept clear at each edge, so a chevron is never lost behind the
    /// controls or the bar across the top.
    private enum Margin {
        static let side: CGFloat = 34
        static let top: CGFloat = 84
        static let bottom: CGFloat = 58
    }

    private var arrows: [SKShapeNode] = []
    private var labels: [SKLabelNode] = []

    override init() {
        super.init()
        zPosition = -1
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BeaconLayer is created in code")
    }

    func show(_ marks: [BeaconMark], screenSize: CGSize, time: TimeInterval) {
        while arrows.count < marks.count {
            let arrow = Self.makeArrow()
            addChild(arrow)
            arrows.append(arrow)
            let label = SKLabelNode()
            label.fontName = "AvenirNext-DemiBold"
            label.fontSize = 11
            label.verticalAlignmentMode = .center
            label.isHidden = true
            addChild(label)
            labels.append(label)
        }

        let halfWidth = screenSize.width / 2 - Margin.side
        let top = screenSize.height / 2 - Margin.top
        let bottom = -(screenSize.height / 2 - Margin.bottom)
        let pulse = 0.75 + 0.25 * CGFloat(sin(time * 5))

        for (index, arrow) in arrows.enumerated() {
            guard index < marks.count else {
                arrow.isHidden = true
                labels[index].isHidden = true
                continue
            }
            let mark = marks[index]
            let offset = mark.offset
            let onScreen = abs(offset.x) <= halfWidth && offset.y <= top && offset.y >= bottom
            guard !onScreen, offset.lengthSquared > 1 else {
                arrow.isHidden = true
                labels[index].isHidden = true
                continue
            }

            // Slide along the ray to the first edge it reaches.
            var factor = CGFloat.greatestFiniteMagnitude
            if offset.x != 0 { factor = min(factor, halfWidth / abs(offset.x)) }
            if offset.y > 0 { factor = min(factor, top / offset.y) }
            if offset.y < 0 { factor = min(factor, bottom / offset.y) }

            arrow.isHidden = false
            arrow.position = CGPoint(x: offset.x * factor, y: offset.y * factor)
            arrow.zRotation = atan2(offset.y, offset.x)
            arrow.fillColor = mark.color
            arrow.alpha = mark.isParty ? 0.95 : pulse
            if mark.isParty {
                arrow.strokeColor = UIColor(white: 1, alpha: 0.9)
            } else {
                arrow.strokeColor = mark.isFallenAlly ? UIColor(rgb: 0x2A2036) : UIColor(white: 0, alpha: 0.85)
            }
            arrow.setScale(mark.isFallenAlly ? 1.25 : mark.isParty ? 1.15 : 1)

            let label = labels[index]
            if let text = mark.label {
                label.isHidden = false
                label.text = text
                label.fontColor = mark.color
                label.alpha = mark.isParty ? 0.95 : pulse
                // Beside the arrow, on the side toward the middle of the screen.
                let inward = CGPoint(x: -offset.x, y: -offset.y).normalized
                label.position = CGPoint(x: arrow.position.x + inward.x * 34, y: arrow.position.y + inward.y * 22)
            } else {
                label.isHidden = true
            }
        }
    }

    private static func makeArrow() -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 13, y: 0))
        path.addLine(to: CGPoint(x: -8, y: 9))
        path.addLine(to: CGPoint(x: -3, y: 0))
        path.addLine(to: CGPoint(x: -8, y: -9))
        path.closeSubpath()
        let arrow = SKShapeNode(path: path)
        arrow.strokeColor = UIColor(white: 0, alpha: 0.85)
        arrow.lineWidth = 1.5
        arrow.isHidden = true
        return arrow
    }
}
