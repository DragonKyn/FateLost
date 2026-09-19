import CoreGraphics
import Foundation

/// Moves enemies toward the player, keeps crowds from stacking, and resolves
/// their strikes.
///
/// Each enemy heads straight for its target by the shortest route across
/// the wrapping arena. Usually that's the player; a taunting ally nearby
/// draws it instead, a confused enemy turns on its own kind, a terrified one
/// flees, and a stealthed player simply can't be found. Crowding is handled
/// by separation: overlapping enemies push apart. That push is the expensive
/// part, so it is recomputed for one group of enemies per tick
/// (`separationGroups`) and cached in between.
///
/// Strikes are telegraphed: an enemy in reach starts a windup, slows down,
/// and only lands the blow if its target is still in reach when it ends.
struct EnemyAISystem {
    let tuning: EnemyAITuning
    let combatTuning: CombatTuning
    private var tick = 0

    /// How close to a taunting ally an enemy must be to be drawn to it.
    static let tauntRadius: CGFloat = 3.2

    init(tuning: EnemyAITuning, combatTuning: CombatTuning) {
        self.tuning = tuning
        self.combatTuning = combatTuning
    }

    private enum Goal {
        case player
        case point(CGPoint)
        case enemy(Int)
        case flee
        case wander
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
        let hidden = player.isStealthed

        for index in 0..<enemies {
            let definition = combat.enemies.definition(at: index)
            let position = combat.enemies.positions[index]
            let mask = combat.enemies.statusMask[index]
            let incapacitated = mask & StatusKind.incapacitating != 0
            let rooted = mask & StatusKind.root.bit != 0

            // Decide what this enemy is after.
            let goal: Goal
            if mask & StatusKind.fear.bit != 0 {
                goal = .flee
            } else if mask & StatusKind.confuse.bit != 0 {
                if let other = nearestOtherEnemy(to: index, in: &combat) {
                    goal = .enemy(other)
                } else {
                    goal = .wander
                }
            } else if hidden || !playerAlive {
                goal = .wander
            } else if let taunt = nearestTaunt(to: position, in: combat) {
                goal = .point(taunt)
            } else {
                goal = .player
            }

            let targetPosition: CGPoint?
            switch goal {
            case .player: targetPosition = player.position
            case .point(let point): targetPosition = point
            case .enemy(let other): targetPosition = combat.enemies.positions[other]
            case .flee, .wander: targetPosition = nil
            }

            var toTarget = CGPoint.zero
            if let targetPosition {
                toTarget = combat.world.delta(from: position, to: targetPosition)
            }
            let distance = toTarget.length
            let contactDistance: CGFloat
            switch goal {
            case .player: contactDistance = combatTuning.playerRadius + definition.radius
            case .enemy(let other): contactDistance = combat.enemies.definition(at: other).radius + definition.radius
            default: contactDistance = 0.45 + definition.radius
            }

            // Strikes: cool down, start a windup when in reach, land it if
            // the target is still there when it finishes.
            combat.enemies.attackCooldown[index] = max(0, combat.enemies.attackCooldown[index] - dt)
            if !incapacitated {
                if combat.enemies.windup[index] > 0 {
                    combat.enemies.windup[index] -= dt
                    if combat.enemies.windup[index] <= 0 {
                        combat.enemies.windup[index] = 0
                        combat.enemies.attackCooldown[index] = definition.attackCooldown
                        let landingReach = contactDistance + definition.attackReach * 1.35
                        resolveStrike(index, definition: definition, goal: goal, distance: distance,
                                      landingReach: landingReach, player: &player, combat: &combat, godMode: godMode)
                    }
                } else if targetPosition != nil, combat.enemies.attackCooldown[index] <= 0,
                          distance <= contactDistance + definition.attackReach {
                    combat.enemies.windup[index] = definition.attackWindup
                    combat.events.append(.enemyWindup(enemyID: combat.enemies.ids[index]))
                }
            }

            // Movement.
            var speed = definition.moveSpeed * combat.enemies.speedScale[index]
            speed *= CGFloat(1 - combat.enemies.potency(.chill, at: index))
            if combat.enemies.windup[index] > 0 {
                speed *= tuning.windupSpeedFactor
            }
            if incapacitated || rooted {
                speed = 0
            }

            var chase = CGPoint.zero
            var heading = combat.enemies.heading[index]
            switch goal {
            case .player, .point, .enemy:
                let direction = distance > 0.0001 ? toTarget / distance : heading
                let gap = max(0, distance - contactDistance)
                chase = direction * min(speed, gap / max(step, 0.0001))
                heading = direction
            case .flee:
                let away = combat.world.delta(from: player.position, to: position).normalized
                chase = away * speed * 0.9
                heading = away
            case .wander:
                // Mill about, slowly, in whatever direction it last faced.
                chase = heading * speed * 0.3
            }

            let push = combat.enemies.separation[index] * tuning.separationStrength
            let knock = combat.enemies.knockback[index]
            var moved = position + (chase + push + knock) * step

            // Never overlap the player's body.
            let after = combat.world.delta(from: moved, to: player.position)
            let afterDistance = after.length
            let playerContact = combatTuning.playerRadius + definition.radius
            if afterDistance < playerContact, afterDistance > 0.0001 {
                moved = moved - after / afterDistance * (playerContact - afterDistance)
            }

            combat.enemies.positions[index] = combat.world.wrap(moved)
            combat.enemies.knockback[index] = knock * decay
            if chase.lengthSquared > 0.0001 {
                combat.enemies.heading[index] = heading
            }
        }
    }

