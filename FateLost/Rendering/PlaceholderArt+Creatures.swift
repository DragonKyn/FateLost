import UIKit

/// Stand-in art for the goblin warband and the player's allies.
///
/// All figures face right (+x) and are anchored at their feet, like the
/// adventurer; renderers flip them to face their heading.
extension PlaceholderArt {
    struct GoblinPalette {
        let skin: UInt32
        let shade: UInt32
        let cloth: UInt32
        let eyes: UInt32

        static let green = GoblinPalette(skin: 0x6B7A3C, shade: 0x4E5A2A, cloth: 0x5A3A22, eyes: 0xF2D23C)
        static let moss = GoblinPalette(skin: 0x55703E, shade: 0x3C5230, cloth: 0x3A3630, eyes: 0xE8E050)
        static let ochre = GoblinPalette(skin: 0x87803A, shade: 0x625C28, cloth: 0x4A2A20, eyes: 0xF28A3C)
        static let pale = GoblinPalette(skin: 0x8C9A78, shade: 0x6A765A, cloth: 0x2E2A36, eyes: 0xD8F0FF)
    }

    enum Headgear {
        case none
        case hood(UInt32)
        case helmet(UInt32)
    }

    private static let inkOutline = UIColor(rgb: 0x0E0C08)

    // MARK: - Goblin parts

    /// Legs, hunched body and loincloth, in the 34 × 40 goblin frame.
    private static func goblinBody(_ ctx: CGContext, palette: GoblinPalette) {
        let skin = UIColor(rgb: palette.skin)
        let shade = UIColor(rgb: palette.shade)
        fill(ctx, CGRect(x: 11, y: 28, width: 3.5, height: 8), shade)
        fill(ctx, CGRect(x: 19.5, y: 28, width: 3.5, height: 8), shade)
        fill(ctx, CGRect(x: 9.5, y: 34.5, width: 6, height: 2.5), UIColor(rgb: 0x2A2016))
        fill(ctx, CGRect(x: 18.5, y: 34.5, width: 6, height: 2.5), UIColor(rgb: 0x2A2016))

        let body = [CGPoint(x: 10, y: 16), CGPoint(x: 7, y: 26), CGPoint(x: 10, y: 31),
                    CGPoint(x: 24, y: 31), CGPoint(x: 26, y: 22), CGPoint(x: 21, y: 14)]
        fillPolygon(ctx, body, skin)
        fillPolygon(ctx, [CGPoint(x: 21, y: 14), CGPoint(x: 26, y: 22), CGPoint(x: 24, y: 31),
                          CGPoint(x: 17, y: 31)], shade)
        strokePolygon(ctx, body, inkOutline, width: 1.1)

        fillPolygon(ctx, [CGPoint(x: 9, y: 26), CGPoint(x: 25, y: 26), CGPoint(x: 23, y: 32),
                          CGPoint(x: 20, y: 30), CGPoint(x: 17, y: 33), CGPoint(x: 14, y: 30),
                          CGPoint(x: 11, y: 32)], UIColor(rgb: palette.cloth))
    }

