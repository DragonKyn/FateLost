import CoreGraphics
import Foundation

/// Moves enemies toward the player, keeps crowds from stacking, and resolves
/// their strikes.
///
/// Each enemy heads straight for the player by the shortest route across
/// the wrapping arena. Crowding is handled by separation: overlapping
/// enemies push apart. That push is the expensive part, so it is recomputed
/// for one group of enemies per tick (`separationGroups`) and cached in
/// between, which spreads the cost across frames and is invisible at 60 Hz.
///
/// Strikes are telegraphed: an enemy in reach starts a windup, slows down,
/// and only lands the blow if the player is still in reach when it ends.
struct EnemyAISystem {
    let tuning: EnemyAITuning
    let combatTuning: CombatTuning
    private var tick = 0

    init(tuning: EnemyAITuning, combatTuning: CombatTuning) {
        self.tuning = tuning
        self.combatTuning = combatTuning
    }

    mutating func step(_ combat: inout CombatState, player: inout PlayerState, godMode: Bool, dt: TimeInterval) {
        tick &+= 1
        let enemies = combat.enemies.count
        guard enemies > 0 else { return }

        let groups = max(1, tuning.separationGroups)
        let group = tick % groups
        let padding = combat.largestEnemyRadius
        for index in stride(from: group, to: enemies, by: groups) {
            updateSeparation(of: index, in: &combat, padding: padding)
        }

        let step = CGFloat(dt)
        let decay = CGFloat(exp(-Double(combatTuning.knockbackDecay * step)))
        let playerAlive = !player.isDefeated

        for index in 0..<enemies {
            let definition = combat.enemies.definition(at: index)
            let position = combat.enemies.positions[index]
            let toPlayer = combat.world.delta(from: position, to: player.position)
            let distance = toPlayer.length
            let direction = distance > 0.0001 ? toPlayer / distance : combat.enemies.heading[index]
            let contactDistance = combatTuning.playerRadius + definition.radius

            // Strikes: cool down, start a windup when in reach, land it if
            // the player is still there when it finishes.
            combat.enemies.attackCooldown[index] = max(0, combat.enemies.attackCooldown[index] - dt)
            if combat.enemies.windup[index] > 0 {
                combat.enemies.windup[index] -= dt
                if combat.enemies.windup[index] <= 0 {
                    combat.enemies.windup[index] = 0
                    combat.enemies.attackCooldown[index] = definition.attackCooldown
                    // A little grace beyond the reach that started the strike.
                    let landingReach = contactDistance + definition.attackReach * 1.35
                    if playerAlive, distance <= landingReach {
                        strikePlayer(&player, from: definition, direction: direction, combat: &combat,
                                     godMode: godMode)
                    }
                }
            } else if playerAlive, combat.enemies.attackCooldown[index] <= 0,
                      distance <= contactDistance + definition.attackReach {
                combat.enemies.windup[index] = definition.attackWindup
                combat.events.append(.enemyWindup(enemyID: combat.enemies.ids[index]))
            }

            // Movement: chase, slowed while striking, stopping at contact.
            var speed = definition.moveSpeed * combat.enemies.speedScale[index]
            if combat.enemies.windup[index] > 0 {
                speed *= tuning.windupSpeedFactor
            }
            let gap = max(0, distance - contactDistance)
            let chase = direction * min(speed, gap / max(step, 0.0001))
            let push = combat.enemies.separation[index] * tuning.separationStrength
            let knock = combat.enemies.knockback[index]
            var moved = position + (chase + push + knock) * step

            // Never overlap the player's body.
            let after = combat.world.delta(from: moved, to: player.position)
            let afterDistance = after.length
            if afterDistance < contactDistance, afterDistance > 0.0001 {
                moved = moved - after / afterDistance * (contactDistance - afterDistance)
            }

            combat.enemies.positions[index] = combat.world.wrap(moved)
            combat.enemies.knockback[index] = knock * decay
            if chase.lengthSquared > 0.0001 {
                combat.enemies.heading[index] = direction
            }
        }
    }

    /// Sums the overlap with nearby enemies into a push away from them.
    private func updateSeparation(of index: Int, in combat: inout CombatState, padding: CGFloat) {
        let position = combat.enemies.positions[index]
        let radius = combat.enemies.definition(at: index).radius
        combat.nearby.removeAll(keepingCapacity: true)
        combat.grid.query(around: position, radius: radius + padding, into: &combat.nearby)

        var push = CGPoint.zero
        var neighbours = 0
        for other in combat.nearby where other != index && other < combat.enemies.count {
            let away = combat.world.delta(from: combat.enemies.positions[other], to: position)
            let minimum = radius + combat.enemies.definition(at: other).radius
            let distanceSquared = away.lengthSquared
            guard distanceSquared < minimum * minimum else { continue }
            let distance = distanceSquared.squareRoot()
            let overlap = minimum - distance
            // Exactly coincident enemies separate along an id-based axis so
            // they don't stay stacked forever.
            let axis = distance > 0.0001
                ? away / distance
                : CGPoint(x: cos(CGFloat(combat.enemies.ids[index])), y: sin(CGFloat(combat.enemies.ids[index])))
            push += axis * overlap
            neighbours += 1
            // Bounded work in extreme crowds.
            if neighbours >= 12 { break }
        }
        combat.enemies.separation[index] = push.clampedLength(maximum: radius * 2)
    }

    private func strikePlayer(_ player: inout PlayerState, from definition: EnemyDefinition, direction: CGPoint,
                              combat: inout CombatState, godMode: Bool) {
        guard !player.isInvulnerable else { return }
        let amount = godMode ? 0 : min(definition.attackDamage, player.health)
        player.health -= amount
        player.invulnerability = combatTuning.invulnerabilityDuration
        player.timeSinceHit = 0
        // `direction` points at the player, so the shove carries on the same way.
        player.knockback = player.knockback + direction * combatTuning.playerKnockbackSpeed
        combat.stats.damageTaken += amount
        combat.events.append(.playerHit(amount: definition.attackDamage, direction: direction))
        if player.isDefeated {
            combat.events.append(.playerDefeated)
        }
    }
}
