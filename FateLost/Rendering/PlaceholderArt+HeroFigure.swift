import UIKit

/// The colours a hero is dressed in, as the generated layers ask for them.
///
/// A layer never names a colour; it asks the ink for "the cloak" or "the
/// trim, a little darker". That is what lets one drawing serve every
/// combination the player can pick.
struct HeroInk {
    private let cloakHex: UInt32
    private let trimHex: UInt32
    private let eyesHex: UInt32
    private let skinHex: UInt32
    private let hairHex: UInt32

    init(_ look: HeroAppearance) {
        cloakHex = look.cloakSwatch.hex
        trimHex = look.trimSwatch.hex
        eyesHex = look.eyeSwatch.hex
        skinHex = look.skinSwatch.hex
        hairHex = look.hairSwatch.hex
    }

    func cloak(_ shade: CGFloat = 1) -> UIColor { Self.tone(cloakHex, shade) }
    func trim(_ shade: CGFloat = 1) -> UIColor { Self.tone(trimHex, shade) }
    func eyes(_ shade: CGFloat = 1) -> UIColor { Self.tone(eyesHex, shade) }
    func skin(_ shade: CGFloat = 1) -> UIColor { Self.tone(skinHex, shade) }
    func hair(_ shade: CGFloat = 1) -> UIColor { Self.tone(hairHex, shade) }

    /// A colour scaled toward black (below 1) or white (above), channel by
    /// channel and clamped. The same arithmetic the art tool previews with.
    static func tone(_ hex: UInt32, _ shade: CGFloat) -> UIColor {
        func channel(_ shift: UInt32) -> CGFloat {
            min(1, max(0, CGFloat((hex >> shift) & 0xFF) / 255 * shade))
        }
        return UIColor(red: channel(16), green: channel(8), blue: channel(0), alpha: 1)
    }
}

/// Puts the hero together: legs, then cloak, then head, on one canvas.
extension PlaceholderArt {
    /// Every build shares this canvas, so a sprite is swapped for another
    /// without the figure jumping. Feet are at y = 60.
    static let heroCanvas = CGSize(width: 48, height: 64)
    static let heroFootY: CGFloat = 60

    private static func paintHero(_ look: HeroAppearance, in ctx: CGContext) {
        let ink = HeroInk(look)
        drawHeroLegs(look.build, ctx, ink)
        drawHeroCloak(look.cloak, look.build, ctx, ink)
        drawHeroHead(look.head, look.build, ctx, ink)
    }

    /// The in-game figure, at device resolution.
    static func hero(_ look: HeroAppearance) -> Sprite {
        let image = render(heroCanvas) { paintHero(look, in: $0) }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (heroCanvas.height - heroFootY) / heroCanvas.height))
    }

    /// The same figure drawn large, for the customisation screen. It is
    /// redrawn at the requested scale rather than enlarged, so it stays sharp.
    static func heroPortrait(_ look: HeroAppearance, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: heroCanvas, format: format).image { context in
            paintHero(look, in: context.cgContext)
        }
    }
}
