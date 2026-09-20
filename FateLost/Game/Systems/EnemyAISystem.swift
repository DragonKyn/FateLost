import CoreGraphics
import Foundation

/// Moves enemies toward the player, keeps crowds from stacking, and resolves
/// their strikes.
///
/// Each enemy heads for its target by the shortest route across the wrapping
/// arena. Usually that's the player; a taunting ally nearby draws it instead,
/// a summon standing closer than the hero is mauled on the way past, a
/// confused enemy turns on its own kind, a terrified one flees, and a
/// stealthed player simply can't be found. Crowding is handled by separation:
/// overlapping enemies push apart. That push is the expensive part, so it is
/// recomputed for one group of enemies per tick (`separationGroups`) and
/// cached in between.
///
/// Every strike is telegraphed by a windup, and every behaviour has a
/// different answer:
/// - melee closes and swings; walk away from it;
/// - an exploder lights a fuse; let the kill go and step back;
/// - a shooter holds its distance and looses; close on it;
/// - a charger winds up in place and then hurls itself in a straight line;
///   side-step it and it is spent;
/// - a summoner hangs back calling more of its kind; kill it first.
struct EnemyAISystem {
    let tuning: EnemyAITuning
    let combatTuning: CombatTuning
    private var tick = 0

    /// How close to a taunting ally an enemy must be to be drawn to it.
    static let tauntRadius: CGFloat = 3.2
    /// How close a summon must be before an enemy bothers with it at all.
    static let allyAggroRadius: CGFloat = 2.4
    /// How much nearer than the hero a summon must be to be preferred. The
    /// horde wants the player; minions are what it walks through.
    static let allyPreferenceBias: CGFloat = 1.2
    /// A shooter holds this share of its range, and backs off below it.
    static let standoffShare: CGFloat = 0.65

    init(tuning: EnemyAITuning, combatTuning: CombatTuning) {
        self.tuning = tuning
        self.combatTuning = combatTuning
    }

    private enum Goal {
        case player
        case ally(AllyAnchor)
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

            // A charge in progress overrides everything else it might do.
            if combat.enemies.special[index] > 0, combat.enemies.dash[index] != .zero {
                advanceCharge(index, definition: definition, player: &player, combat: &combat,
                              godMode: godMode, dt: dt, incapacitated: incapacitated)
                continue
            }

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
            } else if let anchor = preferredAlly(near: position, player: player, hidden: hidden,
                                                 playerAlive: playerAlive, in: combat) {
                goal = .ally(anchor)
            } else if hidden || !playerAlive {
                goal = .wander
            } else {
                goal = .player
            }

            let targetPosition: CGPoint?
            switch goal {
            case .player: targetPosition = player.position
            case .ally(let anchor): targetPosition = anchor.position
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
            case .ally(let anchor): contactDistance = anchor.radius + definition.radius
            case .enemy(let other): contactDistance = combat.enemies.definition(at: other).radius + definition.radius
            default: contactDistance = 0.45 + definition.radius
            }

            // How far out it is willing to start a strike, and where it wants
            // to stand while doing so.
            let strikeRange = engagementRange(definition, contact: contactDistance)
            let standRange = standoffDistance(definition, contact: contactDistance)

