import CoreGraphics
import Foundation

/// Fires the player's weapon automatically.
///
/// The weapon waits until it is ready and a valid target exists, then
/// attacks: a melee weapon sweeps an arc toward its target, hitting every
/// enemy inside; a ranged weapon launches projectiles for `ProjectileSystem`
/// to fly. If nothing is in reach the weapon stays ready, so the attack comes
/// out the instant an enemy steps in rather than on an arbitrary beat.
///
/// A shapeshifted form swaps in its own weapon. Skills change the attack
/// through `WeaponModifierSet` and the player's stats, never by editing the
/// weapon definition.
struct WeaponSystem {
    let weapon: WeaponDefinition
    let tuning: CombatTuning
    /// Level growth per level; see `ProgressionTuning`.
    let growthPerLevel: Double
    /// Seconds until the weapon may attack again.
    private(set) var cooldown: Double = 0

    init(weapon: WeaponDefinition, tuning: CombatTuning, growthPerLevel: Double = 0.07) {
        self.weapon = weapon
        self.tuning = tuning
        self.growthPerLevel = growthPerLevel
    }

    /// Seconds between attacks with the player's current stats.
    func attackInterval(for weapon: WeaponDefinition, attackSpeed: Double) -> Double {
        1 / max(weapon.attackSpeed * attackSpeed, 0.05)
    }

    mutating func step(_ combat: inout CombatState, player: inout PlayerState, form: FormDefinition?,
                       dt: TimeInterval) {
        cooldown = max(0, cooldown - dt)
        guard cooldown <= 0, !player.isDefeated, !combat.enemies.isEmpty else { return }

        let active = form?.weapon ?? weapon
        let interval = attackInterval(for: active, attackSpeed: combat.sheet[.attackSpeed])
        let target: Int?
        switch active.delivery {
        case .meleeArc(let arcDegrees):
            target = swing(active, arcDegrees: arcDegrees, combat: &combat, player: &player)
        case .projectile(let profile):
            target = fire(active, profile, combat: &combat, player: &player)
        }
        guard let target else { return }

        cooldown = interval
        let modifiers = combat.build.weapon
        var multistrike = modifiers.multistrike
        if case .meleeArc = active.delivery {
            // Extra projectiles become extra strikes for melee weapons.
            multistrike += 0.15 * Double(modifiers.extraProjectiles)
        }
        if multistrike > 0, combat.random.chance(min(multistrike, 0.9)) {
            cooldown = min(cooldown, 0.1)
        }

        combat.attackCount += 1
        let position = combat.enemies.positions[target]
        let direction = player.facing
        for procIndex in combat.build.attackProcs {
            switch combat.build.procs[procIndex].trigger {
            case .attack:
                combat.fireProc(procIndex, origin: position, targetIndex: target, depth: 0, direction: direction)
            case .everyNthAttack(let n) where n > 0 && combat.attackCount % n == 0:
                combat.fireProc(procIndex, origin: position, targetIndex: target, depth: 0, direction: direction)
            default:
                break
            }
        }
    }

    private func baseHit(_ weapon: WeaponDefinition, combat: CombatState) -> Hit {
        let growth = SkillPower.growth(level: combat.level, perLevel: growthPerLevel)
        var tags = TagMask(weapon.tags)
        tags.insert(.weapon)
        var hit = Hit(amount: weapon.baseDamage * growth, type: weapon.damageType, tags: tags, knockback: 1,
                      depth: 0, source: .weapon)
        hit.added = combat.build.weapon.added
        return hit
    }

    // MARK: - Melee

    private func swing(_ weapon: WeaponDefinition, arcDegrees baseArc: Double, combat: inout CombatState,
                       player: inout PlayerState) -> Int? {
        let modifiers = combat.build.weapon
        let range = CGFloat(weapon.range * (1 + modifiers.reach)) * CGFloat(combat.sheet[.areaSize]).squareRoot()
        let arcDegrees = min(360, baseArc + modifiers.cleaveDegrees)
        let padding = combat.largestEnemyRadius
        guard let target = Targeting.nearest(to: player.position, within: range + tuning.meleeAcquireSlack,
                                             padding: padding, combat: &combat) else {
            return nil
        }
        let aim = combat.world.delta(from: player.position, to: combat.enemies.positions[target]).normalized
        let direction = aim == .zero ? player.facing : aim
        player.facing = direction

        let halfArcCosine = CGFloat(cos(arcDegrees * .pi / 360))
        // The swing reaches as far as the target it was aimed at.
        let sweep = range + tuning.meleeAcquireSlack
        let template = baseHit(weapon, combat: combat)
        combat.nearby.removeAll(keepingCapacity: true)
        combat.grid.query(around: player.position, radius: sweep + padding, into: &combat.nearby)
        let candidates = combat.nearby
        for index in candidates where index < combat.enemies.count {
            let offset = combat.world.delta(from: player.position, to: combat.enemies.positions[index])
            let distance = offset.length
            let reach = sweep + combat.enemies.definition(at: index).radius
            guard distance <= reach else { continue }
            let inArc = distance <= tuning.meleePointBlank
                || (distance > 0.0001 && (offset / distance).dot(direction) >= halfArcCosine)
            guard inArc else { continue }
            var hit = template
            hit.direction = distance > 0.0001 ? offset / distance : direction
            combat.strike(index, with: hit)
        }

        combat.events.append(.meleeSwing(origin: player.position, direction: direction, range: range,
                                         arcDegrees: arcDegrees))
        return target
    }

    // MARK: - Projectiles

