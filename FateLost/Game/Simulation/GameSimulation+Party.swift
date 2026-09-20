import CoreGraphics
import Foundation

/// Everything that lets one `GameSimulation` carry a party of up to four
/// heroes.
///
/// The simulation was written around a single hero, and that stays true: its
/// systems, skills and stats all speak of "the player". A party is held by
/// keeping one hero *live* in the ordinary fields and the others in `slots`,
/// and swapping when the simulation turns to another (`activate`). The swap
/// only moves references, and with one hero there is nothing to swap, so
/// every existing rule keeps working untouched and a solo run is unchanged.
///
/// What is shared (the horde, the wave clock, drops, shrines, the revive
/// markers) lives once. What belongs to a hero (their build, stats, summons,
/// zones, weapon, progression and finds) is theirs alone.
extension GameSimulation {
    /// One hero's state while another is live.
    struct HeroSlot {
        var player: PlayerState
        var progression: ProgressionState
        var allocation: SkillAllocation
        var abilitySlots: [AbilityID?]
        var buildVersion: Int
        var relics: RelicInventory
        var wielded: WeaponFind?
        var weapon: WeaponDefinition
        var weaponVersion: Int
        var weaponSystem: WeaponSystem
        var offer: RelicOffer?
        var statSignature: StatSignature?
        var alliesNeedSync: Bool
        var timeSinceDefeat: TimeInterval?
        var legacy: [StatModifier]
        var bonusRerolls: Int
        var combat: HeroCombat
    }

    /// The properties that belong to a hero and are swapped by `exchange`.
    static let heroFieldNames: [String] = [
        "weapon", "legacy", "bonusRerolls", "player", "timeSinceDefeat", "progression", "allocation",
        "abilitySlots", "buildVersion", "relics", "wielded", "weaponVersion", "offer", "weaponSystem",
        "statSignature", "alliesNeedSync",
    ]

    /// Everything else: shared by the party, or bookkeeping about it. (`combat`
    /// is split field by field, see `CombatState.heroFieldNames`.)
    static let sharedFieldNames: [String] = [
        "run", "realm", "arena", "tuning", "combat", "elapsed", "cheats", "slots", "activeHero", "members",
        "timeSinceWipe", "stepCounter", "spawnFocusScratch", "targetScratch", "movement", "spawner", "enemyAI",
        "waves", "projectileSystem", "statusSystem", "shrineWave",
    ]

    // MARK: - Building a party

    /// A run for a party. The first entry is the host's hero and must use
    /// the weapon the run was configured with.
    init(run: RunConfiguration, tuning: GameTuning, party: [PartyHeroConfig]) {
        precondition(!party.isEmpty && party.count <= PartyTuning.maximumHeroes,
                     "a party is one to four heroes")
        self.init(run: run, tuning: tuning, legacy: party[0].legacy, bonusRerolls: party[0].bonusRerolls)
        members[0] = PartyMember(id: party[0].id, name: party[0].name, slot: party[0].slot)
        guard party.count > 1 else { return }

        slots = [HeroSlot(player: player, progression: progression, allocation: allocation,
                          abilitySlots: abilitySlots, buildVersion: buildVersion, relics: relics, wielded: wielded,
                          weapon: weapon, weaponVersion: weaponVersion, weaponSystem: weaponSystem, offer: offer,
                          statSignature: statSignature, alliesNeedSync: alliesNeedSync,
                          timeSinceDefeat: timeSinceDefeat, legacy: legacy, bonusRerolls: bonusRerolls,
                          combat: HeroCombat(seed: 0))]
        for config in party.dropFirst() {
            addHero(config)
        }
        combat.isParty = true
        spreadTheParty()
    }