    // MARK: - Targets

    private func nearestTaunt(to position: CGPoint, in combat: CombatState) -> CGPoint? {
        guard !combat.tauntPoints.isEmpty else { return nil }
        var best: CGPoint?
        var bestDistance = Self.tauntRadius
        for point in combat.tauntPoints {
            let distance = combat.world.distance(position, point)
            if distance < bestDistance {
                bestDistance = distance
                best = point
            }
        }
        return best
    }

    private func nearestOtherEnemy(to index: Int, in combat: inout CombatState) -> Int? {
        let position = combat.enemies.positions[index]
        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: position, radius: 3, into: &combat.nearbySecondary)
        var best: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for other in combat.nearbySecondary where other != index && other < combat.enemies.count {
            guard combat.enemies.health[other] > 0 else { continue }
            let distance = combat.world.distanceSquared(position, combat.enemies.positions[other])
            if distance < bestDistance {
                bestDistance = distance
                best = other
            }
        }
        return best
    }

    // MARK: - Strikes

    private func resolveStrike(_ index: Int, definition: EnemyDefinition, goal: Goal, distance: CGFloat,
                               landingReach: CGFloat, player: inout PlayerState, combat: inout CombatState,
                               godMode: Bool) {
        let weakened = 1 - combat.enemies.potency(.weaken, at: index)
        let damage = definition.attackDamage * combat.enemyDamageScale * max(0, weakened)

        if case .exploder(let radius) = definition.behavior {
            explode(index, radius: radius, damage: damage, player: &player, combat: &combat, godMode: godMode)
            return
        }

        switch goal {
        case .player:
            guard distance <= landingReach, !player.isDefeated else { return }
            let direction = combat.world.delta(from: combat.enemies.positions[index], to: player.position).normalized
            strikePlayer(&player, amount: damage, direction: direction, combat: &combat, godMode: godMode)
        case .enemy(let other):
            guard distance <= landingReach, other < combat.enemies.count else { return }
            // A confused enemy's blow lands on its own kind, and the kill is yours.
            let direction = combat.world.delta(from: combat.enemies.positions[index],
                                               to: combat.enemies.positions[other]).normalized
            let hit = Hit(amount: damage * 2.5, type: definition.damageType, tags: [.melee], direction: direction,
                          knockback: 0.6, canCrit: false, depth: 1, source: .environment)
            combat.strike(other, with: hit)
        case .point, .flee, .wander:
            // Allies can't be hurt yet; the blow glances off.
            break
        }
    }

    /// A sapper's keg going off: hurts everything nearby, including goblins,
    /// and takes the sapper with it.
    private func explode(_ index: Int, radius: CGFloat, damage: Double, player: inout PlayerState,
                         combat: inout CombatState, godMode: Bool) {
        let center = combat.enemies.positions[index]
        combat.events.append(.enemyExploded(position: center, radius: radius))
        combat.enemies.health[index] = 0

        let toPlayer = combat.world.delta(from: center, to: player.position)
        if !player.isDefeated, toPlayer.length <= radius + combatTuning.playerRadius {
            strikePlayer(&player, amount: damage, direction: toPlayer.normalized, combat: &combat, godMode: godMode)
        }

        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: center, radius: radius + combat.largestEnemyRadius, into: &combat.nearbySecondary)
        let candidates = combat.nearbySecondary
        for other in candidates where other != index && other < combat.enemies.count {
            let offset = combat.world.delta(from: center, to: combat.enemies.positions[other])
            let distance = offset.length
            guard distance <= radius + combat.enemies.definition(at: other).radius else { continue }
            let hit = Hit(amount: damage * 1.5, type: .fire, tags: [.area],
                          direction: distance > 0.0001 ? offset / distance : CGPoint(x: 1, y: 0),
                          knockback: 1.2, canCrit: false, depth: 1, source: .environment)
            combat.strike(other, with: hit)
        }
    }

    /// Everything between an enemy's blow and the player's health: immunity,
    /// dodging, armour, barriers, a refused death, and the triggers that
    /// answer being struck.
    private func strikePlayer(_ player: inout PlayerState, amount rawAmount: Double, direction: CGPoint,
                              combat: inout CombatState, godMode: Bool) {
        guard !player.isInvulnerable else { return }
        if combat.random.chance(combat.sheet[.dodgeChance]) {
            player.timeSinceDodge = 0
            combat.stats.dodges += 1
            combat.events.append(.playerDodged)
            combat.fireProcs(combat.build.dodgeProcs, origin: player.position)
            return
        }

        let armor = max(0, combat.sheet[.armor])
        let reduction = min(0.8, armor / (armor + 75))
        var amount = godMode ? 0 : rawAmount * (1 - reduction)

        if player.barrier > 0 {
            let absorbed = min(player.barrier, amount)
            player.barrier -= absorbed
            amount -= absorbed
        }

        if amount >= player.health, let refusal = combat.build.cheatDeath, combat.cheatDeathCooldown <= 0 {
            combat.cheatDeathCooldown = refusal.cooldown
            player.health = max(1, player.maxHealth * refusal.restore)
            player.invulnerability = refusal.invulnerability
            combat.events.append(.cheatedDeath)
            if let action = refusal.action {
                combat.pendingActions.append(QueuedAction(action: action, origin: player.position, targetID: nil,
                                                          direction: direction, depth: 1, ability: nil))
            }
            return
        }

        let dealt = min(amount, player.health)
        player.health -= dealt
        player.invulnerability = combatTuning.invulnerabilityDuration
        player.timeSinceHit = 0
        // `direction` points at the player, so the shove carries on the same way.
        player.knockback = player.knockback + direction * combatTuning.playerKnockbackSpeed
        combat.stats.damageTaken += dealt
        combat.events.append(.playerHit(amount: rawAmount, direction: direction))
        combat.conditions.healthFraction = player.healthFraction
        combat.fireProcs(combat.build.hurtProcs, origin: player.position)
        if player.isDefeated {
            combat.events.append(.playerDefeated)
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
}
