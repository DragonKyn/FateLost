import CoreGraphics

/// Everything combat systems read and write during a step, bundled so each
/// system takes one `inout` argument instead of half a dozen.
struct CombatState {
    let world: ToroidalWorld
    let tuning: CombatTuning

    var enemies: EnemyStore
    var projectiles: [Projectile] = []
    /// Broad-phase lookup of enemy indices. Rebuilt whenever enemies move.
    var grid: ToroidalSpatialGrid
    var random: SeededRandom
    var stats = RunStats()
    /// Events produced since the scene last drained them.
    var events: [CombatEvent] = []
    /// Reused query results, so steady-state steps allocate nothing.
    var nearby: [Int] = []
    var nearbySecondary: [Int] = []
    private var nextEntityID = 1

    init(world: ToroidalWorld, tuning: CombatTuning, gridCellSize: CGFloat, capacity: Int, seed: UInt64) {
        self.world = world
        self.tuning = tuning
        enemies = EnemyStore(capacity: capacity)
        grid = ToroidalSpatialGrid(world: world, cellSize: gridCellSize)
        random = SeededRandom(seed: seed)
        nearby.reserveCapacity(64)
        nearbySecondary.reserveCapacity(64)
        events.reserveCapacity(256)
    }

    mutating func makeEntityID() -> Int {
        defer { nextEntityID += 1 }
        return nextEntityID
    }

    /// Re-inserts every enemy at its current position.
    mutating func rebuildGrid() {
        grid.removeAll()
        for index in 0..<enemies.count {
            grid.insert(index, at: enemies.positions[index])
        }
    }

    /// Largest body radius among enemy kinds present, for query padding.
    var largestEnemyRadius: CGFloat {
        max(enemies.largestRadius, 0.25)
    }

    /// Rolls variance and critical chance for one hit.
    mutating func rollDamage(base: Double) -> (amount: Double, isCritical: Bool) {
        let variance = tuning.damageVariance
        var amount = base * random.range(1 - variance, 1 + variance)
        let isCritical = random.chance(tuning.critChance)
        if isCritical {
            amount *= tuning.critMultiplier
        }
        return (amount, isCritical)
    }

    /// Applies a hit to a living enemy.
    ///
    /// - Parameters:
    ///   - direction: Unit vector the blow travels along (for knockback and
    ///     hit effects).
    ///   - knockbackScale: Fraction of standard weapon knockback.
    /// - Returns: false if the enemy was already dead this step.
    @discardableResult
    mutating func damageEnemy(at index: Int, base: Double, direction: CGPoint, knockbackScale: CGFloat) -> Bool {
        guard enemies.health[index] > 0 else { return false }
        let (amount, isCritical) = rollDamage(base: base)
        let dealt = min(amount, enemies.health[index])
        enemies.health[index] -= amount
        stats.damageDealt += dealt
        if isCritical {
            stats.criticalHits += 1
        }

        let resistance = enemies.definition(at: index).knockbackResistance
        let push = tuning.weaponKnockbackSpeed * knockbackScale * max(0, 1 - resistance)
        enemies.knockback[index] = enemies.knockback[index] + direction * push

        events.append(.enemyHit(enemyID: enemies.ids[index], position: enemies.positions[index],
                                amount: amount, isCritical: isCritical, direction: direction))
        return true
    }

    /// Removes every enemy whose health has run out and reports the kills.
    mutating func removeDefeatedEnemies() {
        var index = enemies.count - 1
        while index >= 0 {
            if enemies.health[index] <= 0 {
                let direction = enemies.knockback[index].lengthSquared > 0.0001
                    ? enemies.knockback[index].normalized
                    : enemies.heading[index] * -1
                events.append(.enemyKilled(enemyID: enemies.ids[index], kind: enemies.definition(at: index).id,
                                           position: enemies.positions[index], direction: direction))
                stats.kills += 1
                enemies.remove(at: index)
            }
            index -= 1
        }
    }
}