    /// Adds a hero, level one, with their own build and stats.
    private mutating func addHero(_ config: PartyHeroConfig) {
        let index = slots.count
        let weapon = StarterWeapons.definition(for: config.weaponID) ?? StarterWeapons.sword
        // Each hero draws from a random stream of their own.
        let seed = run.seed ^ 0xC0_4BA7 ^ (UInt64(index) &* 0x9E37_79B9_7F4A_7C15)
        slots.append(HeroSlot(
            player: PlayerState(position: arena.playerSpawn, maxHealth: tuning.player.baseMaxHealth),
            progression: ProgressionState(required: tuning.progression.requirement(toAdvanceFrom: 1)),
            allocation: SkillAllocation(),
            abilitySlots: Array(repeating: nil, count: AbilitySlots.count),
            buildVersion: 0,
            relics: RelicInventory(),
            wielded: nil,
            weapon: weapon,
            weaponVersion: 0,
            weaponSystem: WeaponSystem(weapon: weapon, tuning: tuning.combat,
                                       growthPerLevel: tuning.progression.damageGrowthPerLevel),
            offer: nil,
            statSignature: nil,
            alliesNeedSync: true,
            timeSinceDefeat: nil,
            legacy: config.legacy,
            bonusRerolls: max(0, config.bonusRerolls),
            combat: HeroCombat(seed: seed)))
        members.append(PartyMember(id: config.id, name: config.name, slot: config.slot))

        let previous = activeHero
        activate(index)
        combat.playerPosition = player.position
        refreshStats(force: true)
        player.health = player.maxHealth
        activate(previous)
    }

    /// Stands the party in a ring around the arena's spawn point.
    private mutating func spreadTheParty() {
        let count = heroCount
        let ring = tuning.party.startRingRadius
        for hero in 0..<count {
            activate(hero)
            let angle = 2 * Double.pi * Double(hero) / Double(count)
            player.position = world.wrap(arena.playerSpawn + CGPoint(x: CGFloat(cos(angle)) * ring,
                                                                    y: CGFloat(sin(angle)) * ring))
            combat.playerPosition = player.position
        }
        activate(0)
    }

    // MARK: - Swapping

    var heroCount: Int { max(1, slots.count) }

    /// Swaps every per-hero field with a slot's.
    mutating func exchange(with slot: inout HeroSlot) {
        swap(&player, &slot.player)
        swap(&progression, &slot.progression)
        swap(&allocation, &slot.allocation)
        swap(&abilitySlots, &slot.abilitySlots)
        swap(&buildVersion, &slot.buildVersion)
        swap(&relics, &slot.relics)
        swap(&wielded, &slot.wielded)
        swap(&weapon, &slot.weapon)
        swap(&weaponVersion, &slot.weaponVersion)
        swap(&weaponSystem, &slot.weaponSystem)
        swap(&offer, &slot.offer)
        swap(&statSignature, &slot.statSignature)
        swap(&alliesNeedSync, &slot.alliesNeedSync)
        swap(&timeSinceDefeat, &slot.timeSinceDefeat)
        swap(&legacy, &slot.legacy)
        swap(&bonusRerolls, &slot.bonusRerolls)
        combat.exchangeHero(with: &slot.combat)
    }

    /// Makes a hero the live one.
    mutating func activate(_ hero: Int) {
        guard hero != activeHero, slots.indices.contains(hero) else { return }
        // Park the live hero in their own slot (taking the stale entry out),
        // then bring the requested hero in. The slot is lifted out of the
        // array for the swap, because a method that mutates the simulation
        // cannot also hold an element of `slots`. Lifting copies only
        // references, and each is released again as the slot is put back.
        var outgoing = slots[activeHero]
        exchange(with: &outgoing)
        slots[activeHero] = outgoing
        var incoming = slots[hero]
        exchange(with: &incoming)
        slots[hero] = incoming
        activeHero = hero
        combat.activeHero = hero
    }

    /// Runs `body` with a hero live, then puts the previous hero back.
    @discardableResult
    mutating func perform<T>(as hero: Int, _ body: (inout GameSimulation) -> T) -> T {
        let previous = activeHero
        activate(hero)
        let result = body(&self)
        activate(previous)
        return result
    }

    /// A hero's body, wherever it currently lives.
    func playerState(of hero: Int) -> PlayerState {
        if hero == activeHero || slots.isEmpty { return player }
        return slots[hero].player
    }

    // MARK: - Reading the party