            combat.enemies.attackCooldown[index] = max(0, combat.enemies.attackCooldown[index] - dt)
            if !incapacitated {
                if combat.enemies.windup[index] > 0 {
                    combat.enemies.windup[index] -= dt
                    if combat.enemies.windup[index] <= 0 {
                        combat.enemies.windup[index] = 0
                        combat.enemies.attackCooldown[index] = definition.attackCooldown
                        resolveStrike(index, definition: definition, goal: goal, distance: distance,
                                      landingReach: strikeRange * 1.2, toTarget: toTarget,
                                      player: &player, combat: &combat, godMode: godMode)
                    }
                } else if targetPosition != nil, combat.enemies.attackCooldown[index] <= 0,
                          distance <= strikeRange {
                    combat.enemies.windup[index] = definition.attackWindup
                    if case .charger = definition.behavior, toTarget.lengthSquared > 0.0001 {
                        // Commit to a line now. The telegraph shows it, and the
                        // player has the whole windup to be somewhere else.
                        combat.enemies.aim[index] = toTarget.normalized
                    }
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
            case .player, .ally, .enemy:
                let direction = distance > 0.0001 ? toTarget / distance : heading
                heading = direction
                if distance < standRange - 0.35 {
                    // Too close to shoot comfortably: give ground.
                    chase = direction * -speed * 0.8
                } else {
                    let gap = max(0, distance - standRange)
                    chase = direction * min(speed, gap / max(step, 0.0001))
                }
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

    // MARK: - Ranges

    /// How far out this kind will start a strike.
    private func engagementRange(_ definition: EnemyDefinition, contact: CGFloat) -> CGFloat {
        switch definition.behavior {
        case .melee, .exploder:
            return contact + definition.attackReach
        case .ranged(let range, _, _):
            return range
        case .charger(let range, _, _):
            return range
        case .summoner(_, _, _, let range):
            return range
        }
    }

    /// Where this kind wants to stand relative to its target.
    private func standoffDistance(_ definition: EnemyDefinition, contact: CGFloat) -> CGFloat {
        switch definition.behavior {
        case .melee, .exploder:
            return contact
        case .ranged(let range, _, _), .summoner(_, _, _, let range):
            return max(contact + 0.4, range * Self.standoffShare)
        case .charger:
            // A charger closes like anything else; the charge is the reach.
            return contact
        }
    }

    // MARK: - Targets

    /// The ally this enemy would rather fight than the player, if any.
    ///
    /// A taunting ally wins outright inside its radius. Otherwise a summon
    /// has to be both close and closer than the hero by a clear margin, so
    /// minions screen their master without making them untouchable. With the
    /// player hidden or fallen, anything within reach will do.
    private func preferredAlly(near position: CGPoint, player: PlayerState, hidden: Bool, playerAlive: Bool,
                               in combat: CombatState) -> AllyAnchor? {
        guard !combat.allyAnchors.isEmpty else { return nil }
        let unreachablePlayer = hidden || !playerAlive
        let toPlayer = unreachablePlayer
            ? CGFloat.greatestFiniteMagnitude
            : combat.world.distance(position, player.position)

        var best: AllyAnchor?
        var bestScore = CGFloat.greatestFiniteMagnitude
        for anchor in combat.allyAnchors {
            let distance = combat.world.distance(position, anchor.position)
            let reach = anchor.taunts ? Self.tauntRadius : Self.allyAggroRadius
            guard distance < reach else { continue }
            if !anchor.taunts {
                guard anchor.isMortal else { continue }
                guard distance + Self.allyPreferenceBias < toPlayer else { continue }
            }
            // Taunts come first, then whichever is nearest.
            let score = anchor.taunts ? distance - Self.tauntRadius : distance
            if score < bestScore {
                bestScore = score
                best = anchor
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
                               landingReach: CGFloat, toTarget: CGPoint, player: inout PlayerState,
                               combat: inout CombatState, godMode: Bool) {
        let weakened = 1 - combat.enemies.potency(.weaken, at: index)
        let damage = definition.attackDamage * combat.enemyDamageScale * combat.enemies.damageScale[index]
            * max(0, weakened)
        let direction = toTarget.lengthSquared > 0.0001 ? toTarget.normalized : combat.enemies.heading[index]
        // A blighted goblin's blows are poison, whatever its kind usually deals.
        let damageType = combat.enemies.strain(at: index).damageType ?? definition.damageType

        switch definition.behavior {
        case .exploder(let radius):
            explode(index, radius: radius, damage: damage, player: &player, combat: &combat, godMode: godMode)
            return
        case .ranged(_, let speed, let sprite):
            loose(index, definition: definition, damage: damage, type: damageType, direction: direction,
                  speed: speed, sprite: sprite, combat: &combat)
            return
        case .charger(_, let speed, let travel):
            let committed = combat.enemies.aim[index]
            combat.enemies.aim[index] = .zero
            beginCharge(index, direction: committed != .zero ? committed : direction, speed: speed,
                        distance: travel, combat: &combat)
            return
        case .summoner(let spawns, let count, let interval, _):
            call(index, spawns: spawns, count: count, interval: interval, combat: &combat)
            return
        case .melee:
            break
        }

        switch goal {
        case .player:
            guard distance <= landingReach, !player.isDefeated else { return }
            combat.strikePlayer(&player, amount: damage, direction: direction, godMode: godMode)
        case .ally(let anchor):
            guard distance <= landingReach else { return }
            wound(anchor, amount: damage, combat: &combat)
        case .enemy(let other):
            guard distance <= landingReach, other < combat.enemies.count else { return }
            // A confused enemy's blow lands on its own kind, and the kill is yours.
            let hit = Hit(amount: damage * 2.5, type: damageType, tags: [.melee], direction: direction,
                          knockback: 0.6, canCrit: false, depth: 1, source: .environment)
            combat.strike(other, with: hit)
        case .flee, .wander:
            break
        }
    }

    /// An enemy's blow landing on a summon, if that summon is still there.
    private func wound(_ anchor: AllyAnchor, amount: Double, combat: inout CombatState) {
        guard anchor.isMortal, anchor.index < combat.allies.count,
              combat.allies[anchor.index].id == anchor.id else { return }
        AllySystem.wound(anchor.index, amount: amount, &combat)
    }

    /// A shot on its way. Enemy projectiles fly through the same system as
    /// the player's, flagged so they look the other way for something to hit.
    private func loose(_ index: Int, definition: EnemyDefinition, damage: Double, type: DamageType,
                       direction: CGPoint, speed: CGFloat, sprite: SpriteID, combat: inout CombatState) {
        guard direction != .zero else { return }
        let origin = combat.enemies.positions[index]
        let range = engagementRange(definition, contact: definition.radius)
        var hit = Hit(amount: damage, type: type, tags: [.projectile], direction: direction,
                      knockback: 0.3, canCrit: false, depth: 1, source: .environment)
        hit.status = nil
        combat.projectiles.append(Projectile(
            id: combat.makeEntityID(),
            position: origin,
            velocity: direction * speed,
            remainingLife: Double(range / max(speed, 0.01)) * 1.4,
            pierceRemaining: 0,
            hit: hit,
            radius: 0.22,
            splashRadius: 0,
            spriteID: sprite,
            visual: VisualStyle.matching(type),
            isHostile: true
        ))
        combat.events.append(.projectileFired(spriteID: sprite, origin: origin, direction: direction))
    }

    /// Winds up, then throws itself along a straight line.
    private func beginCharge(_ index: Int, direction: CGPoint, speed: CGFloat, distance: CGFloat,
                             combat: inout CombatState) {
        guard direction != .zero else { return }
        combat.enemies.dash[index] = direction * speed
        combat.enemies.special[index] = Double(distance / max(speed, 0.01))
        combat.enemies.heading[index] = direction
    }

    /// Carries a charge forward, ending it on the first thing it hits.
    private func advanceCharge(_ index: Int, definition: EnemyDefinition, player: inout PlayerState,
                               combat: inout CombatState, godMode: Bool, dt: TimeInterval,
                               incapacitated: Bool) {
        guard !incapacitated else {
            // Knocked out of it mid-run.
            combat.enemies.dash[index] = .zero
            combat.enemies.special[index] = 0
            return
        }
        combat.enemies.special[index] -= dt
        let velocity = combat.enemies.dash[index]
        let moved = combat.world.wrap(combat.enemies.positions[index] + velocity * CGFloat(dt))
        combat.enemies.positions[index] = moved

        let damage = definition.attackDamage * combat.enemyDamageScale * combat.enemies.damageScale[index]
        let reach = definition.radius + definition.attackReach

        // Anything it runs through takes the full weight of it, once.
        let toPlayer = combat.world.delta(from: moved, to: player.position)
        if !player.isDefeated, toPlayer.length <= reach + combatTuning.playerRadius {
            combat.strikePlayer(&player, amount: damage, direction: toPlayer.normalized, godMode: godMode)
            combat.enemies.dash[index] = .zero
            combat.enemies.special[index] = 0
            return
        }
        let anchors = combat.allyAnchors
        for anchor in anchors where anchor.isMortal {
            guard combat.world.distance(moved, anchor.position) <= reach + anchor.radius else { continue }
            wound(anchor, amount: damage, combat: &combat)
            combat.enemies.dash[index] = .zero
            combat.enemies.special[index] = 0
            return
        }

        if combat.enemies.special[index] <= 0 {
            combat.enemies.dash[index] = .zero
            combat.enemies.special[index] = 0
        }
    }

    /// Calls more of its kind in around itself.
    private func call(_ index: Int, spawns: EnemyKindID, count: Int, interval: Double,
                      combat: inout CombatState) {
        guard let definition = EnemyCatalog.definition(for: spawns) else { return }
        let center = combat.enemies.positions[index]
        combat.enemies.attackCooldown[index] = max(combat.enemies.attackCooldown[index], interval)
        combat.events.append(.burst(position: center, radius: 1.4, visual: .shadow))
        let kind = combat.enemies.kindIndex(for: definition)
        for slot in 0..<count {
            let angle = CGFloat(2 * Double.pi * Double(slot) / Double(max(count, 1)) + combat.random.range(-0.4, 0.4))
            let offset = CGPoint(x: cos(angle), y: sin(angle)) * CGFloat(combat.random.range(1.2, 2.2))
            let position = combat.world.wrap(center + offset)
            let id = combat.makeEntityID()
            combat.enemies.append(id: id, kind: kind, position: position, speedScale: 1,
                                  healthScale: combat.enemyHealthScale)
            combat.events.append(.summoned(position: position, visual: .shadow))
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
            combat.strikePlayer(&player, amount: damage, direction: toPlayer.normalized, godMode: godMode)
        }

        // The blast takes summons with it, the same as any other bystander.
        let anchors = combat.allyAnchors
        for anchor in anchors where anchor.isMortal {
            guard combat.world.distance(center, anchor.position) <= radius + anchor.radius else { continue }
            wound(anchor, amount: damage, combat: &combat)
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
