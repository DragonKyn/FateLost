import CoreGraphics

/// Floating virtual joystick logic, independent of rendering and UIKit.
///
/// The stick appears wherever the thumb lands in its zone, so the player
/// never has to find a fixed control. Coordinates are screen-space points
/// with y up (SpriteKit convention).
struct JoystickModel {
    let radius: CGFloat
    /// Fraction of `radius` that produces no movement.
    let deadZone: CGFloat
    /// Drag the base along when the thumb passes the rim.
    let followsThumb: Bool

    private(set) var isActive = false
    private(set) var base: CGPoint = .zero
    private(set) var thumb: CGPoint = .zero

    init(radius: CGFloat, deadZone: CGFloat, followsThumb: Bool) {
        precondition(radius > 0, "Joystick radius must be positive")
        self.radius = radius
        self.deadZone = deadZone.clamped(0, 0.95)
        self.followsThumb = followsThumb
    }

    mutating func begin(at point: CGPoint) {
        isActive = true
        base = point
        thumb = point
    }

    mutating func move(to point: CGPoint) {
        guard isActive else { return }
        thumb = point
        let offset = thumb - base
        if followsThumb, offset.length > radius {
            base = thumb - offset.normalized * radius
        }
    }

    mutating func end() {
        isActive = false
        thumb = base
    }

    /// Knob displacement from the base, limited to the rim.
    var knobOffset: CGPoint {
        (thumb - base).clampedLength(maximum: radius)
    }

    /// Direction with magnitude 0…1. The dead zone is removed and the rest of
    /// the travel rescaled, so small deliberate movements are still possible.
    var output: CGPoint {
        guard isActive else { return .zero }
        let raw = knobOffset / radius
        let magnitude = raw.length
        guard magnitude > deadZone else { return .zero }
        let scaled = min(1, (magnitude - deadZone) / (1 - deadZone))
        return raw.normalized * scaled
    }
}
