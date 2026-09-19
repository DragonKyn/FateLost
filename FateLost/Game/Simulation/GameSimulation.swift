import CoreGraphics
import Foundation

/// Identifies a run before it starts: where, with what, and from which seed.
struct RunConfiguration: Hashable {
    let realmID: RealmID
    let starterWeaponID: WeaponID
    let seed: UInt64

    static func new(realm: RealmID, weapon: WeaponID) -> RunConfiguration {
        RunConfiguration(realmID: realm, starterWeaponID: weapon, seed: UInt64.random(in: .min ... .max))
    }
}

/// Toggles that bend the rules for testing. Always off in normal play.
struct SimulationCheats: Equatable {
    var godMode = false
    var spawningEnabled = true
}

/// Level, experience and unspent skill points.
struct ProgressionState: Equatable {
    var level = 1
    var experience = 0
    var required: Int
    /// Points earned so far (one per level gained).
    var earnedPoints = 0
    var unspentPoints = 0
}

/// Ability slots: three abilities and one ultimate.
enum AbilitySlots {
    static let count = 4
    static let ultimate = 3
}

/// The authoritative game state for one run, advanced in fixed steps.
///
/// Deliberately free of SpriteKit: the scene feeds it intents and reads its
/// state to draw. That keeps game rules testable and lets rendering change
/// without touching them. Each phase adds systems here rather than to the
/// scene.
///
/// Order of a step:
/// 1. timers tick, conditions and stats refresh, health regenerates;
/// 2. the player moves and casts;
/// 3. new enemies arrive;
/// 4. enemies chase, crowd and strike (grid rebuilt first for crowding);
/// 5. the weapon attacks; allies fight; projectiles fly; zones pulse;
///    statuses tick; timed triggers fire (grid rebuilt again, so hits test
///    where enemies are now);
/// 6. the dead are removed (death triggers can kill more);
/// 7. experience is gathered, and levels gained.
///
/// Between systems, effects queued by casts and triggers are carried out
/// (`ActionExecutor.flush`).
struct GameSimulation {
    let run: RunConfiguration
    let realm: RealmDefinition
    let arena: ArenaLayout
    let weapon: WeaponDefinition
    let tuning: GameTuning

    private(set) var player: PlayerState
    private(set) var combat: CombatState
    /// Simulated seconds since the run began (excludes pauses).
    private(set) var elapsed: TimeInterval = 0
    /// Simulated seconds since the player fell, or nil while alive.
    private(set) var timeSinceDefeat: TimeInterval?
    var cheats = SimulationCheats()

    private(set) var progression: ProgressionState
    private(set) var allocation = SkillAllocation()
    /// Equipped abilities; index 3 is the ultimate.
    private(set) var abilitySlots: [AbilityID?] = Array(repeating: nil, count: AbilitySlots.count)
    /// Bumped whenever the build changes, for observers.
    private(set) var buildVersion = 0

    private let movement: MovementSystem
    private var spawner: SpawnSystem
    private var enemyAI: EnemyAISystem
    private var waves: WaveSystem
    private var weaponSystem: WeaponSystem
    private let projectileSystem = ProjectileSystem()
    private var statusSystem = StatusSystem()
    private var statSignature: StatSignature?
    private var alliesNeedSync = true

    var world: ToroidalWorld { arena.world }
    var enemies: EnemyStore { combat.enemies }
    var projectiles: [Projectile] { combat.projectiles }
    var stats: RunStats { combat.stats }
    var sheet: StatSheet { combat.sheet }
    var isPlayerDefeated: Bool { player.isDefeated }
    var allies: [Ally] { combat.allies }
    /// True while the player has sent their companions away.
    var areSummonsDismissed: Bool { combat.companionsDismissed }
    /// Companion kinds waiting to be rebuilt, with the seconds left.
    var summonCooldowns: [String: Double] { combat.summonCooldowns }
    /// Whether this build fields summons at all, so the HUD can stay clear
    /// for everyone else.
    var hasSummons: Bool { !combat.build.companions.isEmpty || !combat.allies.isEmpty }
    /// Seconds until the weapon may attack again.
    var weaponCooldown: Double { weaponSystem.cooldown }

    /// The form whose attack the player is using, if any.
    var activeForm: FormDefinition? {
        if let form = player.form, let definition = FormCatalog.form(form) {
            return definition
        }
        if let permanent = combat.build.permanentForm {
            return FormCatalog.form(permanent)
        }
        return nil
    }

