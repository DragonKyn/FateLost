import CoreGraphics
import Foundation

/// Flies projectiles, resolves their hits and bursts.
///
/// A projectile strikes the first enemy it touches. If it can pierce, it
/// carries on (never striking the same enemy twice); otherwise it is spent.
/// Projectiles with a splash radius burst on impact, damaging everything
/// around the point of contact.
///
/// Enemy shots fly through the same code, flagged `isHostile`: they look for
/// the player and their summons instead of the horde, and are spent on the
/// first thing they reach.
struct ProjectileSystem {
    /// Fraction of a projectile's knockback its splash applies.
    private static let splashKnockbackScale: CGFloat = 1.4

    func step(_ combat: inout CombatState, player: inout PlayerState, godMode: Bool, dt: TimeInterval) {
        guard !combat.projectiles.isEmpty else { return }
        let step = CGFloat(dt)
        let padding = combat.largestEnemyRadius

        var index = combat.projectiles.count - 1
        while index >= 0 {
            var projectile = combat.projectiles[index]
            projectile.remainingLife -= dt
            if projectile.turnsAfter > 0 {
                projectile.turnsAfter -= dt
                if projectile.turnsAfter <= 0 {
                    // On the way back it is a fresh throw: everything it
                    // clipped going out is fair game again.
                    projectile.velocity = projectile.velocity * -1
                    projectile.struckEnemyIDs.removeAll(keepingCapacity: true)
                    projectile.turnsAfter = 0
                }
            }
            projectile.position = combat.world.wrap(projectile.position + projectile.velocity * step)

            var spent = projectile.remainingLife <= 0
            if !spent, projectile.isHostile {
                spent = impactOnPlayerSide(projectile, player: &player, godMode: godMode, combat: &combat)
            } else if !spent, let struck = firstContact(of: projectile, padding: padding, combat: &combat) {
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

    /// An enemy shot reaching the player, or one of their summons. Returns
    /// whether it was spent.
    private func impactOnPlayerSide(_ projectile: Projectile, player: inout PlayerState, godMode: Bool,
                                    combat: inout CombatState) -> Bool {
        let toPlayer = combat.world.delta(from: projectile.position, to: player.position)
        if !player.isDefeated, toPlayer.length <= projectile.radius + combat.tuning.playerRadius {
            combat.strikePlayer(&player, amount: projectile.hit.amount, direction: projectile.direction,
                                godMode: godMode)
            combat.events.append(.burst(position: projectile.position, radius: 0.4, visual: projectile.visual))
            return true
        }
        let anchors = combat.allyAnchors
        for anchor in anchors where anchor.isMortal {
            guard combat.world.distance(projectile.position, anchor.position)
                <= projectile.radius + anchor.radius else { continue }
            guard anchor.index < combat.allies.count, combat.allies[anchor.index].id == anchor.id else { continue }
            AllySystem.wound(anchor.index, amount: projectile.hit.amount, &combat)
            combat.events.append(.burst(position: projectile.position, radius: 0.4, visual: projectile.visual))
            return true
        }
        return false
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
            return projectile.pierceRemaining <= 0 || consumePierce(&projectile)
        }

        var hit = projectile.hit
        hit.direction = direction
        combat.strike(enemy, with: hit)
        return projectile.pierceRemaining <= 0 || consumePierce(&projectile)
    }

    /// Uses up one pierce; returns false so the projectile carries on.
    private func consumePierce(_ projectile: inout Projectile) -> Bool {
        projectile.pierceRemaining -= 1
        return false
    }

    private func burst(at center: CGPoint, projectile: Projectile, combat: inout CombatState) {
        let radius = projectile.splashRadius
        let reach = radius + combat.largestEnemyRadius
        combat.events.append(.burst(position: center, radius: radius, visual: projectile.visual))
        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: center, radius: reach, into: &combat.nearbySecondary)
        let candidates = combat.nearbySecondary
        for index in candidates where index < combat.enemies.count {
            let offset = combat.world.delta(from: center, to: combat.enemies.positions[index])
            let distance = offset.length
            guard distance <= radius + combat.enemies.definition(at: index).radius else { continue }
            var hit = projectile.hit
            hit.direction = distance > 0.0001 ? offset / distance : projectile.direction
            hit.knockback = projectile.hit.knockback * Self.splashKnockbackScale
            combat.strike(index, with: hit)
        }
    }
}
