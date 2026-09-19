import UIKit

/// The small vector vocabulary every generated creature is drawn with:
/// ovals, smoothed closed shapes and smoothed open strokes.
///
/// Hand-written and shared. The generators under `tools/art/` emit sprite
/// functions that call these; keeping them here means a new generator adds a
/// file without redeclaring a single primitive.
extension PlaceholderArt {
    static func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }

    static func fillOval(_ ctx: CGContext, _ rect: CGRect, _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: rect)
    }

    static func strokeOval(_ ctx: CGContext, _ rect: CGRect, _ color: UIColor, width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.strokeEllipse(in: rect)
    }

    /// A closed quadratic B-spline through the midpoints of `points`.
    static func smoothPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        let count = points.count
        guard count > 2 else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        path.move(to: mid(points[0], points[1]))
        for index in 0..<count {
            let control = points[(index + 1) % count]
            path.addQuadCurve(to: mid(control, points[(index + 2) % count]), control: control)
        }
        path.closeSubpath()
        return path
    }

    static func fillSmooth(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(smoothPath(points))
        ctx.fillPath()
    }

    static func strokeSmooth(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor, width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.addPath(smoothPath(points))
        ctx.strokePath()
    }

    /// An open stroke through `points`, rounded through the middle ones.
    static func strokeCurve(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor, width: CGFloat) {
        guard let first = points.first else { return }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: first)
        if points.count < 3 {
            points.dropFirst().forEach { ctx.addLine(to: $0) }
        } else {
            for index in 1..<(points.count - 1) {
                let control = points[index]
                let next = points[index + 1]
                let end = index == points.count - 2
                    ? next
                    : CGPoint(x: (control.x + next.x) / 2, y: (control.y + next.y) / 2)
                ctx.addQuadCurve(to: end, control: control)
            }
        }
        ctx.strokePath()
    }
}