    init(run: RunConfiguration, tuning: GameTuning) {
        self.run = run
        self.tuning = tuning
        let realm = RealmCatalog.realm(run.realmID)
        self.realm = realm
        weapon = StarterWeapons.definition(for: run.starterWeaponID) ?? StarterWeapons.sword
        let arena = ArenaGenerator(definition: realm.arena, seed: run.seed).generate()
        self.arena = arena
        player = PlayerState(position: arena.playerSpawn, maxHealth: tuning.player.baseMaxHealth)
        // Combat randomness has its own stream so it never shifts the arena.
        combat = CombatState(world: arena.world, tuning: tuning.combat, gridCellSize: tuning.enemyAI.gridCellSize,
                             capacity: tuning.enemyAI.hardCap, seed: run.seed ^ 0xC0_4BA7)
        movement = MovementSystem(tuning: tuning.player)
        spawner = SpawnSystem(tuning: tuning.spawning, roster: EnemyCatalog.roster(for: run.realmID))
        waves = WaveSystem(plan: realm.waves, conquestWave: realm.conquestWave)
        enemyAI = EnemyAISystem(tuning: tuning.enemyAI, combatTuning: tuning.combat)
        weaponSystem = WeaponSystem(weapon: weapon, tuning: tuning.combat,
                                    growthPerLevel: tuning.progression.damageGrowthPerLevel)
        progression = ProgressionState(required: tuning.progression.requirement(toAdvanceFrom: 1))
        combat.playerPosition = player.position
        refreshStats(force: true)
        player.health = player.maxHealth
    }

    /// Distance from the player at which enemies appear.
    var spawnRadius: CGFloat {
        get { spawner.spawnRadius }
        set { spawner.spawnRadius = max(newValue, 1) }
    }

    /// Enemies per second the spawner is currently aiming for.
    var currentSpawnRate: Double { spawner.rate(atElapsed: elapsed) }

    /// Where the run has got to: the wave, and any champion on the field.
    var wave: WaveState { waves.state }
    /// True once the realm's final champion has fallen.
    var isRealmConquered: Bool { waves.state.phase == .conquered }

    // MARK: - Step

    mutating func step(dt: TimeInterval, intent: PlayerIntent) {
        elapsed += dt
        let alive = !player.isDefeated
        if !alive {
            timeSinceDefeat = (timeSinceDefeat ?? 0) + dt
        }
        combat.killsThisStep = 0
        combat.experienceCollected = 0

        updateEnemyScaling()
        tickTimers(dt)
        updateConditions()
        refreshStats()

        movement.step(&player, intent: alive ? intent : .idle, speedMultiplier: CGFloat(combat.sheet[.moveSpeed]),
                      world: world, dt: CGFloat(dt))
        syncPlayerSnapshot()
        if alive {
            castAbilities(intent)
        }
        flush()

        if alive {
            advanceWaves(dt)
        }
        spawner.isEnabled = alive && cheats.spawningEnabled
        spawner.step(&combat, player: player, elapsed: elapsed, dt: dt, hardCap: tuning.enemyAI.hardCap,
                     speedVariance: tuning.enemyAI.speedVariance)

        combat.rebuildGrid()
        enemyAI.step(&combat, player: &player, godMode: cheats.godMode, dt: dt)
        flush()
        if alive && player.isDefeated {
            dismissPlayerForces()
        }

        combat.rebuildGrid()
        if alive {
            weaponSystem.step(&combat, player: &player, form: activeForm, dt: dt)
            flush()
        }
        AllySystem.step(&combat, player: player, dt: dt)
        flush()
        projectileSystem.step(&combat, player: &player, godMode: cheats.godMode, dt: dt)
        flush()
        ZoneSystem.step(&combat, player: &player, dt: dt)
        flush()
        statusSystem.step(&combat, dt: dt)
        if alive {
            fireIntervalProcs(dt)
            flush()
        }
        resolveDeaths()

        PickupSystem.step(&combat, player: player, dt: dt)
        if alive {
            gainExperience()
        }
        applyHealing(dt)
        if combat.killsThisStep > 0 {
            player.timeSinceKill = 0
        }
        if alive {
            // Cheap, and it has to run every step now that a companion can
            // fall and its replacement has to wait its cooldown out.
            AllySystem.syncCompanions(&combat, player: player)
        }
        if alliesNeedSync {
            alliesNeedSync = false
            syncAuras()
        }
        syncPlayerSnapshot()
    }

