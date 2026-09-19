import CoreGraphics
import Foundation

/// Moves and fights with the player's allies: summoned minions, permanent
/// companions and orbiting blades.
///
/// Anything with a body can be cut down: an ally with `vitality` carries
/// health, is struck by the same blows the player would take, and leaves a
/// corpse behind. A fallen companion stays gone for its `resummonCooldown`
/// before the build calls it back, so losing one costs something. Conjured
/// blades and orbs have no body and simply expire. A taunting ally draws
/// nearby enemies to itself instead of the player.
enum AllySystem {
    /// Ceiling on temporary allies, so summon-heavy builds stay affordable.
    static let maximumTemporary = 48
    /// How far allies roam from the player before coming back.
    static let leash: CGFloat = 7

    static func spawn(_ spec: SummonSpec, around center: CGPoint, duration: Double, companionKey: String?,
                      slot: Int, of total: Int, _ combat: inout CombatState) {
        let angle = CGFloat(2 * Double.pi * Double(slot) / Double(max(total, 1)) + combat.random.range(-0.3, 0.3))
        let offset: CGFloat
        if case .orbit(let radius, _) = spec.behavior {
            offset = radius
        } else {
            offset = 1.1
        }
        let position = combat.world.wrap(center + CGPoint(x: cos(angle), y: sin(angle)) * offset)
        let life = SummonVitality.maxHealth(of: spec, level: combat.summonVitalityLevel,
                                            perLevel: combat.summonVitalityGrowth)
        combat.allies.append(Ally(id: combat.makeEntityID(), spec: spec, position: position, remaining: duration,
                                  cooldown: combat.random.range(0, spec.attackInterval), angle: angle,
                                  companionKey: companionKey, restAngle: angle, health: life, maxHealth: life))
    }

    /// An enemy's blow landing on an ally. Returns true if it was slain.
    @discardableResult
    static func wound(_ index: Int, amount: Double, _ combat: inout CombatState) -> Bool {
        guard index < combat.allies.count, combat.allies[index].isMortal else { return false }
        combat.allies[index].health -= max(0, amount)
        combat.allies[index].timeSinceHurt = 0
        guard combat.allies[index].isSlain else { return false }
        fall(index, &combat)
        return true
    }

    /// Removes a slain ally and starts the wait before its kind returns.
    private static func fall(_ index: Int, _ combat: inout CombatState) {
        let ally = combat.allies[index]
        combat.events.append(.allyFell(position: ally.position, visual: ally.spec.visual))
        combat.stats.summonsLost += 1
        if let key = ally.companionKey {
            combat.summonCooldowns[key] = ally.spec.resummonCooldown
        }
        combat.allies.swapRemove(at: index)
    }

    /// Sends every ally away. Companions stay gone until recalled, so
    /// dismissing them is a real choice rather than a blink.
    static func dismissAll(_ combat: inout CombatState) {
        combat.companionsDismissed = true
        combat.allies.removeAll(keepingCapacity: true)
        combat.allyAnchors.removeAll(keepingCapacity: true)
    }

    /// Counts down the wait on each fallen companion kind.
    static func tickCooldowns(_ combat: inout CombatState, dt: TimeInterval) {
        guard !combat.summonCooldowns.isEmpty else { return }
        for (key, remaining) in combat.summonCooldowns {
            let left = remaining - dt
            if left <= 0 {
                combat.summonCooldowns.removeValue(forKey: key)
            } else {
                combat.summonCooldowns[key] = left
            }
        }
    }

    /// Drops the oldest temporary allies beyond the ceiling.
    static func trimTemporaryAllies(_ combat: inout CombatState) {
        var temporary = combat.allies.filter { $0.companionKey == nil }.count
        guard temporary > maximumTemporary else { return }
        var index = 0
        while temporary > maximumTemporary, index < combat.allies.count {
            if combat.allies[index].companionKey == nil {
                combat.allies.remove(at: index)
                temporary -= 1
            } else {
                index += 1
            }
        }
    }

