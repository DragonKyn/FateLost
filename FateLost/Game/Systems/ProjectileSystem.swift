import CoreGraphics
import Foundation

/// Flies projectiles, resolves their hits and bursts.
///
/// A projectile strikes the first enemy it touches. If it can pierce, it
/// carries on (never striking the same enemy twice); otherwise it is spent.
/// Projectiles with a splash radius burst on impact, damaging everything
/// around the point of contact.
///
/// Enemy shots are kept apart (`CombatState.hostileProjectiles`), because in a
/// party they look for any hero rather than one: they seek the heroes and
/// their summons instead of the horde, and are spent on the first thing they
/// reach.
struct ProjectileSystem {
    /// Fraction of a projectile's knockback its splash applies.
    private static let splashKnockbackScale: CGFloat = 1.4

    /// Flies the hero's own projectiles and, for a lone hero, the enemy shots
    /// as well. A party runs `stepOwned` for each hero and `stepHostile` once.
    func step(_ combat: inout CombatState, player: inout PlayerState, godMode: Bool, dt: TimeInterval) {
        stepOwned(&combat, dt: dt)
        guard !combat.hostileProjectiles.isEmpty else { return }
        combat.worldAnchors = combat.allyAnchors
        let target = AITarget(position: player.position, isAlive: !player.isDefeated, isHidden: false, hero: 0)
        stepHostile(&combat, targets: [target], dt: dt)
        WorldIncidents.applyToLoneHero(&combat, player: &player, godMode: godMode)
    }

    /// The projectiles a hero has loosed: each strikes the first enemy it
    /// touches. One that can pierce carries on (never striking the same enemy
    /// twice); any other is spent. A projectile with a splash radius bursts on
    /// impact, damaging everything around the point of contact.
    func stepOwned(_ combat: inout CombatState, dt: TimeInterval) {
        guard !combat.projectiles.isEmpty else { return }
        let step = CGFloat(dt)
        let padding = combat.largestEnemyRadius

        var index = combat.projectiles.count - 1
        while index >= 0 {
            var projectile = combat.projectiles[index]
            projectile.remainingLife -= dt
            if projectile.returnsToThrower {
                if !projectile.isReturning {
                    projectile.turnsAfter -= dt
                    if projectile.turnsAfter <= 0 { Self.beginReturn(&projectile, combat: combat) }
                }
                if projectile.isReturning {
                    // Home on the thrower, wherever they have run to.
                    let toThrower = combat.world.delta(from: projectile.position, to: combat.playerPosition)
                    let speed = max(projectile.velocity.length, 0.01)
                    if toThrower.length > 0.0001 { projectile.velocity = toThrower.normalized * speed }
                }
            }
            projectile.position = combat.world.wrap(projectile.position + projectile.velocity * step)

            var spent = projectile.remainingLife <= 0
            if projectile.isReturning,
               combat.world.distance(projectile.position, combat.playerPosition) <= Self.catchRadius {
                // Caught: it is spent, and the hand is free for the next throw.
                spent = true
            } else if !spent, let struck = firstContact(of: projectile, padding: padding, combat: &combat) {
                spent = impact(&projectile, on: struck, combat: &combat)
                if spent, projectile.returnsToThrower, !projectile.isReturning, projectile.remainingLife > 0 {
                    // Through everything it could pass through going out:
                    // turn for home now rather than vanishing in the crowd.
                    Self.beginReturn(&projectile, combat: combat)
                    spent = false
                }
            }

            if spent {
                combat.projectiles.swapRemove(at: index)
            } else {
                combat.projectiles[index] = projectile
            }
            index -= 1
        }
    }

    /// How close to the thrower a returning boomerang must come to be caught.
    static let catchRadius: CGFloat = 0.5

    /// Turns a boomerang for home. On the way back it is a fresh throw:
    /// everything it clipped going out is fair game once more, and it may
    /// pass through as many as it could before. That second pass is part of
    /// its balance; within one leg no enemy is struck twice.
    private static func beginReturn(_ projectile: inout Projectile, combat: CombatState) {
        projectile.isReturning = true
        projectile.turnsAfter = 0
        projectile.struckEnemyIDs.removeAll(keepingCapacity: true)
        projectile.pierceRemaining = projectile.legPierce
        let toThrower = combat.world.delta(from: projectile.position, to: combat.playerPosition)
        if toThrower.length > 0.0001 {
            projectile.velocity = toThrower.normalized * max(projectile.velocity.length, 0.01)
        }
    }

    /// The shots enemies have loosed. They look for any living hero and any
    /// summon, and are spent on the first thing they reach. What they hit is
    /// reported as incidents for the party to carry out.
    func stepHostile(_ combat: inout CombatState, targets: [AITarget], dt: TimeInterval) {
        guard !combat.hostileProjectiles.isEmpty else { return }
        let step = CGFloat(dt)
        var index = combat.hostileProjectiles.count - 1
        while index >= 0 {
            var projectile = combat.hostileProjectiles[index]
            projectile.remainingLife -= dt
            projectile.position = combat.world.wrap(projectile.position + projectile.velocity * step)
            let spent = projectile.remainingLife <= 0 || impactOnPlayerSide(projectile, targets: targets, combat: &combat)
            if spent {
                combat.hostileProjectiles.swapRemove(at: index)
            } else {
                combat.hostileProjectiles[index] = projectile
            }
            index -= 1
        }
    }

    /// An enemy shot reaching a hero, or one of their summons. Returns
    /// whether it was spent.
    private func impactOnPlayerSide(_ projectile: Projectile, targets: [AITarget],
                                    combat: inout CombatState) -> Bool {
        for target in targets where target.isAlive {
            let toTarget = combat.world.delta(from: projectile.position, to: target.position)
            if toTarget.length <= projectile.radius + combat.tuning.playerRadius {
                combat.incidents.append(.strikeHero(hero: target.hero, amount: projectile.hit.amount,
                                                    direction: projectile.direction))
                combat.events.append(.burst(position: projectile.position, radius: 0.4, visual: projectile.visual))
                return true
            }
        }
        for anchor in combat.worldAnchors where anchor.isMortal {
            guard combat.world.distance(projectile.position, anchor.position)
                <= projectile.radius + anchor.radius else { continue }
            combat.incidents.append(.woundAlly(hero: anchor.hero, index: anchor.index, id: anchor.id,
                                               amount: projectile.hit.amount))
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
