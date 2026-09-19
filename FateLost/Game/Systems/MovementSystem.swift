import CoreGraphics
import Foundation

/// Integrates player movement on the wrapping arena.
///
/// Velocity eases toward the stick's target rather than snapping, which reads
/// as weight, but deceleration is faster than acceleration so letting go of
/// the stick stops the character promptly for precise dodging.
struct MovementSystem {
    let tuning: PlayerTuning

    func step(_ player: inout PlayerState, intent: PlayerIntent, speedMultiplier: CGFloat,
              world: ToroidalWorld, dt: CGFloat) {
        let input = intent.move.clampedLength(maximum: 1)
        let maxSpeed = tuning.baseMoveSpeed * max(0, speedMultiplier)
        let target = input * maxSpeed

        // Speeding up (or turning) uses acceleration; slowing uses deceleration.
        let rate = target.lengthSquared >= player.velocity.lengthSquared
            ? tuning.acceleration
            : tuning.deceleration
        player.velocity = player.velocity.moved(toward: target, maxDelta: rate * dt)

        if input.lengthSquared > 0.0001 {
            player.facing = input.normalized
        }

        player.position = world.wrap(player.position + (player.velocity + player.knockback) * dt)
        player.knockback = player.knockback * CGFloat(exp(-Double(tuning.knockbackDecay * dt)))

        if player.isMoving {
            player.strideTime += Double(dt) * Double(player.velocity.length / max(tuning.baseMoveSpeed, 0.001))
        }
    }
}