    /// Runs the wave clock and places whatever champion it calls for.
    ///
    /// The wave decides what the spawner is allowed to field and how hard it
    /// pushes; when a champion is due, it arrives with an escort and the
    /// ordinary horde thins out so the fight is against the champion.
    private mutating func advanceWaves(_ dt: TimeInterval) {
        let due = waves.step(&combat, dt: dt)
        spawner.wave = waves.state.index
        spawner.rateMultiplier = waves.pressure * waves.spawnShare
        combat.stats.wave = max(combat.stats.wave, waves.state.index)
        guard let due, let definition = EnemyCatalog.definition(for: due) else { return }
        let id = spawner.spawnNamed(definition, into: &combat, player: player,
                                    distance: spawner.spawnRadius * 0.8)
        guard let index = combat.index(ofEnemy: id) else { return }
        waves.bossArrived(id: id, title: definition.name, health: combat.enemies.health[index], &combat)
        spawner.spawnBurst(realm.waves.escortCount, into: &combat, player: player,
                           hardCap: tuning.enemyAI.hardCap, speedVariance: tuning.enemyAI.speedVariance)
    }

    /// A fallen hero's power dies with them: missiles, companions, zones,
    /// strikes still falling and afflictions on the horde all end at once.
    private mutating func dismissPlayerForces() {
        combat.projectiles.removeAll()
        combat.allies.removeAll()
        combat.zones.removeAll()
        combat.strikes.removeAll()
        combat.pendingActions.removeAll()
        combat.allyAnchors.removeAll()
        for index in combat.enemies.statusMask.indices {
            combat.enemies.statusMask[index] = 0
        }
    }

    private mutating func flush() {
        ActionExecutor.flush(&combat, player: &player)
    }

    /// Hands over everything that happened since the last call.
    mutating func drainEvents() -> [CombatEvent] {
        let drained = combat.events
        combat.events.removeAll(keepingCapacity: true)
        return drained
    }

    /// Removes the dead, letting death triggers (which may kill more) run.
    private mutating func resolveDeaths() {
        var rounds = 0
        while rounds < 4, combat.removeDefeatedEnemies() {
            rounds += 1
            combat.rebuildGrid()
            flush()
        }
    }

    private mutating func updateEnemyScaling() {
        let minutes = elapsed / 60
        let scaling = tuning.progression
        combat.enemyHealthScale = 1 + scaling.enemyHealthPerMinute * minutes
            + scaling.enemyHealthPerMinuteSquared * minutes * minutes
        combat.enemyDamageScale = 1 + scaling.enemyDamagePerMinute * minutes
    }

    private mutating func tickTimers(_ dt: TimeInterval) {
        player.invulnerability = max(0, player.invulnerability - dt)
        player.stealth = max(0, player.stealth - dt)
        player.timeSinceHit += dt
        player.timeSinceKill += dt
        player.timeSinceDodge += dt
        player.timeStationary = player.isMoving ? 0 : player.timeStationary + dt
        player.tickBuffs(dt)
        for index in combat.procCooldowns.indices where combat.procCooldowns[index] > 0 {
            combat.procCooldowns[index] = max(0, combat.procCooldowns[index] - dt)
        }
        if !combat.abilityCooldowns.isEmpty {
            for (id, remaining) in combat.abilityCooldowns where remaining > 0 {
                combat.abilityCooldowns[id] = max(0, remaining - dt)
            }
        }
        combat.cheatDeathCooldown = max(0, combat.cheatDeathCooldown - dt)
        AllySystem.tickCooldowns(&combat, dt: dt)
    }

    private mutating func updateConditions() {
        var conditions = ConditionState()
        conditions.isMoving = player.isMoving
        conditions.timeStationary = player.timeStationary
        conditions.healthFraction = player.healthFraction
        conditions.timeSinceKill = player.timeSinceKill
        conditions.timeSinceHit = player.timeSinceHit
        conditions.timeSinceDodge = player.timeSinceDodge
        conditions.isShielded = player.barrier > 0.5
        conditions.isStealthed = player.isStealthed
        conditions.isTransformed = player.form != nil || combat.build.permanentForm != nil

        if !combat.enemies.isEmpty {
            combat.nearby.removeAll(keepingCapacity: true)
            combat.grid.query(around: player.position, radius: 2.5, into: &combat.nearby)
            var count = 0
            for index in combat.nearby where index < combat.enemies.count {
                if combat.world.distance(player.position, combat.enemies.positions[index]) <= 2.5 {
                    count += 1
                }
            }
            conditions.nearbyEnemies = count
        }
        combat.conditions = conditions
    }