    func heroSummary(_ hero: Int) -> HeroSummary {
        let state = playerState(of: hero)
        let live = hero == activeHero || slots.isEmpty
        let member = members[hero]
        let level = live ? progression.level : slots[hero].progression.level
        let held = live ? weapon : slots[hero].weapon
        let permanent = live ? combat.build.permanentForm : slots[hero].combat.build.permanentForm
        return HeroSummary(index: hero, id: member.id, name: member.name, slot: member.slot,
                           position: state.position, velocity: state.velocity, facing: state.facing,
                           health: state.health, maxHealth: state.maxHealth, barrier: state.barrier,
                           isDefeated: state.isDefeated, isInvulnerable: state.isInvulnerable,
                           isStealthed: state.isStealthed, isSheltered: isSheltered(hero),
                           isConnected: member.isConnected && !member.isGone, level: level,
                           weaponSprite: held.spriteID, form: state.form ?? permanent)
    }

    var heroSummaries: [HeroSummary] {
        (0..<heroCount).map { heroSummary($0) }
    }

    /// Where the fallen lie.
    var reviveMarkers: [ReviveMarker] { combat.reviveMarkers }

    /// Every hero has fallen, or is gone for good.
    var isPartyWiped: Bool {
        (0..<heroCount).allSatisfy { isOut($0) }
    }

    /// Whether a hero can no longer take part: fallen, or gone, or away for
    /// so long that the party carries on without them.
    func isOut(_ hero: Int) -> Bool {
        let member = members[hero]
        if playerState(of: hero).isDefeated || member.isGone { return true }
        return heroCount > 1 && !member.isConnected && member.awaySeconds >= tuning.party.disconnectGraceSeconds
    }

    /// Who is protected right now: in a menu, or away and expected back.
    func isSheltered(_ hero: Int) -> Bool {
        guard heroCount > 1, members.indices.contains(hero) else { return false }
        let member = members[hero]
        if member.isGone { return false }
        if member.menuOpen { return true }
        return !member.isConnected && member.awaySeconds < tuning.party.disconnectGraceSeconds
    }

    /// A player has opened or closed a menu. The game goes on around them,
    /// so their hero is sheltered (for a while) instead.
    mutating func setMenuOpen(_ open: Bool, forHero hero: Int) {
        guard members.indices.contains(hero), members[hero].menuOpen != open else { return }
        members[hero].menuOpen = open
        members[hero].menuSeconds = 0
    }

    mutating func setConnected(_ connected: Bool, forHero hero: Int) {
        guard members.indices.contains(hero) else { return }
        members[hero].isConnected = connected
        if connected {
            members[hero].awaySeconds = 0
        }
    }

    /// A player has left the party. Their hero goes, and any marker with it.
    mutating func removeHero(_ hero: Int) {
        guard members.indices.contains(hero), !members[hero].isGone else { return }
        members[hero].isGone = true
        members[hero].isConnected = false
        combat.reviveMarkers.removeAll { $0.hero == hero }
        perform(as: hero) { sim in
            sim.player.health = 0
            sim.dismissPlayerForces()
        }
    }

    /// Time every effect in the party has been ticking: shelter for menus and
    /// for the disconnected.
    mutating func updateShelters(_ dt: TimeInterval) {
        guard heroCount > 1 else { return }
        for hero in 0..<heroCount {
            if members[hero].menuOpen {
                members[hero].menuSeconds += dt
                if members[hero].menuSeconds >= tuning.party.menuShelterSeconds {
                    members[hero].menuOpen = false
                    members[hero].menuSeconds = 0
                }
            }
            if members[hero].isConnected {
                members[hero].awaySeconds = 0
            } else {
                members[hero].awaySeconds += dt
            }
        }
    }

    // MARK: - The world's view of the party

    /// The hero placement things should be measured from: the first who is
    /// standing, or the first there is.
    func referencePlayer() -> PlayerState {
        for hero in 0..<heroCount where members[hero].stepAlive {
            return playerState(of: hero)
        }
        return playerState(of: 0)
    }

    /// More heroes standing means more arrivals.
    func partySpawnFactor() -> Double {
        let standing = max(1, members.filter { $0.stepAlive }.count)
        return 1 + tuning.party.spawnRatePerExtraHero * Double(standing - 1)
    }

    /// Who the spawner should place arrivals around: the heroes standing,
    /// or every hero if none is.
    mutating func collectSpawnFocuses(anyAlive: Bool) {
        spawnFocusScratch.removeAll(keepingCapacity: true)
        for hero in 0..<heroCount where !anyAlive || members[hero].stepAlive {
            spawnFocusScratch.append(SpawnFocus(playerState(of: hero)))
        }
    }