    /// Head, ears, eyes and teeth, with optional headgear. `origin` is the
    /// top-left of a 17 × 15 head at `scale` 1.
    private static func goblinHead(_ ctx: CGContext, origin: CGPoint, scale: CGFloat = 1,
                                   palette: GoblinPalette, headgear: Headgear) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: origin.x + x * scale, y: origin.y + y * scale, width: w * scale, height: h * scale)
        }
        let skin = UIColor(rgb: palette.skin)
        let shade = UIColor(rgb: palette.shade)

        var hooded = false
        if case .hood = headgear { hooded = true }
        if !hooded {
            fillPolygon(ctx, [p(1, 6), p(-6.5, 3), p(0, 9.5)], shade)
            fillPolygon(ctx, [p(16, 6), p(24, 2.5), p(17, 9.5)], shade)
        }
        let head = r(0, 0, 17, 15)
        ctx.setFillColor(skin.cgColor)
        ctx.fillEllipse(in: head)
        ctx.setStrokeColor(inkOutline.cgColor)
        ctx.setLineWidth(1.1)
        ctx.strokeEllipse(in: head)

        switch headgear {
        case .none:
            break
        case .hood(let color):
            let cowl = [p(-1.5, 12), p(-0.5, 2), p(8.5, -3), p(17.5, 2), p(18.5, 12), p(14.5, 5.5),
                        p(8.5, 3.2), p(2.5, 5.5)]
            fillPolygon(ctx, cowl, UIColor(rgb: color))
            strokePolygon(ctx, cowl, inkOutline, width: 1)
        case .helmet(let color):
            var dome: [CGPoint] = []
            for step in 0...10 {
                let angle = CGFloat.pi + CGFloat(step) / 10 * .pi
                dome.append(p(8.5 + cos(angle) * 9.4, 5.5 + sin(angle) * 8))
            }
            fillPolygon(ctx, dome, UIColor(rgb: color))
            strokePolygon(ctx, dome, inkOutline, width: 1)
            fill(ctx, r(-1.2, 4.6, 19.4, 2), UIColor(rgb: color).withAlphaComponent(0.9))
            fill(ctx, r(7.8, 4.5, 1.5, 5.5), UIColor(rgb: color))
            stroke(ctx, from: p(3, 1), to: p(6, -1.5), UIColor(white: 1, alpha: 0.35), width: 1)
        }

        // Brow shadow and glowing eyes: the part that reads at a distance.
        ctx.setFillColor(UIColor(rgb: 0x2C3318).cgColor)
        ctx.fill(r(3, 5.5, 11, 3))
        ctx.setFillColor(UIColor(rgb: palette.eyes).cgColor)
        ctx.fillEllipse(in: r(4.2, 6.2, 3, 2))
        ctx.fillEllipse(in: r(9.8, 6.2, 3, 2))
        ctx.setFillColor(UIColor(rgb: 0xE6DDC4).cgColor)
        ctx.fill(r(5.5, 11, 1.4, 2))
        ctx.fill(r(10.5, 11, 1.4, 2))
    }

    // MARK: - Goblins

    /// The rank-and-file goblin with a rusted blade.
    static func goblin(palette: GoblinPalette = .green, headgear: Headgear = .none) -> Sprite {
        let size = CGSize(width: 34, height: 40)
        let footY: CGFloat = 37
        let image = render(size) { ctx in
            goblinBody(ctx, palette: palette)
            fill(ctx, CGRect(x: 25, y: 23, width: 3, height: 3.5), UIColor(rgb: 0x3A2818))
            fillPolygon(ctx, [CGPoint(x: 26, y: 23), CGPoint(x: 31.5, y: 12), CGPoint(x: 28.5, y: 23)],
                        UIColor(rgb: 0x8C8272))
            stroke(ctx, from: CGPoint(x: 28, y: 21), to: CGPoint(x: 30.5, y: 14), UIColor(rgb: 0x9A5A32), width: 0.7)
            goblinHead(ctx, origin: CGPoint(x: 7, y: 3), palette: palette, headgear: headgear)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    /// Lean, hooded and quick, a knife in each hand.
    static func skulker(palette: GoblinPalette, hood: UInt32) -> Sprite {
        let size = CGSize(width: 32, height: 38)
        let footY: CGFloat = 36
        let image = render(size) { ctx in
            let shade = UIColor(rgb: palette.shade)
            fill(ctx, CGRect(x: 11, y: 27, width: 2.8, height: 8), shade)
            fill(ctx, CGRect(x: 18, y: 27, width: 2.8, height: 8), shade)
            fill(ctx, CGRect(x: 9.5, y: 33.5, width: 5, height: 2.5), UIColor(rgb: 0x1A1612))
            fill(ctx, CGRect(x: 17, y: 33.5, width: 5, height: 2.5), UIColor(rgb: 0x1A1612))
            // A ragged cloak over a thin frame.
            let cloak = [CGPoint(x: 10, y: 14), CGPoint(x: 6, y: 26), CGPoint(x: 8, y: 30), CGPoint(x: 12, y: 27),
                         CGPoint(x: 16, y: 31), CGPoint(x: 20, y: 27), CGPoint(x: 24, y: 29), CGPoint(x: 23, y: 18),
                         CGPoint(x: 20, y: 13)]
            fillPolygon(ctx, cloak, UIColor(rgb: hood))
            strokePolygon(ctx, cloak, inkOutline, width: 1)
            // Knives: one low and forward, one raised.
            for (hand, tip) in [(CGPoint(x: 24, y: 21), CGPoint(x: 30.5, y: 16)),
                                (CGPoint(x: 8, y: 22), CGPoint(x: 2, y: 27))] {
                ctx.setFillColor(UIColor(rgb: palette.skin).cgColor)
                ctx.fillEllipse(in: CGRect(x: hand.x - 1.6, y: hand.y - 1.6, width: 3.2, height: 3.2))
                stroke(ctx, from: hand, to: tip, UIColor(rgb: 0xB8BCC0), width: 1.4)
            }
            goblinHead(ctx, origin: CGPoint(x: 7, y: 2), scale: 0.95, palette: palette, headgear: .hood(hood))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    /// Reach behind a long spear and a battered round shield.
    static func spearman(palette: GoblinPalette, crest: UInt32) -> Sprite {
        let size = CGSize(width: 40, height: 48)
        let footY: CGFloat = 45
        let image = render(size) { ctx in
            // Spear shaft behind the body, head high above.
            stroke(ctx, from: CGPoint(x: 31, y: 44), to: CGPoint(x: 31, y: 6), UIColor(rgb: 0x5A3E26), width: 1.8)
            fillPolygon(ctx, [CGPoint(x: 31, y: 0.5), CGPoint(x: 33.6, y: 7), CGPoint(x: 31, y: 9),
                              CGPoint(x: 28.4, y: 7)], UIColor(rgb: 0xA8A294))
            stroke(ctx, from: CGPoint(x: 28.6, y: 9.5), to: CGPoint(x: 33.4, y: 9.5), UIColor(rgb: crest), width: 1.6)

            ctx.saveGState()
            ctx.translateBy(x: 3, y: 8)
            goblinBody(ctx, palette: palette)
            goblinHead(ctx, origin: CGPoint(x: 7, y: 3), palette: palette, headgear: .helmet(0x5E5A50))
            // Crest on the helmet.
            fillPolygon(ctx, [CGPoint(x: 12, y: 1), CGPoint(x: 15.5, y: -6), CGPoint(x: 19, y: 1)], UIColor(rgb: crest))
            ctx.restoreGState()

            // Hand on the shaft, and the shield on the far arm.
            ctx.setFillColor(UIColor(rgb: palette.skin).cgColor)
            ctx.fillEllipse(in: CGRect(x: 29, y: 27, width: 4, height: 4))
            let shield = CGRect(x: 3, y: 23, width: 12, height: 14)
            ctx.setFillColor(UIColor(rgb: 0x6A4A2A).cgColor)
            ctx.fillEllipse(in: shield)
            ctx.setStrokeColor(UIColor(rgb: 0x8C8272).cgColor)
            ctx.setLineWidth(1.4)
            ctx.strokeEllipse(in: shield.insetBy(dx: 1, dy: 1))
            ctx.setFillColor(UIColor(rgb: 0x9C968A).cgColor)
            ctx.fillEllipse(in: CGRect(x: 7.6, y: 28.5, width: 3, height: 3))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    /// A hulking goblin in scraps of plate, dragging a spiked club.
    static func brute(palette: GoblinPalette, scarred: Bool) -> Sprite {
        let scale: CGFloat = 1.45
        let size = CGSize(width: 56, height: 60)
        let footY: CGFloat = 1 + 37 * scale
        let image = render(size) { ctx in
            ctx.saveGState()
            ctx.translateBy(x: 3, y: 1)
            ctx.scaleBy(x: scale, y: scale)
            // Club behind the arm.
            let club = [CGPoint(x: 24, y: 27), CGPoint(x: 29, y: 7), CGPoint(x: 35, y: 6), CGPoint(x: 34, y: 12),
                        CGPoint(x: 27, y: 28)]
            fillPolygon(ctx, club, UIColor(rgb: 0x5A3A22))
            strokePolygon(ctx, club, inkOutline, width: 0.8)
            for spike in [CGPoint(x: 30, y: 9), CGPoint(x: 33, y: 8), CGPoint(x: 31.5, y: 12)] {
                fill(ctx, CGRect(x: spike.x, y: spike.y, width: 1.4, height: 1.4), UIColor(rgb: 0xB8BCC0))
            }
            goblinBody(ctx, palette: palette)
            // Shoulder plate and belt.
            ctx.setFillColor(UIColor(rgb: 0x6E6A62).cgColor)
            ctx.fillEllipse(in: CGRect(x: 7, y: 14, width: 10, height: 7))
            ctx.setStrokeColor(inkOutline.cgColor)
            ctx.setLineWidth(0.8)
            ctx.strokeEllipse(in: CGRect(x: 7, y: 14, width: 10, height: 7))
            fill(ctx, CGRect(x: 9, y: 24.5, width: 16, height: 2), UIColor(rgb: 0x2E2218))
            goblinHead(ctx, origin: CGPoint(x: 7, y: 2), palette: palette, headgear: .none)
            if scarred {
                stroke(ctx, from: CGPoint(x: 9, y: 4), to: CGPoint(x: 13.5, y: 12), UIColor(rgb: 0xB05A4A), width: 0.9)
                stroke(ctx, from: CGPoint(x: 18, y: 18), to: CGPoint(x: 22, y: 23), UIColor(rgb: 0xB05A4A), width: 0.8)
            }
            ctx.restoreGState()
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    /// Hauls a powder keg with a sputtering fuse.
    static func sapper() -> Sprite {
        let size = CGSize(width: 36, height: 44)
        let footY: CGFloat = 40
        let palette = GoblinPalette.ochre
        let image = render(size) { ctx in
            // The keg, strapped to the back.
            let keg = CGRect(x: 1, y: 15, width: 13, height: 16)
            ctx.setFillColor(UIColor(rgb: 0x6A4424).cgColor)
            ctx.fillEllipse(in: keg)
            ctx.setStrokeColor(inkOutline.cgColor)
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: keg)
            fill(ctx, CGRect(x: 1.5, y: 19, width: 12, height: 1.4), UIColor(rgb: 0x3A3632))
            fill(ctx, CGRect(x: 1.5, y: 26, width: 12, height: 1.4), UIColor(rgb: 0x3A3632))
            // Fuse and spark.
            ctx.setStrokeColor(UIColor(rgb: 0x2A2016).cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: 7, y: 15))
            ctx.addQuadCurve(to: CGPoint(x: 3, y: 6), control: CGPoint(x: 1, y: 11))
            ctx.strokePath()
            radialGradient(ctx, center: CGPoint(x: 3, y: 5.5), radius: 4.5,
                           inner: UIColor(rgb: 0xFFF0A0), outer: UIColor(rgb: 0xFF7A20, alpha: 0))

            ctx.saveGState()
            ctx.translateBy(x: 2, y: 3)
            goblinBody(ctx, palette: palette)
            goblinHead(ctx, origin: CGPoint(x: 7, y: 3), palette: palette, headgear: .none)
            // Soot-smudged goggles.
            fill(ctx, CGRect(x: 6.5, y: 8.5, width: 18, height: 1.3), UIColor(rgb: 0x2A2016))
            ctx.setFillColor(UIColor(rgb: 0xC89A4A).cgColor)
            ctx.fillEllipse(in: CGRect(x: 10.5, y: 7.4, width: 4, height: 3.6))
            ctx.fillEllipse(in: CGRect(x: 16.2, y: 7.4, width: 4, height: 3.6))
            ctx.restoreGState()
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    // MARK: - Allies

    static func skeleton() -> Sprite {
        let size = CGSize(width: 32, height: 44)
        let footY: CGFloat = 42
        let image = render(size) { ctx in
            let bone = UIColor(rgb: 0xE6DECB)
            let dark = UIColor(rgb: 0x1A1616)
            // Legs and pelvis.
            stroke(ctx, from: CGPoint(x: 13, y: 29), to: CGPoint(x: 11, y: 41), bone, width: 2)
            stroke(ctx, from: CGPoint(x: 18, y: 29), to: CGPoint(x: 20, y: 41), bone, width: 2)
            fill(ctx, CGRect(x: 11, y: 27, width: 10, height: 3), bone)
            // Spine and ribs.
            stroke(ctx, from: CGPoint(x: 16, y: 27), to: CGPoint(x: 16, y: 14), bone, width: 1.8)
            for y in stride(from: CGFloat(16), through: 24, by: 3.5) {
                stroke(ctx, from: CGPoint(x: 11, y: y), to: CGPoint(x: 21, y: y), bone, width: 1.4)
            }
            // Arms: one holding a notched blade forward.
            stroke(ctx, from: CGPoint(x: 11, y: 15), to: CGPoint(x: 8, y: 25), bone, width: 1.6)
            stroke(ctx, from: CGPoint(x: 21, y: 15), to: CGPoint(x: 25, y: 22), bone, width: 1.6)
            fillPolygon(ctx, [CGPoint(x: 24, y: 23), CGPoint(x: 30, y: 9), CGPoint(x: 27, y: 23)],
                        UIColor(rgb: 0x8C8272))
            // Skull with glowing sockets.
            let skull = CGRect(x: 9.5, y: 1, width: 13, height: 12)
            ctx.setFillColor(bone.cgColor)
            ctx.fillEllipse(in: skull)
            ctx.setFillColor(dark.cgColor)
            ctx.fillEllipse(in: CGRect(x: 12, y: 5, width: 3.2, height: 3.2))
            ctx.fillEllipse(in: CGRect(x: 17, y: 5, width: 3.2, height: 3.2))
            fill(ctx, CGRect(x: 13, y: 10.5, width: 6, height: 1.2), dark)
            ctx.setFillColor(UIColor(rgb: 0xB080FF).cgColor)
            ctx.fillEllipse(in: CGRect(x: 13, y: 6, width: 1.3, height: 1.3))
            ctx.fillEllipse(in: CGRect(x: 18, y: 6, width: 1.3, height: 1.3))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    static func bear() -> Sprite {
        let size = CGSize(width: 60, height: 46)
        let footY: CGFloat = 43
        let image = render(size) { ctx in
            let fur = UIColor(rgb: 0x5A3E2A)
            let furShade = UIColor(rgb: 0x3E2A1C)
            for leg in [CGRect(x: 9, y: 30, width: 8, height: 13), CGRect(x: 19, y: 31, width: 7, height: 12),
                        CGRect(x: 35, y: 31, width: 7, height: 12), CGRect(x: 44, y: 30, width: 8, height: 13)] {
                fill(ctx, leg, furShade)
            }
            let body = CGRect(x: 4, y: 11, width: 46, height: 26)
            ctx.setFillColor(fur.cgColor)
            ctx.fillEllipse(in: body)
            ctx.setStrokeColor(inkOutline.cgColor)
            ctx.setLineWidth(1.2)
            ctx.strokeEllipse(in: body)
            // Shoulder hump highlight.
            ctx.setFillColor(UIColor(rgb: 0x7A5A3E).cgColor)
            ctx.fillEllipse(in: CGRect(x: 26, y: 12, width: 14, height: 7))
            // Head.
            let head = CGRect(x: 40, y: 8, width: 18, height: 17)
            ctx.setFillColor(fur.cgColor)
            ctx.fillEllipse(in: head)
            ctx.setStrokeColor(inkOutline.cgColor)
            ctx.strokeEllipse(in: head)
            ctx.fillEllipse(in: CGRect(x: 41, y: 5, width: 6, height: 6))
            ctx.setFillColor(fur.cgColor)
            ctx.fillEllipse(in: CGRect(x: 41, y: 5, width: 6, height: 6))
            ctx.setFillColor(UIColor(rgb: 0x9A7A5A).cgColor)
            ctx.fillEllipse(in: CGRect(x: 50, y: 15, width: 9, height: 7))
            ctx.setFillColor(UIColor(rgb: 0x100C0A).cgColor)
            ctx.fillEllipse(in: CGRect(x: 56, y: 16, width: 3, height: 2.4))
            ctx.fillEllipse(in: CGRect(x: 48, y: 12, width: 2.4, height: 2.4))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    static func tiger() -> Sprite {
        let size = CGSize(width: 56, height: 36)
        let footY: CGFloat = 34
        let image = render(size) { ctx in
            let coat = UIColor(rgb: 0xD8832A)
            let stripe = UIColor(rgb: 0x2A1810)
            // Tail curling up behind.
            ctx.setStrokeColor(coat.cgColor)
            ctx.setLineWidth(3)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 8, y: 16))
            ctx.addQuadCurve(to: CGPoint(x: 3, y: 4), control: CGPoint(x: 0, y: 14))
            ctx.strokePath()
            for leg in [CGRect(x: 10, y: 22, width: 4.5, height: 12), CGRect(x: 17, y: 23, width: 4.5, height: 11),
                        CGRect(x: 33, y: 23, width: 4.5, height: 11), CGRect(x: 40, y: 22, width: 4.5, height: 12)] {
                fill(ctx, leg, UIColor(rgb: 0xB86A20))
            }
            let body = CGRect(x: 6, y: 10, width: 40, height: 17)
            ctx.setFillColor(coat.cgColor)
            ctx.fillEllipse(in: body)
            ctx.setFillColor(UIColor(rgb: 0xF0D8B0).cgColor)
            ctx.fillEllipse(in: CGRect(x: 14, y: 20, width: 24, height: 6))
            for x in stride(from: CGFloat(12), through: 40, by: 6) {
                stroke(ctx, from: CGPoint(x: x, y: 11), to: CGPoint(x: x + 2.5, y: 19), stripe, width: 1.6)
            }
            ctx.setStrokeColor(inkOutline.cgColor)
            ctx.setLineWidth(1.1)
            ctx.strokeEllipse(in: body)
            // Head.
            let head = CGRect(x: 39, y: 5, width: 15, height: 14)
            ctx.setFillColor(coat.cgColor)
            ctx.fillEllipse(in: head)
            ctx.strokeEllipse(in: head)
            fillPolygon(ctx, [CGPoint(x: 41, y: 7), CGPoint(x: 42, y: 1.5), CGPoint(x: 45.5, y: 5.5)], coat)
            ctx.setFillColor(UIColor(rgb: 0xF0D8B0).cgColor)
            ctx.fillEllipse(in: CGRect(x: 47, y: 11, width: 7, height: 6))
            ctx.setFillColor(UIColor(rgb: 0xE8D040).cgColor)
            ctx.fillEllipse(in: CGRect(x: 47, y: 8, width: 2.6, height: 2))
            stroke(ctx, from: CGPoint(x: 42, y: 9), to: CGPoint(x: 44, y: 12), stripe, width: 1)
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    /// Hovers: anchored below its body so it flies above its position.
    static func owl() -> Sprite {
        let size = CGSize(width: 32, height: 32)
        let image = render(size) { ctx in
            let feathers = UIColor(rgb: 0x7A5A3A)
            // Wings half-spread.
            fillPolygon(ctx, [CGPoint(x: 9, y: 12), CGPoint(x: 0.5, y: 20), CGPoint(x: 8, y: 24)],
                        UIColor(rgb: 0x5A4028))
            fillPolygon(ctx, [CGPoint(x: 23, y: 12), CGPoint(x: 31.5, y: 20), CGPoint(x: 24, y: 24)],
                        UIColor(rgb: 0x5A4028))
            let body = CGRect(x: 8, y: 7, width: 16, height: 22)
            ctx.setFillColor(feathers.cgColor)
            ctx.fillEllipse(in: body)
            ctx.setStrokeColor(inkOutline.cgColor)
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: body)
            // Ear tufts and facial disc.
            fillPolygon(ctx, [CGPoint(x: 9.5, y: 9), CGPoint(x: 9, y: 3), CGPoint(x: 13, y: 7.5)], feathers)
            fillPolygon(ctx, [CGPoint(x: 22.5, y: 9), CGPoint(x: 23, y: 3), CGPoint(x: 19, y: 7.5)], feathers)
            ctx.setFillColor(UIColor(rgb: 0xD8C8A8).cgColor)
            ctx.fillEllipse(in: CGRect(x: 10, y: 8, width: 12, height: 10))
            for x in [CGFloat(11), 17] {
                ctx.setFillColor(UIColor(rgb: 0xF0C040).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: 9.5, width: 4.5, height: 4.5))
                ctx.setFillColor(UIColor(rgb: 0x100C0A).cgColor)
                ctx.fillEllipse(in: CGRect(x: x + 1.3, y: 10.8, width: 2, height: 2))
            }
            fillPolygon(ctx, [CGPoint(x: 15, y: 14), CGPoint(x: 17, y: 14), CGPoint(x: 16, y: 17)],
                        UIColor(rgb: 0x3A2818))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: -0.9))
    }

    /// Hovers a little off the ground.
    static func imp() -> Sprite {
        let size = CGSize(width: 32, height: 36)
        let image = render(size) { ctx in
            let hide = UIColor(rgb: 0xA0302A)
            // Bat wings.
            fillPolygon(ctx, [CGPoint(x: 11, y: 14), CGPoint(x: 1, y: 8), CGPoint(x: 3, y: 16), CGPoint(x: 0.5, y: 22),
                              CGPoint(x: 10, y: 20)], UIColor(rgb: 0x5A1A1A))
            fillPolygon(ctx, [CGPoint(x: 21, y: 14), CGPoint(x: 31, y: 8), CGPoint(x: 29, y: 16), CGPoint(x: 31.5, y: 22),
                              CGPoint(x: 22, y: 20)], UIColor(rgb: 0x5A1A1A))
            // Tail.
            ctx.setStrokeColor(hide.cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 13, y: 28))
            ctx.addQuadCurve(to: CGPoint(x: 6, y: 33), control: CGPoint(x: 8, y: 26))
            ctx.strokePath()
            fillPolygon(ctx, [CGPoint(x: 6, y: 31), CGPoint(x: 3.5, y: 34.5), CGPoint(x: 7.5, y: 34)], hide)
            // Body and head.
            let body = CGRect(x: 10, y: 14, width: 12, height: 16)
            ctx.setFillColor(hide.cgColor)
            ctx.fillEllipse(in: body)
            let head = CGRect(x: 9.5, y: 4, width: 13, height: 12)
            ctx.fillEllipse(in: head)
            ctx.setStrokeColor(inkOutline.cgColor)
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: head)
            fillPolygon(ctx, [CGPoint(x: 11, y: 6), CGPoint(x: 9, y: 0.5), CGPoint(x: 13.5, y: 4.5)],
                        UIColor(rgb: 0x2A1A14))
            fillPolygon(ctx, [CGPoint(x: 21, y: 6), CGPoint(x: 23, y: 0.5), CGPoint(x: 18.5, y: 4.5)],
                        UIColor(rgb: 0x2A1A14))
            ctx.setFillColor(UIColor(rgb: 0xFFD040).cgColor)
            ctx.fillEllipse(in: CGRect(x: 12.5, y: 8.5, width: 2.8, height: 2.2))
            ctx.fillEllipse(in: CGRect(x: 17, y: 8.5, width: 2.8, height: 2.2))
            fill(ctx, CGRect(x: 13.5, y: 12.5, width: 5, height: 1), UIColor(rgb: 0x2A0A0A))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: -0.25))
    }

    static func wolf() -> Sprite {
        let size = CGSize(width: 52, height: 34)
        let footY: CGFloat = 32
        let image = render(size) { ctx in
            let coat = UIColor(rgb: 0x8A8A88)
            let shade = UIColor(rgb: 0x5E5E5C)
            // Bushy tail.
            fillPolygon(ctx, [CGPoint(x: 9, y: 14), CGPoint(x: 0.5, y: 11), CGPoint(x: 2, y: 17), CGPoint(x: 9, y: 19)], shade)
            for leg in [CGRect(x: 10, y: 21, width: 4, height: 11), CGRect(x: 16, y: 22, width: 4, height: 10),
                        CGRect(x: 31, y: 22, width: 4, height: 10), CGRect(x: 37, y: 21, width: 4, height: 11)] {
                fill(ctx, leg, shade)
            }
            let body = CGRect(x: 7, y: 11, width: 36, height: 14)
            ctx.setFillColor(coat.cgColor)
            ctx.fillEllipse(in: body)
            ctx.setStrokeColor(inkOutline.cgColor)
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: body)
            // Head with pointed ears and a long snout.
            let head = [CGPoint(x: 36, y: 12), CGPoint(x: 39, y: 3), CGPoint(x: 42, y: 8), CGPoint(x: 44, y: 3),
                        CGPoint(x: 46, y: 9), CGPoint(x: 51.5, y: 14), CGPoint(x: 46, y: 18), CGPoint(x: 38, y: 19)]
            fillPolygon(ctx, head, coat)
            strokePolygon(ctx, head, inkOutline, width: 1)
            ctx.setFillColor(UIColor(rgb: 0xE8E0A0).cgColor)
            ctx.fillEllipse(in: CGRect(x: 42.5, y: 10, width: 2.4, height: 1.8))
            ctx.setFillColor(UIColor(rgb: 0x100C0A).cgColor)
            ctx.fillEllipse(in: CGRect(x: 49.5, y: 13, width: 2.2, height: 2))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    static func treant() -> Sprite {
        let size = CGSize(width: 54, height: 68)
        let footY: CGFloat = 65
        let image = render(size) { ctx in
            let bark = UIColor(rgb: 0x5A4430)
            let barkShade = UIColor(rgb: 0x3E2E20)
            // Root feet.
            fillPolygon(ctx, [CGPoint(x: 14, y: 56), CGPoint(x: 6, y: 65), CGPoint(x: 22, y: 65), CGPoint(x: 21, y: 56)],
                        barkShade)
            fillPolygon(ctx, [CGPoint(x: 31, y: 56), CGPoint(x: 30, y: 65), CGPoint(x: 47, y: 65), CGPoint(x: 39, y: 56)],
                        barkShade)
            // Trunk.
            let trunk = [CGPoint(x: 15, y: 58), CGPoint(x: 13, y: 26), CGPoint(x: 18, y: 18), CGPoint(x: 35, y: 18),
                         CGPoint(x: 40, y: 26), CGPoint(x: 38, y: 58)]
            fillPolygon(ctx, trunk, bark)
            strokePolygon(ctx, trunk, inkOutline, width: 1.2)
            for x in [CGFloat(20), 26, 32] {
                stroke(ctx, from: CGPoint(x: x, y: 24), to: CGPoint(x: x + 1, y: 54), barkShade, width: 1.2)
            }
            // Branch arms.
            stroke(ctx, from: CGPoint(x: 15, y: 30), to: CGPoint(x: 3, y: 44), bark, width: 4)
            stroke(ctx, from: CGPoint(x: 38, y: 30), to: CGPoint(x: 51, y: 42), bark, width: 4)
            // Leafy crown.
            for leaves in [CGRect(x: 6, y: 4, width: 22, height: 18), CGRect(x: 22, y: 1, width: 24, height: 20),
                           CGRect(x: 14, y: 10, width: 26, height: 14)] {
                ctx.setFillColor(UIColor(rgb: 0x3E6A2E).cgColor)
                ctx.fillEllipse(in: leaves)
            }
            ctx.setFillColor(UIColor(rgb: 0x5A8A3E).cgColor)
            ctx.fillEllipse(in: CGRect(x: 18, y: 4, width: 12, height: 8))
            // Glowing eyes in the bark.
            ctx.setFillColor(UIColor(rgb: 0xB8F070).cgColor)
            ctx.fillEllipse(in: CGRect(x: 20, y: 28, width: 4, height: 3))
            ctx.fillEllipse(in: CGRect(x: 29, y: 28, width: 4, height: 3))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: (size.height - footY) / size.height))
    }

    /// A short blade pointing along +x, spun by its orbit.
    static func orbitingBlade() -> Sprite {
        let size = CGSize(width: 30, height: 10)
        let image = render(size) { ctx in
            fillPolygon(ctx, [CGPoint(x: 9, y: 3.2), CGPoint(x: 29.5, y: 5), CGPoint(x: 9, y: 6.8)],
                        UIColor(rgb: 0xD8DEE6))
            stroke(ctx, from: CGPoint(x: 10, y: 5), to: CGPoint(x: 26, y: 5), UIColor(rgb: 0x9AA0A8), width: 0.7)
            fill(ctx, CGRect(x: 7.5, y: 1, width: 2, height: 8), UIColor(rgb: 0x8C7A55))
            fill(ctx, CGRect(x: 1, y: 4, width: 6.5, height: 2), UIColor(rgb: 0x4A3322))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }
}
