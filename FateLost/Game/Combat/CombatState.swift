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

    // MARK: The party
    //
    // Everything above the "Enemy scaling" mark that belongs to one hero (the
    // build, stats, summons, zones and so on) is swapped in and out as the
    // simulation turns to each member of the party (`exchangeHero`); what is
    // below it, and the enemies, drops and shrines, is the shared world.

    /// Enemy shots in flight. Shared, because they look for any hero.
    var hostileProjectiles: [Projectile] = []
    /// Every hero's summons as the horde sees them, rebuilt each step.
    var worldAnchors: [AllyAnchor] = []
    /// What the horde did to the party this step, waiting to be carried out.
    var incidents: [WorldIncident] = []
    /// Blessings that reach beyond their caster, waiting to be delivered.
    var partyEffects: [PartyEffect] = []
    var reviveMarkers: [ReviveMarker] = []
    /// Which hero's state is live in the per-hero fields.
    var activeHero = 0
    /// True when more than one hero shares this world, so effects that reach
    /// beyond their caster are worth queueing.
    var isParty = false

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


/// One hero's share of `CombatState`, held while another hero is live.
///
/// `CombatState.exchangeHero` swaps these fields with the live ones, so every
/// combat system keeps working on "the hero" without knowing a party exists.
/// `heroFieldNames` and `sharedFieldNames` classify every stored property of
/// `CombatState`; a test fails if one is added and not classified.
struct HeroCombat {
    var projectiles: [Projectile] = []
    var allies: [Ally] = []
    var zones: [Zone] = []
    var strikes: [PendingStrike] = []
    var pendingFinds: [LootTier] = []
    var pendingShrines: [ShrineKind] = []
    var random: SeededRandom
    var stats = RunStats()
    var events: [CombatEvent] = []
    var build = CompiledBuild()
    var sheet = StatSheet()
    var level = 1
    var skillPower: Double = SkillPower.reference
    var conditions = ConditionState()
    var playerPosition: CGPoint = .zero
    var playerFacing = CGPoint(x: 1, y: 0)
    var playerStealthed = false
    var pendingActions: [QueuedAction] = []
    var pendingHealing: Double = 0
    var experienceCollected = 0
    var killsThisStep = 0
    var procCooldowns: [Double] = []
    var procTimers: [Double] = []
    var attackCount = 0
    var abilityCooldowns: [AbilityID: Double] = [:]
    var cheatDeathCooldown: Double = 0
    var allyAnchors: [AllyAnchor] = []
    var summonCooldowns: [String: Double] = [:]
    var companionsDismissed = false
    var summonVitalityLevel = 1
    var summonVitalityGrowth: Double = 0

    init(seed: UInt64) {
        random = SeededRandom(seed: seed)
    }
}

extension CombatState {
    /// The properties that belong to a hero, in the order `exchangeHero` swaps them.
    static let heroFieldNames: [String] = [
        "projectiles", "allies", "zones", "strikes", "pendingFinds", "pendingShrines", "random", "stats", "events",
        "build", "sheet", "level", "skillPower", "conditions", "playerPosition", "playerFacing", "playerStealthed",
        "pendingActions", "pendingHealing", "experienceCollected", "killsThisStep", "procCooldowns", "procTimers",
        "attackCount", "abilityCooldowns", "cheatDeathCooldown", "allyAnchors", "summonCooldowns",
        "companionsDismissed", "summonVitalityLevel", "summonVitalityGrowth",
    ]

    /// The properties every hero shares.
    static let sharedFieldNames: [String] = [
        "world", "tuning", "enemies", "orbs", "drops", "shrines", "curseRemaining", "grid", "lootRandom", "nearby",
        "nearbySecondary", "nextEntityID", "enemyHealthScale", "enemyDamageScale", "hostileProjectiles",
        "worldAnchors", "incidents", "partyEffects", "reviveMarkers", "activeHero", "isParty",
    ]

    /// Swaps this hero's fields with `other`'s. Moves references and copies
    /// nothing, so it costs a few dozen pointer writes.
    mutating func exchangeHero(with other: inout HeroCombat) {
        swap(&projectiles, &other.projectiles)
        swap(&allies, &other.allies)
        swap(&zones, &other.zones)
        swap(&strikes, &other.strikes)
        swap(&pendingFinds, &other.pendingFinds)
        swap(&pendingShrines, &other.pendingShrines)
        swap(&random, &other.random)
        swap(&stats, &other.stats)
        swap(&events, &other.events)
        swap(&build, &other.build)
        swap(&sheet, &other.sheet)
        swap(&level, &other.level)
        swap(&skillPower, &other.skillPower)
        swap(&conditions, &other.conditions)
        swap(&playerPosition, &other.playerPosition)
        swap(&playerFacing, &other.playerFacing)
        swap(&playerStealthed, &other.playerStealthed)
        swap(&pendingActions, &other.pendingActions)
        swap(&pendingHealing, &other.pendingHealing)
        swap(&experienceCollected, &other.experienceCollected)
        swap(&killsThisStep, &other.killsThisStep)
        swap(&procCooldowns, &other.procCooldowns)
        swap(&procTimers, &other.procTimers)
        swap(&attackCount, &other.attackCount)
        swap(&abilityCooldowns, &other.abilityCooldowns)
        swap(&cheatDeathCooldown, &other.cheatDeathCooldown)
        swap(&allyAnchors, &other.allyAnchors)
        swap(&summonCooldowns, &other.summonCooldowns)
        swap(&companionsDismissed, &other.companionsDismissed)
        swap(&summonVitalityLevel, &other.summonVitalityLevel)
        swap(&summonVitalityGrowth, &other.summonVitalityGrowth)
    }
}
