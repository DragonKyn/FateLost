import SpriteKit

/// Draws a `JoystickModel`. Owns no input logic of its own.
@MainActor
final class VirtualJoystickNode: SKNode {
    private let baseRing = SKShapeNode()
    private let knob = SKShapeNode()

    private enum Style {
        static let idleAlpha: CGFloat = 0.28
        static let activeAlpha: CGFloat = 0.9
        static let knobRadiusFraction: CGFloat = 0.42
        static let ringColor = SKColor(red: 0.91, green: 0.86, blue: 0.78, alpha: 0.55)
        static let fillColor = SKColor(red: 0.05, green: 0.04, blue: 0.05, alpha: 0.45)
        static let knobColor = SKColor(red: 0.85, green: 0.51, blue: 0.17, alpha: 0.85)
    }

    override init() {
        super.init()
        addChild(baseRing)
        addChild(knob)
        alpha = Style.idleAlpha
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("VirtualJoystickNode is created in code")
    }

    func configure(radius: CGFloat) {
        baseRing.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
                               transform: nil)
        baseRing.strokeColor = Style.ringColor
        baseRing.fillColor = Style.fillColor
        baseRing.lineWidth = 2

        let knobRadius = radius * Style.knobRadiusFraction
        knob.path = CGPath(ellipseIn: CGRect(x: -knobRadius, y: -knobRadius,
                                             width: knobRadius * 2, height: knobRadius * 2), transform: nil)
        knob.fillColor = Style.knobColor
        knob.strokeColor = SKColor(white: 0, alpha: 0.5)
        knob.lineWidth = 1.5
    }

    func show(_ model: JoystickModel, restPosition: CGPoint) {
        if model.isActive {
            position = model.base
            knob.position = model.knobOffset
            alpha = Style.activeAlpha
        } else {
            position = restPosition
            knob.position = .zero
            alpha = Style.idleAlpha
        }
    }
}