    /// Each hero as the horde sees them.
    mutating func collectTargets() {
        targetScratch.removeAll(keepingCapacity: true)
        for hero in 0..<heroCount {
            let state = playerState(of: hero)
            targetScratch.append(AITarget(position: state.position, isAlive: !state.isDefeated,
                                          isHidden: state.isStealthed || isSheltered(hero), hero: hero))
        }
    }

    /// Every hero's summons in one list, tagged with whose they are.
    mutating func gatherWorldAnchors() {
        combat.worldAnchors.removeAll(keepingCapacity: true)
        for hero in 0..<heroCount {
            let anchors = hero == activeHero || slots.isEmpty ? combat.allyAnchors : slots[hero].combat.allyAnchors
            for var anchor in anchors {
                anchor.hero = hero
                combat.worldAnchors.append(anchor)
            }
        }
    }

    /// Carries out what the horde did this step, each blow in the context of
    /// the hero it fell on.
    mutating func carryOutIncidents() {
        guard !combat.incidents.isEmpty else { return }
        let incidents = combat.incidents
        combat.incidents.removeAll(keepingCapacity: true)
        let previous = activeHero
        for incident in incidents {
            switch incident {
            case let .strikeHero(hero, amount, direction):
                activate(hero)
                guard !player.isDefeated else { continue }
                combat.strikePlayer(&player, amount: amount, direction: direction, godMode: cheats.godMode)
                // What a blow sets off (a barrier, a counter) happens now.
                flush()
            case let .woundAlly(hero, index, id, amount):
                activate(hero)
                guard index < combat.allies.count, combat.allies[index].id == id else { continue }
                AllySystem.wound(index, amount: amount, &combat)
            }
        }
        activate(previous)
    }

    /// A hero who fell this step drops what they were doing, and leaves a
    /// marker where they lie.
    mutating func registerFallenHeroes() {
        let previous = activeHero
        for hero in 0..<heroCount where !members[hero].isGone {
            guard playerState(of: hero).isDefeated else { continue }
            if heroCount > 1 {
                // The marker is the record that a fall has been dealt with.
                guard !combat.reviveMarkers.contains(where: { $0.hero == hero }) else { continue }
            } else {
                // A lone hero's fall is dealt with once: on the step it happens.
                guard members[hero].stepAlive else { continue }
            }
            activate(hero)
            dismissPlayerForces()
            if heroCount > 1 {
                combat.reviveMarkers.append(ReviveMarker(hero: hero, position: player.position))
                combat.events.append(.heroFell(hero: hero, position: player.position))
            }
        }
        activate(previous)
    }

    // MARK: - Blessings

    /// Delivers heals, shields and auras to the friends they reach.
    mutating func dispatchPartyEffects() {
        let effects = combat.partyEffects
        combat.partyEffects.removeAll(keepingCapacity: true)
        guard heroCount > 1 else { return }
        let previous = activeHero
        for effect in effects {
            for hero in 0..<heroCount where hero != effect.source {
                let candidate = playerState(of: hero)
                let relation = Relations.between(effect.source, hero, otherIsDefeated: candidate.isDefeated)
                guard effect.rule.permits(relation),
                      world.distance(candidate.position, effect.center) <= effect.radius else { continue }
                activate(hero)
                deliver(effect.kind)
            }
        }
        activate(previous)
    }

    private mutating func deliver(_ kind: PartyEffect.Kind) {
        switch kind {
        case .heal(let fraction):
            let amount = fraction * player.maxHealth
            combat.pendingHealing += amount
            if amount >= 1 {
                combat.events.append(.playerHealed(amount: amount * combat.sheet[.healingReceived]))
            }
        case .barrier(let fraction):
            player.barrier = min(player.maxHealth, player.barrier + fraction * player.maxHealth)
            combat.events.append(.barrierGained)
        case let .buff(id, modifiers, duration):
            player.applyBuff(id: id, modifiers: modifiers, duration: duration, maxStacks: 1)
        }
    }

    // MARK: - Experience

    /// What any hero gathers, all of them gain: the party levels together.
    mutating func shareExperience() {
        var total = 0
        for hero in 0..<heroCount where !members[hero].isGone {
            total += hero == activeHero ? combat.experienceCollected : slots[hero].combat.experienceCollected
        }
        guard total > 0 else { return }
        for hero in 0..<heroCount {
            if hero == activeHero {
                combat.experienceCollected = total
            } else {
                slots[hero].combat.experienceCollected = total
            }
        }
    }

