import SpriteKit
import UIKit

/// What an ability slot currently shows.
enum AbilitySlotDisplay: Equatable {
    /// Nothing equipped. Most early builds leave slots empty.
    case empty
    /// Ready to use. `symbol` is an SF Symbol name.
    case ready(symbol: String)
    /// Recharging; `progress` runs 0 (just used) to 1 (ready).
    case coolingDown(symbol: String, progress: CGFloat, secondsRemaining: Double)
}

/// A round ability socket with the ability's icon and a radial cooldown sweep.
@MainActor
final class AbilityButtonNode: SKNode {
    private let socket = SKShapeNode()
    private let readyGlow = SKShapeNode()
    private let sweep = SKShapeNode()
    private let icon = SKSpriteNode()
    private let countdown = SKLabelNode()
    private var radius: CGFloat = 30
    private let isUltimate: Bool
    private var display: AbilitySlotDisplay?
    private var iconSymbol: String?

    private enum Style {
        static let socketFill = SKColor(red: 0.06, green: 0.05, blue: 0.06, alpha: 0.7)
        static let rim = SKColor(red: 0.55, green: 0.47, blue: 0.36, alpha: 0.9)
        static let ultimateRim = SKColor(red: 0.85, green: 0.51, blue: 0.17, alpha: 0.95)
        static let readyRim = SKColor(red: 1, green: 0.78, blue: 0.4, alpha: 0.9)
        static let sweepFill = SKColor(white: 0, alpha: 0.62)
        static let emptyAlpha: CGFloat = 0.35
    }

    private static var symbolTextures: [String: SKTexture] = [:]

    init(isUltimate: Bool) {
        self.isUltimate = isUltimate
        super.init()
        addChild(socket)
        readyGlow.strokeColor = Style.readyRim
        readyGlow.fillColor = .clear
        readyGlow.zPosition = 0.5
        addChild(readyGlow)
        icon.zPosition = 1
        addChild(icon)
        sweep.zPosition = 2
        sweep.strokeColor = .clear
        sweep.fillColor = Style.sweepFill
        addChild(sweep)

        countdown.fontName = "AvenirNext-Bold"
        countdown.verticalAlignmentMode = .center
        countdown.horizontalAlignmentMode = .center
        countdown.zPosition = 3
        countdown.fontColor = SKColor(white: 1, alpha: 0.95)
        addChild(countdown)
        render(.empty)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("AbilityButtonNode is created in code")
    }

    func configure(diameter: CGFloat) {
        radius = diameter / 2
        let circle = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: diameter, height: diameter),
                            transform: nil)
        socket.path = circle
        socket.fillColor = Style.socketFill
        socket.strokeColor = isUltimate ? Style.ultimateRim : Style.rim
        socket.lineWidth = isUltimate ? 3 : 2
        let inset = radius + 3
        readyGlow.path = CGPath(ellipseIn: CGRect(x: -inset, y: -inset, width: inset * 2, height: inset * 2),
                                transform: nil)
        readyGlow.lineWidth = 2
        countdown.fontSize = diameter * 0.32
        iconSymbol = nil
        if let display {
            self.display = nil
            render(display)
        }
    }

    func render(_ newDisplay: AbilitySlotDisplay) {
        guard newDisplay != display else { return }
        let wasCooling: Bool
        if case .coolingDown = display { wasCooling = true } else { wasCooling = false }
        display = newDisplay
        switch newDisplay {
        case .empty:
            alpha = Style.emptyAlpha
            setIcon(nil)
            countdown.text = nil
            sweep.path = nil
            readyGlow.isHidden = true
        case .ready(let symbol):
            alpha = 1
            setIcon(symbol)
            icon.alpha = 1
            countdown.text = nil
            sweep.path = nil
            readyGlow.isHidden = false
            if wasCooling {
                // A little flourish when an ability comes back.
                run(.sequence([.scale(to: 1.12, duration: 0.08), .scale(to: 1, duration: 0.14)]))
            }
        case .coolingDown(let symbol, let progress, let seconds):
            alpha = 1
            setIcon(symbol)
            icon.alpha = 0.55
            countdown.text = seconds >= 1 ? "\(Int(seconds.rounded(.up)))" : String(format: "%.1f", seconds)
            sweep.path = Self.sweepPath(radius: radius, remaining: 1 - progress.clamped(0, 1))
            readyGlow.isHidden = true
        }
    }

    /// A quick press animation.
    func pulse() {
        removeAction(forKey: "pulse")
        run(.sequence([.scale(to: 0.88, duration: 0.05), .scale(to: 1, duration: 0.12)]), withKey: "pulse")
    }

    private func setIcon(_ symbol: String?) {
        guard symbol != iconSymbol else { return }
        iconSymbol = symbol
        guard let symbol, let texture = Self.texture(for: symbol, pointSize: radius * 0.9) else {
            icon.texture = nil
            icon.isHidden = true
            return
        }
        icon.isHidden = false
        icon.texture = texture
        icon.size = texture.size()
    }

    /// An SF Symbol baked into a white texture, cached per symbol and size.
    private static func texture(for symbol: String, pointSize: CGFloat) -> SKTexture? {
        let key = "\(symbol)@\(Int(pointSize))"
        if let cached = symbolTextures[key] {
            return cached
        }
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let symbolImage = UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) else { return nil }
        let baked = UIGraphicsImageRenderer(size: symbolImage.size).image { _ in
            symbolImage.draw(at: .zero)
        }
        let texture = SKTexture(image: baked)
        symbolTextures[key] = texture
        return texture
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
