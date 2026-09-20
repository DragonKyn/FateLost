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
/// Where the horde is drawn to: a hero, as the spawner needs to know them.
struct SpawnFocus {
    var position: CGPoint
    var velocity: CGPoint

    var isMoving: Bool { velocity.lengthSquared > 0.0001 }

    init(position: CGPoint, velocity: CGPoint = .zero) {
        self.position = position
        self.velocity = velocity
    }

    init(_ player: PlayerState) {
        self.init(position: player.position, velocity: player.velocity)
    }
}

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
        step(&combat, focuses: [SpawnFocus(player)], elapsed: elapsed, dt: dt, hardCap: hardCap,
             speedVariance: speedVariance)
    }

    /// Spawns around a party: each arrival picks one of the heroes to appear
    /// around. A lone hero is picked without touching the random stream, so
    /// a solo run is exactly what it always was.
    mutating func step(_ combat: inout CombatState, focuses: [SpawnFocus], elapsed: TimeInterval,
                       dt: TimeInterval, hardCap: Int, speedVariance: CGFloat) {
        recycleStragglers(&combat, focuses: focuses)
        guard isEnabled, !roster.isEmpty, !focuses.isEmpty else { return }

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
            let focus = Self.pickFocus(focuses, random: &combat.random)
            spawn(definition, into: &combat, focus: focus, speedVariance: speedVariance)
        }
    }

    /// Places `count` enemies at once, ignoring the natural cap (developer
    /// tooling, and a champion's escort).
    mutating func spawnBurst(_ count: Int, into combat: inout CombatState, player: PlayerState,
                             hardCap: Int, speedVariance: CGFloat) {
        spawnBurst(count, into: &combat, focuses: [SpawnFocus(player)], hardCap: hardCap,
                   speedVariance: speedVariance)
    }

    mutating func spawnBurst(_ count: Int, into combat: inout CombatState, focuses: [SpawnFocus],
                             hardCap: Int, speedVariance: CGFloat) {
        guard !roster.isEmpty, !focuses.isEmpty else { return }
        let allowed = max(0, min(count, hardCap - combat.enemies.count))
        for _ in 0..<allowed {
            let definition = roster[pick(from: &combat.random)]
            let focus = Self.pickFocus(focuses, random: &combat.random)
            spawn(definition, into: &combat, focus: focus, speedVariance: speedVariance)
        }
    }

    /// One of the heroes, without spending a random number when there is only one.
    private static func pickFocus(_ focuses: [SpawnFocus], random: inout SeededRandom) -> SpawnFocus {
        guard focuses.count > 1 else { return focuses[0] }
        return focuses[min(focuses.count - 1, Int(random.unit() * Double(focuses.count)))]
    }

    /// Places one named creature on the ring and hands back its stable id.
    /// Champions never roll a strain and never take speed variance.
    @discardableResult
    mutating func spawnNamed(_ definition: EnemyDefinition, into combat: inout CombatState,
                             player: PlayerState, distance: CGFloat? = nil) -> Int {
        spawnNamed(definition, into: &combat, focus: SpawnFocus(player), distance: distance)
    }

    @discardableResult
    mutating func spawnNamed(_ definition: EnemyDefinition, into combat: inout CombatState,
                             focus: SpawnFocus, distance: CGFloat? = nil) -> Int {
        var position = ringPosition(around: focus, random: &combat.random, world: combat.world)
        if let distance {
            let offset = combat.world.delta(from: focus.position, to: position).normalized * distance
            position = combat.world.wrap(focus.position + offset)
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

    private func spawn(_ definition: EnemyDefinition, into combat: inout CombatState, focus: SpawnFocus,
                       speedVariance: CGFloat) {
        let position = ringPosition(around: focus, random: &combat.random, world: combat.world)
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
    private func ringPosition(around player: SpawnFocus, random: inout SeededRandom,
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

    private mutating func recycleStragglers(_ combat: inout CombatState, focuses: [SpawnFocus]) {
        guard !focuses.isEmpty else { return }
        // Always well outside the spawn ring, whatever the screen size.
        let limit = max(tuning.recycleDistance, spawnRadius + 8)
        let limitSquared = limit * limit
        for index in 0..<combat.enemies.count {
            // Far from every hero, not just from one of them.
            var nearest = CGFloat.greatestFiniteMagnitude
            for focus in focuses {
                nearest = min(nearest, combat.world.distanceSquared(combat.enemies.positions[index], focus.position))
            }
            guard nearest > limitSquared else { continue }
            // A champion is never quietly teleported: the fight is where it is.
            guard !combat.enemies.definition(at: index).isBoss else { continue }
            let focus = Self.pickFocus(focuses, random: &combat.random)
            combat.enemies.positions[index] = ringPosition(around: focus, random: &combat.random,
                                                           world: combat.world)
            combat.enemies.knockback[index] = .zero
            combat.enemies.windup[index] = 0
        }
    }
}
