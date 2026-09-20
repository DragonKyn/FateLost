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
    /// The weapon in the hand. Starts as the one the run began with and
    /// changes if the player takes a weapon from a find.
    var weapon: WeaponDefinition
    let tuning: GameTuning
    /// Permanent bonuses the Legacy board grants this run. Applied as part
    /// of the stat sheet, so every other system sees them as ordinary stats.
    var legacy: [StatModifier]
    /// Extra rerolls on every find, from the relic codex.
    var bonusRerolls: Int

    var player: PlayerState
    var combat: CombatState
    /// Simulated seconds since the run began (excludes pauses).
    var elapsed: TimeInterval = 0
    /// Simulated seconds since the player fell, or nil while alive.
    var timeSinceDefeat: TimeInterval?
    var cheats = SimulationCheats()

    // MARK: The party
    //
    // A run has one hero or several. The hero the fields above and `combat`
    // describe is the *live* one (`activeHero`); the others wait in `slots`
    // and are swapped in when it is their turn (`activate`). With one hero
    // nothing is ever swapped, and the simulation is what it always was.

    /// The swapped-out state of every hero. The live hero's entry is stale.
    var slots: [HeroSlot] = []
    /// Which hero is live in the fields above.
    var activeHero = 0
    /// Identity and party-only facts about each hero, by index.
    var members: [PartyMember] = [PartyMember()]
    /// Seconds since every hero fell, or nil while any stands.
    var timeSinceWipe: TimeInterval?
    var stepCounter = 0
    /// Scratch space reused every step so the party allocates nothing.
    var spawnFocusScratch: [SpawnFocus] = []
    var targetScratch: [AITarget] = []

    var progression: ProgressionState
    var allocation = SkillAllocation()
    /// Equipped abilities; index 3 is the ultimate.
    var abilitySlots: [AbilityID?] = Array(repeating: nil, count: AbilitySlots.count)
    /// Bumped whenever the build changes, for observers.
    var buildVersion = 0
    /// Relics found this run.
    var relics = RelicInventory()
    /// The rolled weapon in the hand, or nil while it is still the starter.
    var wielded: WeaponFind?
    var weaponVersion = 0
    /// A find waiting for the player to choose from. While it is set the
    /// scene holds the game still and shows the cards.
    var offer: RelicOffer?

    let movement: MovementSystem
    var spawner: SpawnSystem
    var enemyAI: EnemyAISystem
    var waves: WaveSystem
    var weaponSystem: WeaponSystem
    private let projectileSystem = ProjectileSystem()
    var statusSystem = StatusSystem()
    var statSignature: StatSignature?
    var alliesNeedSync = true
    /// The wave a shrine was last considered for.
    var shrineWave = 1

    var world: ToroidalWorld { arena.world }
    var enemies: EnemyStore { combat.enemies }
    /// Every projectile in flight: each hero's own, and the horde's.
    var projectiles: [Projectile] {
        if slots.count > 1 || !combat.hostileProjectiles.isEmpty {
            var all = combat.projectiles
            for hero in slots.indices where hero != activeHero {
                all.append(contentsOf: slots[hero].combat.projectiles)
            }
            all.append(contentsOf: combat.hostileProjectiles)
            return all
        }
        return combat.projectiles
    }
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

    init(run: RunConfiguration, tuning: GameTuning, legacy: [StatModifier] = [], bonusRerolls: Int = 0) {
        self.run = run
        self.tuning = tuning
        self.legacy = legacy
        self.bonusRerolls = max(0, bonusRerolls)
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

    /// Advances a run with a single hero by one fixed step.
    mutating func step(dt: TimeInterval, intent: PlayerIntent) {
        members[0].intent = intent
        step(dt: dt)
    }

    /// Records what a hero wants to do. Presses (abilities, interact) are
    /// used by the next step that sees them and then forgotten; movement stays
    /// until it is changed.
    mutating func setIntent(_ intent: PlayerIntent, forHero hero: Int) {
        guard members.indices.contains(hero) else { return }
        members[hero].intent = intent
    }

    /// Advances the whole run by one fixed step.
    ///
    /// Each hero takes a turn at the parts of the step that are theirs (their
    /// timers, movement, casts, weapon, summons, pickups); the horde, the wave
    /// clock and the spawner run once for everyone. A party's turns rotate, so
    /// no hero always gets first pick of what lies on the ground.
    mutating func step(dt: TimeInterval) {
        let count = heroCount
        let party = count > 1
        elapsed += dt
        stepCounter &+= 1
        let first = party ? stepCounter % count : 0

        // Who is standing at the start of the step, and a clean slate for
        // what each hero collects.
        for turn in 0..<count {
            let hero = (first + turn) % count
            activate(hero)
            let alive = !player.isDefeated
            members[hero].stepAlive = alive
            if !alive {
                timeSinceDefeat = (timeSinceDefeat ?? 0) + dt
            }
            combat.killsThisStep = 0
            combat.experienceCollected = 0
        }
        let anyAlive = members.contains { $0.stepAlive }
        timeSinceWipe = anyAlive ? nil : (timeSinceWipe ?? 0) + dt

        updateEnemyScaling()
        combat.curseRemaining = max(0, combat.curseRemaining - dt)
        updateShelters(dt)

        // Each hero: timers, conditions, stats, movement, casts.
        for turn in 0..<count {
            let hero = (first + turn) % count
            activate(hero)
            let alive = members[hero].stepAlive
            var intent = members[hero].intent
            let sheltered = isSheltered(hero)
            if sheltered {
                intent = .idle
            }
            tickTimers(dt)
            if sheltered {
                player.invulnerability = max(player.invulnerability, 0.25)
            }
            updateConditions()
            refreshStats()

            movement.step(&player, intent: alive ? intent : .idle, speedMultiplier: CGFloat(combat.sheet[.moveSpeed]),
                          world: world, dt: CGFloat(dt))
            syncPlayerSnapshot()
            if alive {
                castAbilities(intent)
            }
            flush()
        }

        // The world: the wave clock, new arrivals and the horde, once.
        activate(0)
        collectSpawnFocuses(anyAlive: anyAlive)
        if anyAlive {
            advanceWaves(dt)
        }
        spawner.isEnabled = anyAlive && cheats.spawningEnabled
        spawner.step(&combat, focuses: spawnFocusScratch, elapsed: elapsed, dt: dt,
                     hardCap: tuning.enemyAI.hardCap, speedVariance: tuning.enemyAI.speedVariance)

        combat.rebuildGrid()
        gatherWorldAnchors()
        collectTargets()
        enemyAI.step(&combat, targets: targetScratch, godMode: cheats.godMode, dt: dt)
        projectileSystem.stepHostile(&combat, targets: targetScratch, dt: dt)
        carryOutIncidents()
        registerFallenHeroes()
        stepRevives(dt: dt)

        // Each hero: weapon, summons, shots, zones, procs, deaths, pickups.
        for turn in 0..<count {
            let hero = (first + turn) % count
            activate(hero)
            let alive = members[hero].stepAlive
            combat.rebuildGrid()
            if alive {
                weaponSystem.step(&combat, player: &player, form: activeForm, dt: dt)
                flush()
            }
            AllySystem.step(&combat, player: player, dt: dt)
            flush()
            projectileSystem.stepOwned(&combat, dt: dt)
            flush()
            ZoneSystem.step(&combat, player: &player, dt: dt)
            flush()
            if turn == 0 {
                // Afflictions tick once for the whole horde, whoever laid them.
                statusSystem.step(&combat, dt: dt)
            }
            if alive {
                fireIntervalProcs(dt)
                flush()
            }
            resolveDeaths()

            PickupSystem.step(&combat, player: player, dt: dt)
            ShrineSystem.step(&combat, player: player, dt: dt)
        }

        // Experience gathered by anyone is everyone's.
        if party {
            shareExperience()
        }

        // Each hero: bargains, levels, finds, healing.
        for turn in 0..<count {
            let hero = (first + turn) % count
            activate(hero)
            let alive = members[hero].stepAlive
            if alive {
                carryOutShrines()
                gainExperience()
                openNextFind()
            } else if party {
                members[hero].bankedExperience += combat.experienceCollected
                combat.experienceCollected = 0
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
            // Presses are used up by the step that saw them.
            members[hero].intent.abilityPresses = 0
            members[hero].intent.interact = false
        }
        activate(0)
    }

    /// Runs the wave clock and places whatever champion it calls for.
    ///
    /// The wave decides what the spawner is allowed to field and how hard it
    /// pushes; when a champion is due, it arrives with an escort and the
    /// ordinary horde thins out so the fight is against the champion.
    mutating func advanceWaves(_ dt: TimeInterval) {
        let due = waves.step(&combat, dt: dt)
        if waves.state.index != shrineWave {
            shrineWave = waves.state.index
            ShrineSystem.waveBegan(shrineWave, isBossWave: realm.waves.isBossWave(shrineWave), &combat,
                                   player: referencePlayer())
        }
        spawner.wave = waves.state.index
        spawner.rateMultiplier = waves.pressure * waves.spawnShare * partySpawnFactor()
        combat.stats.wave = max(combat.stats.wave, waves.state.index)
        guard let due, let definition = EnemyCatalog.definition(for: due),
              let focus = spawnFocusScratch.first else { return }
        let id = spawner.spawnNamed(definition, into: &combat, focus: focus,
                                    distance: spawner.spawnRadius * 0.8)
        guard let index = combat.index(ofEnemy: id) else {
            // The champion never made it onto the field. Carry on with the
            // wave rather than leaving the run waiting for a fight that
            // cannot happen.
            waves.abandonBossWave()
            return
        }
        let title = definition.epithet.map { "\(definition.name), \($0)" } ?? definition.name
        waves.bossArrived(id: id, title: title, health: combat.enemies.health[index], &combat)
        spawner.spawnBurst(realm.waves.escortCount, into: &combat, focuses: spawnFocusScratch,
                           hardCap: tuning.enemyAI.hardCap, speedVariance: tuning.enemyAI.speedVariance)
    }

    /// A fallen hero's power dies with them: missiles, companions, zones,
    /// strikes still falling and afflictions on the horde all end at once.
    mutating func dismissPlayerForces() {
        combat.projectiles.removeAll()
        combat.allies.removeAll()
        combat.zones.removeAll()
        combat.strikes.removeAll()
        combat.pendingActions.removeAll()
        combat.allyAnchors.removeAll()
        // Afflictions on the horde end with a lone hero. In a party they may
        // belong to any of them, so they run their course.
        guard heroCount == 1 else { return }
        for index in combat.enemies.statusMask.indices {
            combat.enemies.statusMask[index] = 0
        }
    }

    mutating func flush() {
        ActionExecutor.flush(&combat, player: &player)
        if !combat.partyEffects.isEmpty {
            dispatchPartyEffects()
        }
    }

    /// Hands over everything that happened since the last call.
    mutating func drainEvents() -> [CombatEvent] {
        let drained = combat.events
        combat.events.removeAll(keepingCapacity: true)
        return drained
    }

    /// Removes the dead, letting death triggers (which may kill more) run.
    mutating func resolveDeaths() {
        var rounds = 0
        while rounds < 4, combat.removeDefeatedEnemies() {
            rounds += 1
            combat.rebuildGrid()
            flush()
        }
    }

    mutating func updateEnemyScaling() {
        let minutes = elapsed / 60
        let scaling = tuning.progression
        let curse = combat.curseRemaining > 0 ? ShrineTuning.curseStrength : 1
        let crowd = 1 + tuning.party.enemyHealthPerExtraHero * Double(max(0, heroCount - 1))
        combat.enemyHealthScale = (1 + scaling.enemyHealthPerMinute * minutes
            + scaling.enemyHealthPerMinuteSquared * minutes * minutes) * curse * crowd
        combat.enemyDamageScale = (1 + scaling.enemyDamagePerMinute * minutes) * curse
    }

    mutating func tickTimers(_ dt: TimeInterval) {
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

    mutating func updateConditions() {
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

    mutating func syncPlayerSnapshot() {
        combat.playerPosition = player.position
        combat.playerFacing = player.facing
        combat.playerStealthed = player.isStealthed
    }

    // MARK: - Stats

    struct StatSignature: Equatable {
        var conditions: UInt64
        var buffs: Int
        var level: Int
        var form: FormID?
        var build: Int
        var weapon: Int
    }

    /// Recomputes the player's stats when anything feeding them has changed.
    mutating func refreshStats(force: Bool = false) {
        var mask: UInt64 = 0
        for (index, conditional) in combat.build.conditionals.enumerated() where index < 64 {
            if combat.conditions.holds(conditional.condition) {
                mask |= 1 << UInt64(index)
            }
        }
        let formID = player.form ?? combat.build.permanentForm
        let signature = StatSignature(conditions: mask, buffs: player.buffsVersion, level: progression.level,
                                      form: formID, build: buildVersion, weapon: weaponVersion)
        guard force || signature != statSignature else { return }
        statSignature = signature

        var sheet = combat.sheet
        sheet.reset()
        let baseHealth = tuning.player.baseMaxHealth - StatID.maxHealth.baseValue
        let levelHealth = tuning.progression.healthPerLevel * Double(progression.level - 1)
        sheet.add(StatModifier(.maxHealth, .flat, baseHealth + levelHealth))
        sheet.add(legacy)
        if let wielded {
            sheet.add(wielded.modifiers)
        }
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

    mutating func applyHealing(_ dt: TimeInterval) {
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

    mutating func castAbilities(_ intent: PlayerIntent) {
        guard intent.abilityPresses != 0 else { return }
        for slot in 0..<AbilitySlots.count where intent.pressed(slot) {
            guard let id = abilitySlots[slot], let learned = combat.build.abilities[id] else { continue }
            guard (combat.abilityCooldowns[id] ?? 0) <= 0 else { continue }
            cast(learned)
        }
    }

    mutating func cast(_ learned: LearnedAbility) {
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

    mutating func queueCast(_ action: EffectAction, ability: AbilityID) {
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

    mutating func fireIntervalProcs(_ dt: TimeInterval) {
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

    mutating func gainExperience() {
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

    mutating func levelUp() {
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

    mutating func rebuild() {
        combat.install(CompiledBuild.compile(allocation, relics: relics))
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
    mutating func syncAuras() {
        combat.zones.removeAll { $0.isAura }
        let context = QueuedAction(action: .all([]), origin: player.position, targetID: nil, direction: .zero,
                                   depth: 0, ability: nil)
        for aura in combat.build.auras {
            ActionExecutor.place(aura, context, &combat, player, isAura: true)
        }
    }

    // MARK: - Relics

    /// Opens a find for the player to choose from. A find that opens on top
    /// of another waits its turn rather than replacing it.
    ///
    /// - Returns: false if an offer is already open, or nothing is left to offer.
    @discardableResult
    mutating func openOffer(tier: LootTier) -> Bool {
        guard offer == nil, !player.isDefeated else { return false }
        var dealt = RelicRoller.offer(tier: tier, wave: waves.state.index, inventory: relics, wielding: weapon.id,
                                      random: &combat.lootRandom)
        guard !dealt.choices.isEmpty else { return false }
        dealt.rerollsLeft += bonusRerolls
        offer = dealt
        return true
    }

    /// Carries out the bargains the player has walked onto.
    mutating func carryOutShrines() {
        guard !combat.pendingShrines.isEmpty else { return }
        let taken = combat.pendingShrines
        combat.pendingShrines.removeAll()
        for kind in taken {
            switch kind {
            case .blood:
                player.health = max(1, player.health - player.maxHealth * ShrineTuning.bloodCost)
                combat.pendingFinds.append(.chest)
            case .fortune:
                let experience = Int((Double(progression.required) * ShrineTuning.fortuneExperience).rounded())
                combat.dropExperience(max(1, experience), at: player.position)
                combat.pendingHealing += player.maxHealth * ShrineTuning.fortuneHeal
            case .ruin:
                combat.curseRemaining = ShrineTuning.curseSeconds
                combat.pendingFinds.append(.hoard)
            }
        }
    }

    /// Opens the oldest chest waiting, once the last find has been answered.
    mutating func openNextFind() {
        guard offer == nil, let tier = combat.pendingFinds.first else { return }
        combat.pendingFinds.removeFirst()
        openOffer(tier: tier)
    }

    /// Takes one of the cards on offer and closes the find.
    @discardableResult
    mutating func chooseRelic(at index: Int) -> Bool {
        guard let current = offer, current.choices.indices.contains(index) else { return false }
        offer = nil
        grantRelic(current.choices[index])
        return true
    }

    /// Takes the weapon on offer, in place of the one in the hand, and
    /// closes the find.
    @discardableResult
    mutating func chooseWeapon() -> Bool {
        guard let current = offer, let find = current.weapon, let definition = find.definition else { return false }
        offer = nil
        weapon = definition
        wielded = find
        weaponVersion += 1
        combat.stats.weaponsWielded += 1
        weaponSystem = WeaponSystem(weapon: definition, tuning: tuning.combat,
                                    growthPerLevel: tuning.progression.damageGrowthPerLevel)
        refreshStats(force: true)
        combat.events.append(.weaponWielded(title: find.title, rarity: find.rarity))
        return true
    }

    /// Spends the offer's reroll on a fresh set of cards.
    @discardableResult
    mutating func rerollOffer() -> Bool {
        guard var current = offer else { return false }
        guard RelicRoller.reroll(&current, inventory: relics, random: &combat.lootRandom) else { return false }
        offer = current
        return true
    }

    /// Puts a relic in the pack and rebuilds what it changes.
    mutating func grantRelic(_ choice: RelicChoice) {
        let rank = relics.add(choice.relic, rank: choice.rank)
        guard rank > 0 else { return }
        combat.stats.relicsTaken += 1
        rebuild()
        combat.events.append(.relicGained(id: choice.relic, rank: rank))
    }

    // MARK: - Developer commands

    /// Developer tooling: jump straight to the next wave.
    mutating func skipWave() {
        waves.skipToNextWave(&combat)
        spawner.wave = waves.state.index
    }

    /// Developer tooling and tests: leaves a drop at the player's feet, or
    /// `offset` world units away from them.
    mutating func spawnDrop(_ kind: DropKind, offset: CGPoint = .zero) {
        combat.place(kind, near: world.wrap(player.position + offset), scatter: 0)
    }

    /// Developer tooling and tests: raises a shrine `offset` world units from
    /// the player.
    mutating func spawnShrine(_ kind: ShrineKind, offset: CGPoint = .zero) {
        combat.shrines.append(Shrine(id: combat.makeEntityID(), kind: kind,
                                     position: world.wrap(player.position + offset)))
    }

    /// Seconds left on a Shrine of Ruin's curse; zero when none.
    var curseRemaining: Double { combat.curseRemaining }

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