    private func fire(_ weapon: WeaponDefinition, _ profile: ProjectileProfile, combat: inout CombatState,
                      player: inout PlayerState) -> Int? {
        let modifiers = combat.build.weapon
        let range = CGFloat(weapon.range * (1 + modifiers.reach))
        let padding = combat.largestEnemyRadius
        // Cleave gives projectiles a small burst on impact instead.
        let splash = CGFloat(profile.splashRadius + modifiers.cleaveDegrees / 120) * CGFloat(combat.sheet[.areaSize])
        let target: Int?
        switch weapon.targeting {
        case .densestCluster:
            target = Targeting.densestCluster(around: player.position, within: range,
                                              clusterRadius: max(splash, 1), padding: padding, combat: &combat)
        case .nearest, .nearestInRange:
            target = Targeting.nearest(to: player.position, within: range, padding: padding, combat: &combat)
        }
        guard let target else { return nil }

        let aim = combat.world.delta(from: player.position, to: combat.enemies.positions[target]).normalized
        let direction = aim == .zero ? player.facing : aim
        player.facing = direction

        let count = max(1, profile.count + modifiers.extraProjectiles + Int(combat.sheet[.projectileCount]))
        let spread = 12 * Double.pi / 180
        let baseAngle = atan2(Double(direction.y), Double(direction.x)) - spread * Double(count - 1) / 2
        let speed = CGFloat(profile.speed) * CGFloat(combat.sheet[.projectileSpeed])
        // Lives long enough to cross the weapon's range with a little spare. A
        // boomerang goes out as far as its target (and a little past it), turns,
        // and lives long enough to come all the way back.
        let distanceToTarget = combat.world.distance(player.position, combat.enemies.positions[target])
        let thrown = min(range, max(2.5, distanceToTarget + 1.2))
        let flightSpeed = max(Double(speed), 0.01)
        let life = profile.returns ? Double(thrown) / flightSpeed * 2.4 + 0.6
                                   : Double(range) / max(profile.speed, 0.01) * 1.25
        let template = baseHit(weapon, combat: combat)
        let pierce = profile.pierce + Int(combat.sheet[.pierce])
        let visual: VisualStyle = VisualStyle.matching(weapon.damageType)

        for shot in 0..<count {
            let angle = baseAngle + spread * Double(shot)
            let heading = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            var hit = template
            hit.knockback = 0.45
            combat.projectiles.append(Projectile(
                id: combat.makeEntityID(),
                position: combat.world.wrap(player.position + heading * 0.35),
                velocity: heading * speed,
                remainingLife: life,
                pierceRemaining: pierce,
                hit: hit,
                radius: 0.18,
                splashRadius: splash,
                spriteID: profile.spriteID,
                visual: visual,
                turnsAfter: profile.returns ? Double(thrown) / flightSpeed : 0,
                returnsToThrower: profile.returns,
                legPierce: pierce
            ))
        }
        combat.events.append(.projectileFired(spriteID: profile.spriteID, origin: player.position,
                                              direction: direction))
        return target
    }
}

/// Target selection shared by weapons, skills and allies.
enum Targeting {
    /// Index of the closest living enemy whose body lies within `range`.
    static func nearest(to point: CGPoint, within range: CGFloat, padding: CGFloat,
                        combat: inout CombatState) -> Int? {
        combat.nearby.removeAll(keepingCapacity: true)
        combat.grid.query(around: point, radius: range + padding, into: &combat.nearby)
        var best: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for index in combat.nearby where index < combat.enemies.count && combat.enemies.health[index] > 0 {
            let surface = combat.world.distance(point, combat.enemies.positions[index])
                - combat.enemies.definition(at: index).radius
            if surface <= range, surface < bestDistance {
                bestDistance = surface
                best = index
            }
        }
        return best
    }

    /// Index of the in-range enemy with the most other enemies within
    /// `clusterRadius`, breaking ties by distance. Only the closest few
    /// candidates are scored, which bounds the cost in huge crowds.
    static func densestCluster(around point: CGPoint, within range: CGFloat, clusterRadius: CGFloat,
                               padding: CGFloat, combat: inout CombatState) -> Int? {
        combat.nearby.removeAll(keepingCapacity: true)
        combat.grid.query(around: point, radius: range + padding, into: &combat.nearby)

        var candidates: [(index: Int, distance: CGFloat)] = []
        candidates.reserveCapacity(combat.nearby.count)
        for index in combat.nearby where index < combat.enemies.count && combat.enemies.health[index] > 0 {
            let distance = combat.world.distance(point, combat.enemies.positions[index])
            if distance - combat.enemies.definition(at: index).radius <= range {
                candidates.append((index, distance))
            }
        }
        guard !candidates.isEmpty else { return nil }
        candidates.sort { $0.distance < $1.distance }

        var best = candidates[0].index
        var bestScore = -1
        let clusterRadiusSquared = clusterRadius * clusterRadius
        for candidate in candidates.prefix(12) {
            let center = combat.enemies.positions[candidate.index]
            combat.nearbySecondary.removeAll(keepingCapacity: true)
            combat.grid.query(around: center, radius: clusterRadius, into: &combat.nearbySecondary)
            var score = 0
            for other in combat.nearbySecondary where other < combat.enemies.count {
                if combat.world.distanceSquared(center, combat.enemies.positions[other]) <= clusterRadiusSquared {
                    score += 1
                }
            }
            // Candidates are sorted nearest first, so ties keep the nearer one.
            if score > bestScore {
                bestScore = score
                best = candidate.index
            }
        }
        return best
    }
}
