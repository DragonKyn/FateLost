import CoreGraphics

// Gameplay code treats CGPoint as a 2D vector. CoreGraphics is available to
// unit tests without SpriteKit, so simulation code built on these helpers
// stays testable in isolation.

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static prefix func - (value: CGPoint) -> CGPoint {
        CGPoint(x: -value.x, y: -value.y)
    }

    static func * (lhs: CGPoint, scalar: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * scalar, y: lhs.y * scalar)
    }

    static func / (lhs: CGPoint, scalar: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / scalar, y: lhs.y / scalar)
    }

    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }

    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs - rhs
    }

    var length: CGFloat { (x * x + y * y).squareRoot() }

    var lengthSquared: CGFloat { x * x + y * y }

    /// Unit vector in the same direction, or `.zero` for a zero vector.
    var normalized: CGPoint {
        let len = length
        return len > 0 ? self / len : .zero
    }

    func clampedLength(maximum: CGFloat) -> CGPoint {
        let len = length
        guard len > maximum, len > 0 else { return self }
        return self * (maximum / len)
    }

    func dot(_ other: CGPoint) -> CGFloat { x * other.x + y * other.y }

    /// Moves toward `target` by at most `maxDelta`, never overshooting.
    func moved(toward target: CGPoint, maxDelta: CGFloat) -> CGPoint {
        let delta = target - self
        let distance = delta.length
        guard distance > maxDelta, distance > 0 else { return target }
        return self + delta * (maxDelta / distance)
    }

    func lerp(to target: CGPoint, t: CGFloat) -> CGPoint {
        self + (target - self) * t
    }
}

extension CGFloat {
    func clamped(_ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, lower), upper)
    }
}

extension Double {
    func clamped(_ lower: Double, _ upper: Double) -> Double {
        Swift.min(Swift.max(self, lower), upper)
    }
}
