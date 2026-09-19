import SpriteKit

/// What an ability slot currently shows.
enum AbilitySlotDisplay: Equatable {
    /// Nothing equipped. Most early builds leave slots empty.
    case empty
    /// Ready to use.
    case ready(symbol: String)
    /// Recharging; `progress` runs 0 (just used) to 1 (ready).
    case coolingDown(symbol: String, progress: CGFloat, secondsRemaining: Double)
}

/// A round ability socket with a radial cooldown sweep.
@MainActor
final class AbilityButtonNode: SKNode {
    private let socket = SKShapeNode()
    private let sweep = SKShapeNode()
    private let symbol = SKLabelNode()
    private let countdown = SKLabelNode()
    private var radius: CGFloat = 30
    private let isUltimate: Bool
    private var display: AbilitySlotDisplay?

    private enum Style {
        static let socketFill = SKColor(red: 0.06, green: 0.05, blue: 0.06, alpha: 0.7)
        static let rim = SKColor(red: 0.55, green: 0.47, blue: 0.36, alpha: 0.9)
        static let ultimateRim = SKColor(red: 0.85, green: 0.51, blue: 0.17, alpha: 0.95)
        static let sweepFill = SKColor(white: 0, alpha: 0.6)
        static let emptyAlpha: CGFloat = 0.35
    }

    init(isUltimate: Bool) {
        self.isUltimate = isUltimate
        super.init()
        addChild(socket)
        sweep.zPosition = 1
        sweep.strokeColor = .clear
        sweep.fillColor = Style.sweepFill
        addChild(sweep)

        for label in [symbol, countdown] {
            label.fontName = "AvenirNext-Bold"
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 2
            addChild(label)
        }
        countdown.fontColor = SKColor(white: 1, alpha: 0.95)
        render(.empty)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("AbilityButtonNode is created in code")
    }

    func configure(diameter: CGFloat) {
        radius = diameter / 2
        socket.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: diameter, height: diameter),
                             transform: nil)
        socket.fillColor = Style.socketFill
        socket.strokeColor = isUltimate ? Style.ultimateRim : Style.rim
        socket.lineWidth = isUltimate ? 3 : 2
        symbol.fontSize = diameter * 0.36
        countdown.fontSize = diameter * 0.32
        if let display {
            self.display = nil
            render(display)
        }
    }

    func render(_ newDisplay: AbilitySlotDisplay) {
        guard newDisplay != display else { return }
        display = newDisplay
        switch newDisplay {
        case .empty:
            alpha = Style.emptyAlpha
            symbol.text = nil
            countdown.text = nil
            sweep.path = nil
        case .ready(let glyph):
            alpha = 1
            symbol.text = glyph
            countdown.text = nil
            sweep.path = nil
        case .coolingDown(let glyph, let progress, let seconds):
            alpha = 1
            symbol.text = glyph
            countdown.text = seconds >= 1 ? "\(Int(seconds.rounded(.up)))" : String(format: "%.1f", seconds)
            sweep.path = Self.sweepPath(radius: radius, remaining: 1 - progress.clamped(0, 1))
        }
    }

    /// Pie wedge covering the remaining fraction, starting at 12 o'clock and
    /// shrinking clockwise.
    private static func sweepPath(radius: CGFloat, remaining: CGFloat) -> CGPath? {
        guard remaining > 0 else { return nil }
        let path = CGMutablePath()
        let start = CGFloat.pi / 2
        path.move(to: .zero)
        path.addArc(center: .zero, radius: radius, startAngle: start,
                    endAngle: start + remaining * 2 * .pi, clockwise: false)
        path.closeSubpath()
        return path
    }
}