    private mutating func syncPlayerSnapshot() {
        combat.playerPosition = player.position
        combat.playerFacing = player.facing
        combat.playerStealthed = player.isStealthed
    }

    // MARK: - Stats

    private struct StatSignature: Equatable {
        var conditions: UInt64
        var buffs: Int
        var level: Int
        var form: FormID?
        var build: Int
    }

    /// Recomputes the player's stats when anything feeding them has changed.
    private mutating func refreshStats(force: Bool = false) {
        var mask: UInt64 = 0
        for (index, conditional) in combat.build.conditionals.enumerated() where index < 64 {
            if combat.conditions.holds(conditional.condition) {
                mask |= 1 << UInt64(index)
            }
        }
        let formID = player.form ?? combat.build.permanentForm
        let signature = StatSignature(conditions: mask, buffs: player.buffsVersion, level: progression.level,
                                      form: formID, build: buildVersion)
        guard force || signature != statSignature else { return }
        statSignature = signature

        var sheet = combat.sheet
        sheet.reset()
        let baseHealth = tuning.player.baseMaxHealth - StatID.maxHealth.baseValue
        let levelHealth = tuning.progression.healthPerLevel * Double(progression.level - 1)
        sheet.add(StatModifier(.maxHealth, .flat, baseHealth + levelHealth))
        sheet.add(combat.build.modifiers)
        for (index, conditional) in combat.build.conditionals.enumerated()
        where index < 64 && mask & (1 << UInt64(index)) != 0 {
            sheet.add(conditional.modifier)
        }
        for buff in player.buffs {
            for modifier in buff.modifiers {
                sheet.add(modifier.scaled(by: Double(buff.stacks)))
            }
        }
        if let formID, let form = FormCatalog.form(formID) {
            let rank = combat.build.formRanks[formID] ?? 1
            for spec in form.modifiers {
                sheet.add(spec.at(rank))
            }
        }
        sheet.finalize()
        if !combat.build.conversions.isEmpty {
            for conversion in combat.build.conversions {
                sheet.add(conversion.perPoint.scaled(by: sheet[conversion.source]))
            }
            sheet.finalize()
        }
        combat.sheet = sheet
        combat.level = progression.level
        combat.summonVitalityLevel = progression.level
        combat.summonVitalityGrowth = tuning.progression.damageGrowthPerLevel
        combat.skillPower = SkillPower.reference
            * SkillPower.growth(level: progression.level, perLevel: tuning.progression.damageGrowthPerLevel)

        // Health follows max health: gaining max health heals the difference.
        let newMaximum = sheet[.maxHealth]
        if newMaximum != player.maxHealth {
            let gained = newMaximum - player.maxHealth
            player.maxHealth = newMaximum
            if gained > 0, !player.isDefeated {
                player.health += gained
            }
            player.health = min(player.health, newMaximum)
            player.barrier = min(player.barrier, newMaximum)
        }
    }

    private mutating func applyHealing(_ dt: TimeInterval) {
        guard !player.isDefeated else {
            combat.pendingHealing = 0
            return
        }
        let received = combat.sheet[.healingReceived]
        var amount = combat.pendingHealing * received
        combat.pendingHealing = 0
        let regeneration = combat.sheet[.healthRegen]
        if regeneration > 0 {
            amount += regeneration * dt * received
        } else if regeneration < 0 {
            // Forbidden power drains, but never kills.
            player.health = max(1, player.health + regeneration * dt)
        }
        guard amount > 0 else { return }
        let healed = min(amount, player.maxHealth - player.health)
        player.health += max(0, healed)
        combat.stats.healingReceived += max(0, healed)
        let overflow = amount - max(0, healed)
        let conversion = combat.sheet[.overhealBarrier]
        if overflow > 0, conversion > 0 {
            player.barrier = min(player.maxHealth, player.barrier + overflow * conversion)
        }
    }

    // MARK: - Abilities

