import Foundation

/// Framework-neutral colour for configuration data.
///
/// Content definitions (realm palettes, rarity colours) use this rather than
/// `UIColor`/`SKColor` so they are `Codable`, testable, and ready to move into
/// JSON. Conversions to platform colours live in the presentation layer.
struct RGBA: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// `0xRRGGBB`
    init(hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }

    func withAlpha(_ alpha: Double) -> RGBA {
        RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Linear blend toward `other`; `t` of 0 is self, 1 is other.
    func mixed(with other: RGBA, t: Double) -> RGBA {
        RGBA(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t,
            alpha: alpha + (other.alpha - alpha) * t
        )
    }

    func scaled(brightness factor: Double) -> RGBA {
        RGBA(
            red: (red * factor).clamped(0, 1),
            green: (green * factor).clamped(0, 1),
            blue: (blue * factor).clamped(0, 1),
            alpha: alpha
        )
    }
}
