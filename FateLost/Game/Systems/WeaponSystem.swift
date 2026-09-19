import CoreGraphics
import Foundation

/// Fires the player's weapon automatically.
///
/// The weapon waits until it is ready and a valid target exists, then
/// attacks: a melee weapon sweeps an arc toward its target, hitting every
/// enemy inside; a ranged weapon launches projectiles for `ProjectileSystem`
/// to fly. If nothing is in reach the weapon stays ready, so the attack comes
/// out the instant an enemy steps in rather than on an arbitrary beat.
struct WeaponSystem {
    let weapon: WeaponDefinition
    let tuning: CombatTuning
    /// Seconds until the weapon may attack again.
    private(set) var cooldown: Double = 0

    init(weapon: WeaponDefinition, tuning: CombatTuning) {
        self.weapon = weapon
        self.tuning = tuning
    }

    var attackInterval: Double { 1 / max(weapon.attackSpeed, 0.01) }

    mutating func step(_ combat: inout CombatState, player: inout PlayerState, dt: TimeInterval) {
        cooldown = max(0, cooldown - dt)
        guard cooldown <= 0, !player.isDefeated, !combat.enemies.isEmpty else { return }

        switch weapon.delivery {
        case .meleeArc(let arcDegrees):
            if swing(arcDegrees: arcDegrees, combat: &combat, player: &player) {
                cooldown = attackInterval
            }
        case .projectile(let profile):
            if fire(profile, combat: &combat, player: &player) {
                cooldown = attackInterval
            }
        }
    }

    // MARK: - Melee

    private func swing(arcDegrees: Double, combat: inout CombatState, player: inout PlayerState) -> Bool {
        let range = CGFloat(weapon.range)
        let padding = combat.largestEnemyRadius
        guard let target = Targeting.nearest(to: player.position,
                                             within: range + tuning.meleeAcquireSlack,
                                             padding: padding, combat: &combat) else {
            return false
        }
        let aim = combat.world.delta(from: player.position, to: combat.enemies.positions[target]).normalized
        let direction = aim == .zero ? player.facing : aim
        player.facing = direction

        let halfArcCosine = CGFloat(cos(arcDegrees * .pi / 360))
        // The swing reaches as far as the target it was aimed at.
        let sweep = range + tuning.meleeAcquireSlack
        combat.nearby.removeAll(keepingCapacity: true)
        combat.grid.query(around: player.position, radius: sweep + padding, into: &combat.nearby)
        for index in combat.nearby where index < combat.enemies.count {
            let offset = combat.world.delta(from: player.position, to: combat.enemies.positions[index])
            let distance = offset.length
            let reach = sweep + combat.enemies.definition(at: index).radius
            guard distance <= reach else { continue }
            let inArc = distance <= tuning.meleePointBlank
                || (distance > 0.0001 && (offset / distance).dot(direction) >= halfArcCosine)
            guard inArc else { continue }
            let pushDirection = distance > 0.0001 ? offset / distance : direction
            combat.damageEnemy(at: index, base: weapon.baseDamage, direction: pushDirection, knockbackScale: 1)
        }

        combat.events.append(.meleeSwing(origin: player.position, direction: direction, range: range,
                                         arcDegrees: arcDegrees))
        return true
    }

    // MARK: - Projectiles

    private func fire(_ profile: ProjectileProfile, combat: inout CombatState, player: inout PlayerState) -> Bool {
        let range = CGFloat(weapon.range)
        let padding = combat.largestEnemyRadius
        let target: Int?
        switch weapon.targeting {
        case .densestCluster:
            target = Targeting.densestCluster(around: player.position, within: range,
                                              clusterRadius: max(CGFloat(profile.splashRadius), 1),
                                              padding: padding, combat: &combat)
        case .nearest, .nearestInRange:
            target = Targeting.nearest(to: player.position, within: range, padding: padding, combat: &combat)
        }
        guard let target else { return false }

        let aim = combat.world.delta(from: player.position, to: combat.enemies.positions[target]).normalized
        let direction = aim == .zero ? player.facing : aim
        player.facing = direction

        let count = max(1, profile.count)
        let spread = 12 * Double.pi / 180
        let baseAngle = atan2(Double(direction.y), Double(direction.x)) - spread * Double(count - 1) / 2
        let speed = CGFloat(profile.speed)
        // Lives long enough to cross the weapon's range with a little spare.
        let life = Double(range) / max(profile.speed, 0.01) * 1.25

        for shot in 0..<count {
            let angle = baseAngle + spread * Double(shot)
            let heading = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            combat.projectiles.append(Projectile(
                id: combat.makeEntityID(),
                position: combat.world.wrap(player.position + heading * 0.35),
                velocity: heading * speed,
                remainingLife: life,
                pierceRemaining: profile.pierce,
                baseDamage: weapon.baseDamage,
                damageType: weapon.damageType,
                radius: 0.18,
                splashRadius: CGFloat(profile.splashRadius),
                spriteID: profile.spriteID
            ))
        }
        combat.events.append(.projectileFired(spriteID: profile.spriteID, origin: player.position,
                                              direction: direction))
        return true
    }
}

/// Target selection shared by weapons (and, later, skills).
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
