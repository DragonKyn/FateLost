import CoreGraphics
import Foundation

/// Brings enemies into the arena around the player at a rate that climbs
/// over the run.
///
/// Enemies appear on a ring just beyond the edge of the screen, partly
/// biased ahead of a moving player so running never outpaces the horde.
/// Enemies left far behind are moved back onto the ring instead of trailing
/// uselessly, which keeps pressure constant without raising the count.
///
/// What arrives is decided by the wave: a roster's easy kinds are there from
/// the first wave and the nastier ones unlock later, and every ordinary
/// creature rolls a strain (see `EnemyStrain`) so no two goblins in a crowd
/// are quite the same. `WaveSystem` owns *when*; this owns *what* and *where*.
struct SpawnSystem {
    let tuning: SpawnTuning
    /// Enemy kinds this realm fields.
    let roster: [EnemyDefinition]
    /// Current spawn distance; the scene sets it from the real screen size.
    var spawnRadius: CGFloat
    var isEnabled = true
    /// Wave the spawner is currently filling.
    var wave = 1
    /// Multiplier on the spawn rate from wave pressure and the boss phase.
    var rateMultiplier: Double = 1

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
        let base = min(tuning.maximumRate, tuning.baseRate + tuning.rateGrowthPerMinute * minutes)
        return base * rateMultiplier
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
            let definition = roster[pick(from: &combat.random)]
            spawn(definition, into: &combat, player: player, speedVariance: speedVariance)
        }
    }

    /// Places `count` enemies at once, ignoring the natural cap (developer
    /// tooling, and a champion's escort).
    mutating func spawnBurst(_ count: Int, into combat: inout CombatState, player: PlayerState,
                             hardCap: Int, speedVariance: CGFloat) {
        guard !roster.isEmpty else { return }
        let allowed = max(0, min(count, hardCap - combat.enemies.count))
        for _ in 0..<allowed {
            let definition = roster[pick(from: &combat.random)]
            spawn(definition, into: &combat, player: player, speedVariance: speedVariance)
        }
    }

    /// Places one named creature on the ring and hands back its stable id.
    /// Champions never roll a strain and never take speed variance.
    @discardableResult
    mutating func spawnNamed(_ definition: EnemyDefinition, into combat: inout CombatState,
                             player: PlayerState, distance: CGFloat? = nil) -> Int {
        var position = ringPosition(around: player, random: &combat.random, world: combat.world)
        if let distance {
            let offset = combat.world.delta(from: player.position, to: position).normalized * distance
            position = combat.world.wrap(player.position + offset)
        }
        let kind = combat.enemies.kindIndex(for: definition)
        let id = combat.makeEntityID()
        combat.enemies.append(id: id, kind: kind, position: position, speedScale: 1,
                              healthScale: combat.enemyHealthScale)
        combat.stats.mostEnemiesAlive = max(combat.stats.mostEnemiesAlive, combat.enemies.count)
        return id
    }

    /// A roster index, weighted by spawn weight among the kinds this wave
    /// allows.
    private func pick(from random: inout SeededRandom) -> Int {
        var total = 0.0
        for definition in roster where definition.earliestWave <= wave {
            total += definition.spawnWeight
        }
        guard total > 0 else { return 0 }
        var roll = random.unit() * total
        for (index, definition) in roster.enumerated() where definition.earliestWave <= wave {
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
        let strain = EnemyStrain.roll(for: definition.rank, wave: wave, random: &combat.random)
        let id = combat.makeEntityID()
        combat.enemies.append(id: id, kind: kind, position: position, speedScale: scale,
                              healthScale: combat.enemyHealthScale, strain: strain)
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
            // A champion is never quietly teleported: the fight is where it is.
            guard !combat.enemies.definition(at: index).isBoss else { continue }
            combat.enemies.positions[index] = ringPosition(around: player, random: &combat.random,
                                                           world: combat.world)
            combat.enemies.knockback[index] = .zero
            combat.enemies.windup[index] = 0
        }
    }
}
