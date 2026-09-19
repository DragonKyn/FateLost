import CoreGraphics
import Foundation

/// Gathers experience lying in the world.
///
/// Orbs within the player's pickup radius are drawn in, accelerating, and
/// collected on arrival, so walking near a fight sweeps up its rewards
/// without chasing every mote.
enum PickupSystem {
    static let collectDistance: CGFloat = 0.35
    static let initialSpeed: CGFloat = 3
    static let acceleration: CGFloat = 32
    static let maximumSpeed: CGFloat = 20

    static func step(_ combat: inout CombatState, player: PlayerState, dt: TimeInterval) {
        guard !combat.orbs.isEmpty, !player.isDefeated else { return }
        let radius = CGFloat(combat.sheet[.pickupRadius])
        let radiusSquared = radius * radius
        let step = CGFloat(dt)

        var index = combat.orbs.count - 1
        while index >= 0 {
            var orb = combat.orbs[index]
            let offset = combat.world.delta(from: orb.position, to: player.position)
            let distanceSquared = offset.lengthSquared
            if !orb.attracted, distanceSquared <= radiusSquared {
                orb.attracted = true
                orb.speed = initialSpeed
            }
            if orb.attracted {
                orb.speed = min(orb.speed + acceleration * step, maximumSpeed)
                let distance = distanceSquared.squareRoot()
                if distance <= collectDistance + orb.speed * step {
                    combat.experienceCollected += orb.value
                    combat.orbs.swapRemove(at: index)
                    index -= 1
                    continue
                }
                orb.position = combat.world.wrap(orb.position + offset / distance * orb.speed * step)
            }
            combat.orbs[index] = orb
            index -= 1
        }
    }
}