    private mutating func castAbilities(_ intent: PlayerIntent) {
        guard intent.abilityPresses != 0 else { return }
        for slot in 0..<AbilitySlots.count where intent.pressed(slot) {
            guard let id = abilitySlots[slot], let learned = combat.build.abilities[id] else { continue }
            guard (combat.abilityCooldowns[id] ?? 0) <= 0 else { continue }
            cast(learned)
        }
    }

    private mutating func cast(_ learned: LearnedAbility) {
        let id = learned.definition.id
        combat.abilityCooldowns[id] = learned.cooldown * (1 - combat.sheet[.cooldownReduction])
        combat.stats.abilityUses[id, default: 0] += 1
        combat.events.append(.abilityCast(id: id, visual: learned.action.visual))
        queueCast(learned.action, ability: id)

        var isToggle = false
        if case .transform = learned.action {
            isToggle = true
        }
        let echo = combat.sheet[.spellEcho]
        if !isToggle, echo > 0, combat.random.chance(echo) {
            queueCast(learned.action, ability: id)
        }
        combat.fireProcs(combat.build.castProcs, origin: player.position)
    }

    private mutating func queueCast(_ action: EffectAction, ability: AbilityID) {
        combat.pendingActions.append(QueuedAction(action: action, origin: player.position, targetID: nil,
                                                  direction: player.facing, depth: 0, ability: ability))
    }

    /// Seconds until each slot's ability is ready, and its full cooldown.
    func cooldown(forSlot slot: Int) -> (remaining: Double, total: Double)? {
        guard slot < abilitySlots.count, let id = abilitySlots[slot],
              let learned = combat.build.abilities[id] else { return nil }
        let total = learned.cooldown * (1 - combat.sheet[.cooldownReduction])
        return (combat.abilityCooldowns[id] ?? 0, total)
    }

    private mutating func fireIntervalProcs(_ dt: TimeInterval) {
        for procIndex in combat.build.intervalProcs where procIndex < combat.procTimers.count {
            combat.procTimers[procIndex] -= dt
            guard combat.procTimers[procIndex] <= 0 else { continue }
            if case .interval(let seconds) = combat.build.procs[procIndex].trigger {
                combat.procTimers[procIndex] += max(seconds, 0.1)
            }
            combat.fireProc(procIndex, origin: player.position, targetIndex: nil, depth: 0)
        }
    }

    // MARK: - Experience and levels

    private mutating func gainExperience() {
        let collected = combat.experienceCollected
        guard collected > 0 else { return }
        let gained = max(1, Int((Double(collected) * combat.sheet[.experienceGain]).rounded()))
        combat.stats.experience += gained
        progression.experience += gained
        combat.events.append(.experienceCollected(amount: gained))
        while progression.experience >= progression.required {
            levelUp()
        }
    }

    private mutating func levelUp() {
        progression.experience -= progression.required
        progression.level += 1
        progression.earnedPoints += 1
        progression.unspentPoints += 1
        progression.required = tuning.progression.requirement(toAdvanceFrom: progression.level)
        refreshStats(force: true)

        let scaling = tuning.progression
        player.invulnerability = max(player.invulnerability, scaling.levelUpImmunity)
        combat.pendingHealing += player.maxHealth * scaling.levelUpHeal
        combat.events.append(.levelUp(level: progression.level, position: player.position))

        // A burst of fate energy that clears space around you.
        let burst = DamageSpec(RankValue(scaling.levelUpBurstPower), .arcane, tags: [.area],
                               knockback: scaling.levelUpBurstKnockback)
        ActionExecutor.affect(around: player.position, radius: scaling.levelUpBurstRadius, damage: burst, status: nil,
                              depth: 2, source: .levelUp, &combat)
        resolveDeaths()
    }

    // MARK: - Summons

    /// Sends every summon away, or calls the companions back.
    ///
    /// Dismissing is instant and free: it is a tactical choice, not a cost.
    /// Recalling still respects any kind that is waiting out its death.
    mutating func setSummonsDismissed(_ dismissed: Bool) {
        guard dismissed != combat.companionsDismissed else { return }
        if dismissed {
            AllySystem.dismissAll(&combat)
            combat.events.append(.summonsDismissed)
        } else {
            combat.companionsDismissed = false
            AllySystem.syncCompanions(&combat, player: player)
            combat.events.append(.summonsRecalled)
        }
    }

    mutating func toggleSummonsDismissed() {
        setSummonsDismissed(!combat.companionsDismissed)
    }

    // MARK: - Build