    /// Keeps the build's companions alive at the right number, replacing
    /// any whose skill has since ranked up.
    static func syncCompanions(_ combat: inout CombatState, player: PlayerState) {
        guard !combat.companionsDismissed else {
            combat.allies.removeAll { $0.companionKey != nil }
            return
        }
        let rules = combat.build.companions
        let extra = Int(combat.sheet[.summonCount])
        var counts: [String: Int] = [:]
        combat.allies.removeAll { ally in
            guard let key = ally.companionKey else { return false }
            guard let rule = rules.first(where: { $0.key == key }), rule.spec == ally.spec else { return true }
            let have = counts[key, default: 0]
            if have >= rule.count + extra { return true }
            counts[key] = have + 1
            return false
        }
        for rule in rules {
            let want = rule.count + extra
            let have = counts[rule.key, default: 0]
            guard want > have else { continue }
            // A companion cut down does not walk back out of the dark at once.
            guard combat.summonCooldowns[rule.key] == nil else { continue }
            for slot in have..<want {
                spawn(rule.spec, around: player.position, duration: .infinity, companionKey: rule.key, slot: slot,
                      of: want, &combat)
            }
        }
    }

    static func step(_ combat: inout CombatState, player: PlayerState, dt: TimeInterval) {
        combat.allyAnchors.removeAll(keepingCapacity: true)
        guard !combat.allies.isEmpty else { return }

        var index = combat.allies.count - 1
        while index >= 0 {
            var ally = combat.allies[index]
            ally.remaining -= dt
            if ally.remaining <= 0 {
                combat.allies.swapRemove(at: index)
                index -= 1
                continue
            }
            if ally.isSlain {
                fall(index, &combat)
                index -= 1
                continue
            }
            ally.timeSinceHurt += dt
            ally.cooldown -= dt
            ally.timeSinceAttack += dt

            switch ally.spec.behavior {
            case let .orbit(radius, angularSpeed):
                orbit(&ally, radius: radius, angularSpeed: angularSpeed, player: player, dt: dt, &combat)
            case .melee(let range):
                melee(&ally, range: range, player: player, dt: dt, &combat)
            case let .ranged(range, projectileSpeed, sprite):
                ranged(&ally, range: range, projectileSpeed: projectileSpeed, sprite: sprite, player: player, dt: dt,
                       &combat)
            }
            if ally.spec.taunts || ally.isMortal {
                combat.allyAnchors.append(AllyAnchor(index: index, id: ally.id, position: ally.position,
                                                     radius: ally.spec.radius, taunts: ally.spec.taunts,
                                                     isMortal: ally.isMortal))
            }
            combat.allies[index] = ally
            index -= 1
        }
    }

    // MARK: - Behaviours

    private static func orbit(_ ally: inout Ally, radius: CGFloat, angularSpeed: CGFloat, player: PlayerState,
                              dt: TimeInterval, _ combat: inout CombatState) {
        ally.angle += angularSpeed * CGFloat(dt)
        let offset = CGPoint(x: cos(ally.angle), y: sin(ally.angle)) * radius
        ally.position = combat.world.wrap(player.position + offset)
        ally.heading = CGPoint(x: -sin(ally.angle), y: cos(ally.angle))
        guard ally.cooldown <= 0 else { return }

        combat.nearbySecondary.removeAll(keepingCapacity: true)
        combat.grid.query(around: ally.position, radius: ally.spec.radius + combat.largestEnemyRadius,
                          into: &combat.nearbySecondary)
        let candidates = combat.nearbySecondary
        var struck = false
        for index in candidates where index < combat.enemies.count && combat.enemies.health[index] > 0 {
            let reach = ally.spec.radius + combat.enemies.definition(at: index).radius
            guard combat.world.distance(ally.position, combat.enemies.positions[index]) <= reach else { continue }
            var hit = combat.hit(from: ally.spec.damage, direction: offset.normalized, depth: 1, source: .summon)
            hit.status = ally.spec.status
            combat.strike(index, with: hit)
            struck = true
        }
        if struck {
            ally.cooldown = ally.spec.attackInterval
            ally.timeSinceAttack = 0
        }
    }

