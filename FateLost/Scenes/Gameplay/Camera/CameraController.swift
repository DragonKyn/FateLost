import SpriteKit

/// Smooth follow camera with look-ahead and trauma-based shake.
///
/// Follow uses frame-rate-independent exponential smoothing. Shake follows
/// the "trauma" model: events add trauma, trauma decays over time, and the
/// visible offset scales with trauma squared, so small bumps stay subtle and
/// big hits land hard. Shake is suppressed entirely when the player disables
/// it in settings.
@MainActor
final class CameraController {
    let camera = SKCameraNode()

    private let tuning: CameraTuning
    /// Converts world-unit tuning (look-ahead) to screen points.
    private let pointsPerWorldUnit: CGFloat
    /// Camera position before shake is applied.
    private var followPosition: CGPoint = .zero
    private var lead: CGPoint = .zero
    private var trauma: CGFloat = 0
    private var shakeTime: CGFloat = 0

    /// Current shake displacement, so screen-space UI can cancel it out.
    private(set) var shakeOffset: CGPoint = .zero
    var shakeEnabled = true

    init(tuning: CameraTuning, pointsPerWorldUnit: CGFloat) {
        self.tuning = tuning
        self.pointsPerWorldUnit = pointsPerWorldUnit
    }

    /// Scale that frames roughly `targetVisibleHeight` points of world on any
    /// screen, clamped so iPads show more rather than magnifying placeholder
    /// art into blur.
    func configureScale(forViewSize size: CGSize) {
        guard size.height > 0 else { return }
        let scale = (tuning.targetVisibleHeight / size.height).clamped(tuning.minimumScale, tuning.maximumScale)
        camera.setScale(scale)
    }

    func snap(to target: CGPoint) {
        followPosition = target
        lead = .zero
        camera.position = target
    }

    /// - Parameters:
    ///   - target: Screen-space point to follow (the player).
    ///   - motion: Screen-space direction of travel with magnitude 0…1.
    func update(target: CGPoint, motion: CGPoint, dt: CGFloat) {
        let leadTarget = motion.clampedLength(maximum: 1) * tuning.lookAhead * pointsPerWorldUnit
        lead = lead.lerp(to: leadTarget, t: smoothing(tuning.lookAheadSharpness, dt))
        followPosition = followPosition.lerp(to: target + lead, t: smoothing(tuning.followSharpness, dt))

        updateShake(dt: dt)
        camera.position = followPosition + shakeOffset
    }

    func addTrauma(_ amount: CGFloat) {
        guard shakeEnabled else { return }
        trauma = min(1, trauma + amount)
    }

    /// Moves the camera with the world after a render-frame rebase so the
    /// shift is invisible.
    func shift(by delta: CGPoint) {
        followPosition += delta
        camera.position += delta
    }

    private func updateShake(dt: CGFloat) {
        guard shakeEnabled, trauma > 0 else {
            trauma = 0
            shakeOffset = .zero
            return
        }
        trauma = max(0, trauma - tuning.shakeDecay * dt)
        shakeTime += dt
        let intensity = trauma * trauma * tuning.shakeMaxOffset
        // Two incommensurate sines per axis read as noise without a noise table.
        let t = shakeTime * tuning.shakeFrequency
        let x = (sin(t) + sin(t * 1.73 + 1.3)) * 0.5
        let y = (sin(t * 1.21 + 2.1) + sin(t * 2.07 + 0.4)) * 0.5
        shakeOffset = CGPoint(x: x * intensity, y: y * intensity)
    }

    /// Converts a "sharpness" rate into a lerp factor for this frame.
    private func smoothing(_ sharpness: CGFloat, _ dt: CGFloat) -> CGFloat {
        1 - exp(-sharpness * dt)
    }
}
