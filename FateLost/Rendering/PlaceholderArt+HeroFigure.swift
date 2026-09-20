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

/// Puts the hero together on one canvas, back to front: wings, legs, cloak,
/// metalwork, chest emblem, head.
extension PlaceholderArt {
    /// Every build shares this canvas, so a sprite is swapped for another
    /// without the figure jumping. It is wide enough for the widest wings and
    /// tall enough for the tallest build in a wizard's hat. Feet are at y = 76.
    static let heroCanvas = CGSize(width: 64, height: 80)
    static let heroFootY: CGFloat = 76

    private static func paintHero(_ look: HeroAppearance, in ctx: CGContext) {
        let ink = HeroInk(look)
        drawHeroWings(look.wings, look.build, ctx, ink)
        drawHeroLegs(look.build, ctx, ink)
        drawHeroCloak(look.cloak, look.build, ctx, ink)
        drawHeroDetail(look.detail, look.build, ctx, ink)
        drawHeroEmblem(look.emblem, look.build, ctx, ink)
        drawHeroHead(look.head, look.build, ctx, ink)
    }

    /// The figure in three pieces on the same canvas, back to front, so the
    /// cloak can move on its own while the wings, legs, armour and head stay
    /// rigid. Laid one over another they are exactly `hero(_:)`.
    static func heroPieces(_ look: HeroAppearance) -> (behind: Sprite, cloak: Sprite, front: Sprite) {
        let anchor = CGPoint(x: 0.5, y: (heroCanvas.height - heroFootY) / heroCanvas.height)
        let ink = HeroInk(look)
        let behind = render(heroCanvas) { ctx in
            drawHeroWings(look.wings, look.build, ctx, ink)
            drawHeroLegs(look.build, ctx, ink)
        }
        let cloak = render(heroCanvas) { ctx in
            drawHeroCloak(look.cloak, look.build, ctx, ink)
        }
        let front = render(heroCanvas) { ctx in
            drawHeroDetail(look.detail, look.build, ctx, ink)
            drawHeroEmblem(look.emblem, look.build, ctx, ink)
            drawHeroHead(look.head, look.build, ctx, ink)
        }
        return (Sprite(image: behind, anchor: anchor), Sprite(image: cloak, anchor: anchor),
                Sprite(image: front, anchor: anchor))
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
