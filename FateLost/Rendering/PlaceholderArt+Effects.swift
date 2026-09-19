import UIKit

/// Stand-in art for skill projectiles and effects. Most are drawn white so
/// renderers can tint them by visual style.
extension PlaceholderArt {
    static func knife() -> Sprite {
        let size = CGSize(width: 22, height: 8)
        let image = render(size) { ctx in
            fillPolygon(ctx, [CGPoint(x: 8, y: 2.4), CGPoint(x: 21.5, y: 4), CGPoint(x: 8, y: 5.6)],
                        UIColor(rgb: 0xD8DEE6))
            fill(ctx, CGRect(x: 6.5, y: 1, width: 1.6, height: 6), UIColor(rgb: 0x6A5A44))
            fill(ctx, CGRect(x: 1, y: 3, width: 5.5, height: 2), UIColor(rgb: 0x3A2818))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    static func shard() -> Sprite {
        let size = CGSize(width: 26, height: 12)
        let image = render(size) { ctx in
            radialGradient(ctx, center: CGPoint(x: 14, y: 6), radius: 10,
                           inner: UIColor(rgb: 0xBFEAFF, alpha: 0.6), outer: UIColor(rgb: 0xBFEAFF, alpha: 0))
            let crystal = [CGPoint(x: 3, y: 6), CGPoint(x: 13, y: 2), CGPoint(x: 25, y: 6), CGPoint(x: 13, y: 10)]
            fillPolygon(ctx, crystal, UIColor(rgb: 0xDFF6FF))
            fillPolygon(ctx, [CGPoint(x: 13, y: 2), CGPoint(x: 25, y: 6), CGPoint(x: 13, y: 6)], UIColor(rgb: 0x9AD8F5))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    /// A bright head trailing a soft tail, pointing along +x. Drawn white.
    static func energyBolt() -> Sprite {
        let size = CGSize(width: 32, height: 16)
        let image = render(size) { ctx in
            ctx.saveGState()
            ctx.translateBy(x: 14, y: 8)
            ctx.scaleBy(x: 2, y: 1)
            radialGradient(ctx, center: .zero, radius: 7, inner: UIColor(white: 1, alpha: 0.55),
                           outer: UIColor(white: 1, alpha: 0))
            ctx.restoreGState()
            radialGradient(ctx, center: CGPoint(x: 23, y: 8), radius: 7, inner: .white,
                           outer: UIColor(white: 1, alpha: 0))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.7, y: 0.5))
    }

    /// An ember of experience: a bright golden core in a warm halo.
    static func ember() -> Sprite {
        let dimension: CGFloat = 20
        let image = render(CGSize(width: dimension, height: dimension)) { ctx in
            let center = CGPoint(x: dimension / 2, y: dimension / 2)
            radialGradient(ctx, center: center, radius: dimension / 2,
                           inner: UIColor(rgb: 0xFFB040, alpha: 0.75), outer: UIColor(rgb: 0xFF6A20, alpha: 0))
            radialGradient(ctx, center: center, radius: 3.6, inner: UIColor(rgb: 0xFFF6D0),
                           outer: UIColor(rgb: 0xFFD060, alpha: 0))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    /// A 90° wedge from the centre toward +x, brightest at its far edge.
    static func cone() -> Sprite {
        let dimension: CGFloat = 128
        let center = CGPoint(x: dimension / 2, y: dimension / 2)
        let image = render(CGSize(width: dimension, height: dimension)) { ctx in
            let outer = dimension / 2 - 1
            let bands: [(inner: CGFloat, alpha: CGFloat)] = [(0.05, 0.12), (0.45, 0.2), (0.7, 0.35), (0.88, 0.7)]
            for band in bands {
                let path = UIBezierPath()
                path.addArc(withCenter: center, radius: outer, startAngle: -.pi / 4, endAngle: .pi / 4, clockwise: true)
                path.addArc(withCenter: center, radius: outer * band.inner, startAngle: .pi / 4, endAngle: -.pi / 4,
                            clockwise: false)
                path.close()
                ctx.setFillColor(UIColor(white: 1, alpha: band.alpha).cgColor)
                ctx.addPath(path.cgPath)
                ctx.fillPath()
            }
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    /// A soft disc with a brighter rim, for zones on the ground.
    static func disc() -> Sprite {
        let dimension: CGFloat = 128
        let image = render(CGSize(width: dimension, height: dimension)) { ctx in
            let center = CGPoint(x: dimension / 2, y: dimension / 2)
            let colors = [UIColor(white: 1, alpha: 0.12).cgColor, UIColor(white: 1, alpha: 0.28).cgColor,
                          UIColor(white: 1, alpha: 0.7).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                            locations: [0, 0.8, 0.95, 1]) else { return }
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: dimension / 2, options: [])
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.5))
    }

    /// A tall shaft of light, anchored at its base.
    static func pillar() -> Sprite {
        let size = CGSize(width: 40, height: 180)
        let image = render(size) { ctx in
            let colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0.55).cgColor,
                          UIColor(white: 1, alpha: 0.9).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                            locations: [0, 0.7, 1]) else { return }
            // Fades upward, and toward the sides.
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: 4, y: -40, width: 32, height: 260))
            ctx.clip()
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 20, y: 0), end: CGPoint(x: 20, y: 180), options: [])
            ctx.restoreGState()
            radialGradient(ctx, center: CGPoint(x: 20, y: 174), radius: 12, inner: .white,
                           outer: UIColor(white: 1, alpha: 0))
        }
        return Sprite(image: image, anchor: CGPoint(x: 0.5, y: 0.03))
    }
}