    // MARK: - Reviving

    /// Advances every revive channel: starts one when a friend beside a
    /// marker asks, breaks it if the reviver is struck, walks away or falls,
    /// and finishes it when the time is up.
    mutating func stepRevives(dt: TimeInterval) {
        guard !combat.reviveMarkers.isEmpty else { return }
        let rules = tuning.party
        var index = combat.reviveMarkers.count - 1
        while index >= 0 {
            var marker = combat.reviveMarkers[index]
            marker.age += dt

            if let reviverIndex = marker.reviver {
                let reviver = playerState(of: reviverIndex)
                let struck = reviver.hitsTaken != marker.hitsAtStart
                let away = world.distance(reviver.position, marker.position) > rules.reviveHoldRange
                if reviver.isDefeated || struck || away || members[reviverIndex].isGone {
                    marker.reviver = nil
                    marker.progress = 0
                    combat.events.append(.reviveInterrupted(hero: marker.hero))
                }
            }

            if marker.reviver == nil {
                for candidate in 0..<heroCount where candidate != marker.hero && members[candidate].intent.interact {
                    let state = playerState(of: candidate)
                    guard !state.isDefeated, !members[candidate].isGone,
                          world.distance(state.position, marker.position) <= rules.reviveStartRange,
                          !combat.reviveMarkers.contains(where: { $0.reviver == candidate }) else { continue }
                    marker.reviver = candidate
                    marker.progress = 0
                    marker.hitsAtStart = state.hitsTaken
                    combat.events.append(.reviveStarted(hero: marker.hero, reviver: candidate))
                    break
                }
            }

            if marker.reviver != nil {
                marker.progress += dt / max(rules.reviveSeconds, 0.1)
                if marker.progress >= 1 {
                    combat.reviveMarkers.remove(at: index)
                    revive(marker.hero, at: marker.position)
                    index -= 1
                    continue
                }
            }
            combat.reviveMarkers[index] = marker
            index -= 1
        }
    }

    /// Brings a fallen hero back. Only one revive can ever take effect: a hero
    /// who is already standing is left alone.
    mutating func revive(_ hero: Int, at position: CGPoint) {
        guard members.indices.contains(hero), !members[hero].isGone else { return }
        guard playerState(of: hero).isDefeated else { return }
        let rules = tuning.party
        perform(as: hero) { sim in
            sim.player.health = max(1, sim.player.maxHealth * rules.reviveHealthFraction)
            sim.player.barrier = 0
            sim.player.position = position
            sim.player.velocity = .zero
            sim.player.knockback = .zero
            sim.player.stealth = 0
            sim.player.invulnerability = max(sim.player.invulnerability, rules.reviveInvulnerability)
            sim.player.buffs.removeAll()
            sim.player.buffsVersion &+= 1
            sim.timeSinceDefeat = nil
            sim.alliesNeedSync = true
            sim.syncPlayerSnapshot()
            sim.combat.events.append(.heroRevived(hero: hero, position: position))
            // What was earned while down is paid out now.
            let banked = sim.members[hero].bankedExperience
            if banked > 0 {
                sim.members[hero].bankedExperience = 0
                sim.combat.experienceCollected = banked
                sim.gainExperience()
            }
        }
    }

    // MARK: - Events

    /// Hands over every hero's events, tagged with whose they are. A
    /// world event (an enemy struck, a wave began) is tagged with whichever
    /// hero was live when it happened; `CombatEvent.isPersonal` says which
    /// events belong only to their hero.
    mutating func drainPartyEvents() -> [(hero: Int, event: CombatEvent)] {
        var result: [(hero: Int, event: CombatEvent)] = []
        for hero in 0..<heroCount {
            if hero == activeHero || slots.isEmpty {
                for event in combat.events {
                    result.append((hero, event))
                }
                combat.events.removeAll(keepingCapacity: true)
            } else {
                for event in slots[hero].combat.events {
                    result.append((hero, event))
                }
                slots[hero].combat.events.removeAll(keepingCapacity: true)
            }
        }
        return result
    }
}
