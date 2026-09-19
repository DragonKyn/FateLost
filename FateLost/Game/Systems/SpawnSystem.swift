import CoreGraphics
import Foundation

/// Brings enemies into the arena around the player at a rate that climbs
/// over the run.
///
/// Enemies appear on a ring just beyond the edge of the screen, partly
/// biased ahead of a moving player so running never outpaces the horde.
/// Enemies left far behind are moved back onto the ring instead of trailing
/// uselessly, which keeps pressure constant without raising the count.
/// Numbered waves, elites and bosses build on this in Phase 5.
struct SpawnSystem {
    let tuning: SpawnTuning
    /// Enemy kinds this realm fields.
    let roster: [EnemyDefinition]
    /// Current spawn distance; the scene sets it from the real screen size.
    var spawnRadius: CGFloat
    var isEnabled = true

    /// Fractional enemies owed, carried between steps.
    private var accumulator: Double = 0

    init(tuning: SpawnTuning, roster: [EnemyDefinition]) {
        self.tuning = tuning
        self.roster = roster
        spawnRadius = tuning.spawnRadius
    }

    /// Enemies per second at a moment in the run.
    func rate(atElapsed elapsed: TimeInterval) -> Double {
        guard elapsed >= tuning.initialDelay else { return 0 }
        let minutes = (elapsed - tuning.initialDelay) / 60
        return min(tuning.maximumRate, tuning.baseRate + tuning.rateGrowthPerMinute * minutes)
    }

    mutating func step(_ combat: inout CombatState, player: PlayerState, elapsed: TimeInterval,
                       dt: TimeInterval, hardCap: Int, speedVariance: CGFloat) {
        recycleStragglers(&combat, player: player)
        guard isEnabled, !roster.isEmpty else { return }

        accumulator += rate(atElapsed: elapsed) * dt
        let limit = min(tuning.maximumAlive, hardCap)
        while accumulator >= 1 {
            accumulator -= 1
            guard combat.enemies.count < limit else {
                // At the cap, owed spawns are dropped rather than banked, so
                // killing a crowd doesn't unleash a burst.
                accumulator = 0
                break
            }
            let definition = roster[pick(from: &combat.random, elapsed: elapsed)]
            spawn(definition, into: &combat, player: player, speedVariance: speedVariance)
        }
    }

    /// Places `count` enemies at once, ignoring the natural cap (developer
    /// tooling and scripted events).
    mutating func spawnBurst(_ count: Int, into combat: inout CombatState, player: PlayerState,
                             hardCap: Int, speedVariance: CGFloat) {
        guard !roster.isEmpty else { return }
        let allowed = max(0, min(count, hardCap - combat.enemies.count))
        for _ in 0..<allowed {
            let definition = roster[pick(from: &combat.random, elapsed: .infinity)]
            spawn(definition, into: &combat, player: player, speedVariance: speedVariance)
        }
    }

    /// A roster index, weighted by spawn weight among the kinds allowed at
    /// this point in the run.
    private func pick(from random: inout SeededRandom, elapsed: TimeInterval) -> Int {
        let minutes = elapsed / 60
        var total = 0.0
        for definition in roster where definition.earliestMinute <= minutes {
            total += definition.spawnWeight
        }
        guard total > 0 else { return 0 }
        var roll = random.unit() * total
        for (index, definition) in roster.enumerated() where definition.earliestMinute <= minutes {
            roll -= definition.spawnWeight
            if roll < 0 { return index }
        }
        return 0
    }

    private func spawn(_ definition: EnemyDefinition, into combat: inout CombatState, player: PlayerState,
                       speedVariance: CGFloat) {
        let position = ringPosition(around: player, random: &combat.random, world: combat.world)
        let kind = combat.enemies.kindIndex(for: definition)
        let scale = 1 + CGFloat(combat.random.range(-1, 1)) * speedVariance
        let id = combat.makeEntityID()
        combat.enemies.append(id: id, kind: kind, position: position, speedScale: scale,
                              healthScale: combat.enemyHealthScale)
        combat.stats.mostEnemiesAlive = max(combat.stats.mostEnemiesAlive, combat.enemies.count)
    }

    /// A point on the spawn ring, sometimes inside a cone ahead of the
    /// player's travel.
    private func ringPosition(around player: PlayerState, random: inout SeededRandom,
                              world: ToroidalWorld) -> CGPoint {
        var angle = random.range(0, 2 * .pi)
        if player.isMoving, random.chance(tuning.aheadBias) {
            let heading = atan2(Double(player.velocity.y), Double(player.velocity.x))
            let halfCone = tuning.aheadConeDegrees * .pi / 360
            angle = heading + random.range(-halfCone, halfCone)
        }
        // A little depth to the ring so arrivals don't form a perfect circle.
        let distance = spawnRadius + CGFloat(random.range(0, 1.5))
        let offset = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle))) * distance
        return world.wrap(player.position + offset)
    }

    private mutating func recycleStragglers(_ combat: inout CombatState, player: PlayerState) {
        // Always well outside the spawn ring, whatever the screen size.
        let limit = max(tuning.recycleDistance, spawnRadius + 8)
        let limitSquared = limit * limit
        for index in 0..<combat.enemies.count
        where combat.world.distanceSquared(combat.enemies.positions[index], player.position) > limitSquared {
            combat.enemies.positions[index] = ringPosition(around: player, random: &combat.random,
                                                           world: combat.world)
            combat.enemies.knockback[index] = .zero
            combat.enemies.windup[index] = 0
        }
    }
}