    /// Points available to spend, including a draft's unspent remainder.
    var availablePoints: Int { progression.unspentPoints }

    /// Commits a skill draft from the tree screen, with ability slots.
    ///
    /// The draft must include everything already learned (no refunds
    /// mid-run), be reachable under the tree rules, and cost no more than
    /// the points earned.
    @discardableResult
    mutating func commit(_ draft: SkillAllocation, slots requestedSlots: [AbilityID?]) -> Bool {
        guard draft.spent <= progression.earnedPoints,
              SkillTreeRules.standard.isValid(draft),
              allocation.ranks.allSatisfy({ draft.rank(of: $0.key) >= $0.value }) else { return false }
        allocation = draft
        progression.unspentPoints = progression.earnedPoints - draft.spent
        rebuild()
        abilitySlots = Self.sanitize(requestedSlots, abilities: combat.build.abilities)
        return true
    }

    /// Replaces the equipped abilities.
    mutating func equip(_ slots: [AbilityID?]) {
        abilitySlots = Self.sanitize(slots, abilities: combat.build.abilities)
    }

    private mutating func rebuild() {
        combat.install(CompiledBuild.compile(allocation))
        buildVersion += 1
        refreshStats(force: true)
        alliesNeedSync = true
        // A form no longer granted can't be kept.
        if let form = player.form, combat.build.formRanks[form] == nil {
            player.form = nil
        }
    }

    /// Keeps only learned abilities, each in a slot of the right kind, and
    /// fills empty slots with learned abilities not yet equipped.
    static func sanitize(_ requested: [AbilityID?], abilities: [AbilityID: LearnedAbility]) -> [AbilityID?] {
        var slots: [AbilityID?] = Array(repeating: nil, count: AbilitySlots.count)
        var placed = Set<AbilityID>()
        for (slot, id) in requested.prefix(AbilitySlots.count).enumerated() {
            guard let id, let learned = abilities[id], !placed.contains(id) else { continue }
            guard learned.definition.isUltimate == (slot == AbilitySlots.ultimate) else { continue }
            slots[slot] = id
            placed.insert(id)
        }
        // Learned but unequipped abilities fill free slots, in the order learned.
        let unplaced = abilities.values
            .filter { !placed.contains($0.definition.id) }
            .sorted { $0.skillID < $1.skillID }
        for learned in unplaced {
            if learned.definition.isUltimate {
                if slots[AbilitySlots.ultimate] == nil {
                    slots[AbilitySlots.ultimate] = learned.definition.id
                }
            } else if let free = (0..<AbilitySlots.ultimate).first(where: { slots[$0] == nil }) {
                slots[free] = learned.definition.id
            }
        }
        return slots
    }

    /// Re-creates the permanent auras the build grants.
    private mutating func syncAuras() {
        combat.zones.removeAll { $0.isAura }
        let context = QueuedAction(action: .all([]), origin: player.position, targetID: nil, direction: .zero,
                                   depth: 0, ability: nil)
        for aura in combat.build.auras {
            ActionExecutor.place(aura, context, &combat, player, isAura: true)
        }
    }

    // MARK: - Developer commands

    /// Developer tooling: jump straight to the next wave.
    mutating func skipWave() {
        waves.skipToNextWave(&combat)
        spawner.wave = waves.state.index
    }

    mutating func spawnEnemies(_ count: Int) {
        spawner.spawnBurst(count, into: &combat, player: player, hardCap: tuning.enemyAI.hardCap,
                           speedVariance: tuning.enemyAI.speedVariance)
    }

    /// Kills every enemy, awarding the kills as if the player had landed them.
    mutating func defeatAllEnemies() {
        for index in 0..<combat.enemies.count {
            combat.enemies.health[index] = 0
        }
        resolveDeaths()
    }

    mutating func restorePlayerHealth() {
        guard !player.isDefeated else { return }
        player.health = player.maxHealth
    }

    /// Gains levels instantly, with all their usual effects.
    mutating func grantLevels(_ count: Int) {
        guard !player.isDefeated else { return }
        for _ in 0..<max(0, count) {
            progression.experience = progression.required
            levelUp()
        }
    }

    /// Takes back every skill point (developer tooling only).
    mutating func resetSkills() {
        allocation = SkillAllocation()
        progression.unspentPoints = progression.earnedPoints
        player.form = nil
        rebuild()
        abilitySlots = Array(repeating: nil, count: AbilitySlots.count)
    }
}