    private static func melee(_ ally: inout Ally, range: CGFloat, player: PlayerState, dt: TimeInterval,
                              _ combat: inout CombatState) {
        let step = CGFloat(dt)
        let fromPlayer = combat.world.distance(player.position, ally.position)
        let target = fromPlayer < leash
            ? Targeting.nearest(to: ally.position, within: 6, padding: combat.largestEnemyRadius, combat: &combat)
            : nil

        guard let target else {
            returnToPlayer(&ally, player: player, dt: dt, &combat)
            return
        }
        let enemyPosition = combat.enemies.positions[target]
        let toEnemy = combat.world.delta(from: ally.position, to: enemyPosition)
        let distance = toEnemy.length
        let direction = distance > 0.0001 ? toEnemy / distance : ally.heading
        let reach = range + ally.spec.radius + combat.enemies.definition(at: target).radius
        ally.heading = direction

        if distance > reach {
            let travel = min(ally.spec.moveSpeed * step, distance - reach * 0.9)
            ally.position = combat.world.wrap(ally.position + direction * travel)
        } else if ally.cooldown <= 0 {
            ally.cooldown = ally.spec.attackInterval
            ally.timeSinceAttack = 0
            if ally.spec.splash > 0 {
                ActionExecutor.affect(around: enemyPosition, radius: ally.spec.splash, damage: ally.spec.damage,
                                      status: ally.spec.status, depth: 1, source: .summon, &combat)
                combat.events.append(.burst(position: enemyPosition, radius: ally.spec.splash, visual: ally.spec.visual))
            } else {
                var hit = combat.hit(from: ally.spec.damage, direction: direction, depth: 1, source: .summon)
                hit.status = ally.spec.status
                combat.strike(target, with: hit)
            }
        }
    }

    private static func ranged(_ ally: inout Ally, range: CGFloat, projectileSpeed: CGFloat, sprite: SpriteID,
                               player: PlayerState, dt: TimeInterval, _ combat: inout CombatState) {
        returnToPlayer(&ally, player: player, dt: dt, &combat)
        guard ally.cooldown <= 0,
              let target = Targeting.nearest(to: ally.position, within: range, padding: combat.largestEnemyRadius,
                                             combat: &combat) else { return }
        let direction = combat.world.delta(from: ally.position, to: combat.enemies.positions[target]).normalized
        guard direction != .zero else { return }
        ally.cooldown = ally.spec.attackInterval
        ally.timeSinceAttack = 0
        ally.heading = direction

        var hit = combat.hit(from: ally.spec.damage, direction: direction, depth: 1, source: .summon)
        hit.status = ally.spec.status
        combat.projectiles.append(Projectile(
            id: combat.makeEntityID(),
            position: ally.position,
            velocity: direction * projectileSpeed,
            remainingLife: Double(range / max(projectileSpeed, 0.01)) * 1.2,
            pierceRemaining: 0,
            hit: hit,
            radius: 0.18,
            splashRadius: ally.spec.splash,
            spriteID: sprite,
            visual: ally.spec.visual
        ))
    }

    /// Drifts back to the ally's resting place beside the player.
    private static func returnToPlayer(_ ally: inout Ally, player: PlayerState, dt: TimeInterval,
                                       _ combat: inout CombatState) {
        let rest = player.position + CGPoint(x: cos(ally.restAngle), y: sin(ally.restAngle)) * 1.3
        let offset = combat.world.delta(from: ally.position, to: rest)
        let distance = offset.length
        guard distance > 0.15 else { return }
        // Hurry when left behind.
        let speed = ally.spec.moveSpeed * (distance > 4 ? 2.2 : 1)
        let travel = min(speed * CGFloat(dt), distance)
        ally.heading = offset / distance
        ally.position = combat.world.wrap(ally.position + offset / distance * travel)
    }
}
