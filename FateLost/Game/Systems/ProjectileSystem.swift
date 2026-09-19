import CoreGraphics
import Foundation

/// Flies projectiles, resolves their hits and bursts.
///
/// A projectile strikes the first enemy it touches. If it can pierce, it
/// carries on (never striking the same enemy twice); otherwise it is spent.
/// Projectiles with a splash radius burst on impact, damaging everything
/// around the point of contact.
struct ProjectileSystem {
    /// Fraction of standard knockback a projectile hit applies.
    private static let knockbackScale: CGFloat = 0.45
    private static let splashKnockbackScale: CGFloat = 0.7

    func step(_ combat: inout CombatState, dt: TimeInterval) {
        guard !combat.projectiles.isEmpty else { return }
        let step = CGFloat(dt)
        let padding = combat.largestEnemyRadius

        var index = combat.projectiles.count - 1
        while index >= 0 {
            var projectile = combat.projectiles[index]
            projectile.remainingLife -= dt
            projectile.position = combat.world.wrap(projectile.position + projectile.velocity * step)

            var spent = projectile.remainingLife <= 0
            if !spent, let struck = firstContact(of: projectile, padding: padding, combat: &combat) {
                spent = impact(&projectile, on: struck, combat: &combat)
            }

            if spent {
                combat.projectiles.swapRemove(at: index)
            } else {
                combat.projectiles[index] = projectile
            }
            index -= 1
        }
    }

    /// Nearest living enemy touching the projectile that it hasn't struck yet.
    private func firstContact(of projectile: Projectile, padding: CGFloat, combat: inout CombatState) -> Int? {
        combat.nearby.removeAll(keepingCapacity: true)
        combat.grid.query(around: projectile.position, radius: projectile.radius + padding, into: &combat.nearby)
        var best: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for index in combat.nearby where index < combat.enemies.count && combat.enemies.health[index] > 0 {
            guard !projectile.struckEnemyIDs.contains(combat.enemies.ids[index]) else { continue }
            let distance = combat.world.distance(projectile.position, combat.enemies.positions[index])
            let contact = projectile.radius + combat.enemies.definition(at: index).radius
            if distance <= contact, distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    /// Applies a hit and reports whether the projectile is used up.
    private func impact(_ projectile: inout Projectile, on enemy: Int, combat: inout CombatState) -> Bool {
        let direction = projectile.direction
        projectile.struckEnemyIDs.append(combat.enemies.ids[enemy])

        if projectile.splashRadius > 0 {
            burst(at: combat.enemies.positions[enemy], projectile: projectile, combat: &combat)
            return true
        }

        combat.damageEnemy(at: enemy, base: projectile.baseDamage, direction: direction,
                           knockbackScale: Self.knockbackScale)
        if projectile.pierceRemaining > 0 {
            projectile.pierceRemaining -= 1
            return false
        }
        return true
    }

    private func burst(at center: CGPoint, projectile: Projectile, combat: inout CombatState) {
        let radius = projectile.splashRadius
        let reach = radius + combat.largestEnemyRadius
        combat.events.append(.explosion(position: center, radius: radius))
        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: center, radius: reach, into: &combat.nearbySecondary)
        for index in combat.nearbySecondary where index < combat.enemies.count {
            let offset = combat.world.delta(from: center, to: combat.enemies.positions[index])
            let distance = offset.length
            guard distance <= radius + combat.enemies.definition(at: index).radius else { continue }
            let direction = distance > 0.0001 ? offset / distance : projectile.direction
            combat.damageEnemy(at: index, base: projectile.baseDamage, direction: direction,
                               knockbackScale: Self.splashKnockbackScale)
        }
    }
}
