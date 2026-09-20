import CoreGraphics

/// Everything combat systems read and write during a step, bundled so each
/// system takes one `inout` argument instead of half a dozen.
///
/// Holds the enemies, projectiles, allies, zones, pickups and the player's
/// compiled build and stats. The damage pipeline lives in
/// `CombatState+Damage.swift`.
struct CombatState {
    let world: ToroidalWorld
    let tuning: CombatTuning

    var enemies: EnemyStore
    var projectiles: [Projectile] = []
    var allies: [Ally] = []
    var zones: [Zone] = []
    var strikes: [PendingStrike] = []
    var orbs: [ExperienceOrb] = []
    /// Vials, magnets and chests lying in the world.
    var drops: [Drop] = []
    /// Finds opened but not yet answered, oldest first. Each becomes an offer
    /// once the last one has been chosen.
    var pendingFinds: [LootTier] = []
    /// Shrines standing in the world, and bargains taken but not yet carried
    /// out by the simulation.
    var shrines: [Shrine] = []
    var pendingShrines: [ShrineKind] = []
    /// Seconds left on a Shrine of Ruin's curse.
    var curseRemaining: Double = 0
    /// Broad-phase lookup of enemy indices. Rebuilt whenever enemies move.
    var grid: ToroidalSpatialGrid
    var random: SeededRandom
    /// What drops, and what a find holds, has a stream of its own. Loot must
    /// not shift combat, and combat must not shift loot.
    var lootRandom: SeededRandom
    var stats = RunStats()
    /// Events produced since the scene last drained them.
    var events: [CombatEvent] = []
    /// Reused query results, so steady-state steps allocate nothing.
    var nearby: [Int] = []
    var nearbySecondary: [Int] = []
    private var nextEntityID = 1

    // MARK: The player's build

    private(set) var build = CompiledBuild()
    var sheet = StatSheet()
    var level = 1
    /// Damage of 100% power at the current level.
    var skillPower: Double = SkillPower.reference
    var conditions = ConditionState()
    var playerPosition: CGPoint = .zero
    var playerFacing = CGPoint(x: 1, y: 0)
    var playerStealthed = false

    /// Effects waiting to run; see `ActionExecutor`.
    var pendingActions: [QueuedAction] = []
    /// Healing earned this step (life steal, heals), applied once.
    var pendingHealing: Double = 0
    /// Experience collected this step.
    var experienceCollected = 0
    /// Enemies slain this step.
    var killsThisStep = 0
    var procCooldowns: [Double] = []
    var procTimers: [Double] = []
    var attackCount = 0
    var abilityCooldowns: [AbilityID: Double] = [:]
    var cheatDeathCooldown: Double = 0
    /// Where the player's allies stand, as enemies see them. Rebuilt each
    /// step so enemy AI never walks the ally array itself.
    var allyAnchors: [AllyAnchor] = []
    /// Seconds before a fallen companion of each summon kind returns.
    var summonCooldowns: [String: Double] = [:]
    /// Set while the player has sent their companions away.
    var companionsDismissed = false
    /// Level and growth the next summon's toughness is built from.
    var summonVitalityLevel = 1
    var summonVitalityGrowth: Double = 0

    // MARK: Enemy scaling

    var enemyHealthScale: Double = 1
    var enemyDamageScale: Double = 1

    init(world: ToroidalWorld, tuning: CombatTuning, gridCellSize: CGFloat, capacity: Int, seed: UInt64) {
        self.world = world
        self.tuning = tuning
        enemies = EnemyStore(capacity: capacity)
        grid = ToroidalSpatialGrid(world: world, cellSize: gridCellSize)
        random = SeededRandom(seed: seed)
        lootRandom = SeededRandom(seed: seed ^ 0x100_7B0F)
        nearby.reserveCapacity(64)
        nearbySecondary.reserveCapacity(64)
        events.reserveCapacity(256)
        orbs.reserveCapacity(400)
    }

    mutating func makeEntityID() -> Int {
        defer { nextEntityID += 1 }
        return nextEntityID
    }

    /// Installs a newly compiled build, keeping proc cooldowns where the
    /// proc survives.
    mutating func install(_ newBuild: CompiledBuild) {
        build = newBuild
        procCooldowns = Array(repeating: 0, count: newBuild.procs.count)
        procTimers = newBuild.procs.map { rule in
            if case .interval(let seconds) = rule.trigger { return seconds }
            return 0
        }
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

    /// Index of a living enemy by stable id, trying a remembered index first.
    func index(ofEnemy id: Int, hint: Int? = nil) -> Int? {
        if let hint, hint < enemies.count, enemies.ids[hint] == id {
            return hint
        }
        return enemies.ids.firstIndex(of: id)
    }

    /// A seeded random point within `radius` of `center`.
    mutating func randomPoint(around center: CGPoint, within radius: CGFloat) -> CGPoint {
        let angle = random.range(0, 2 * .pi)
        let distance = radius * CGFloat(random.unit().squareRoot())
        return world.wrap(center + CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle))) * distance)
    }
}
