import CoreGraphics
import XCTest
@testable import FateLost

/// Helpers for building parties and poking at them.
private enum Party {
    static let dt: TimeInterval = 1.0 / 60
    static let names = ["Jesse", "Whitney", "Kevin", "Robin"]

    static func make(_ count: Int, seed: UInt64 = 7, legacy: [[StatModifier]] = []) -> GameSimulation {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: seed)
        let party = (0..<count).map { index in
            PartyHeroConfig(id: "p\(index)", name: names[index], slot: index, weaponID: StarterWeapons.sword.id,
                            legacy: index < legacy.count ? legacy[index] : [])
        }
        var sim = GameSimulation(run: run, tuning: .standard, party: party)
        sim.cheats = SimulationCheats(godMode: false, spawningEnabled: false)
        return sim
    }

    static func place(_ sim: inout GameSimulation, hero: Int, at point: CGPoint) {
        sim.perform(as: hero) { simulation in
            simulation.player.position = point
            simulation.combat.playerPosition = point
        }
    }

    static func health(_ sim: GameSimulation, _ hero: Int) -> Double {
        sim.playerState(of: hero).health
    }

    static func setHealth(_ sim: inout GameSimulation, hero: Int, _ health: Double) {
        sim.perform(as: hero) { $0.player.health = health }
    }

    @discardableResult
    static func addGoblin(_ sim: inout GameSimulation, at point: CGPoint,
                          definition: EnemyDefinition = EnemyCatalog.goblin) -> Int {
        let kind = sim.combat.enemies.kindIndex(for: definition)
        let id = sim.combat.makeEntityID()
        sim.combat.enemies.append(id: id, kind: kind, position: point, speedScale: 1)
        return sim.combat.enemies.count - 1
    }

    static func run(_ sim: inout GameSimulation, seconds: Double) {
        for _ in 0..<Int((seconds * 60).rounded()) {
            sim.step(dt: dt)
        }
    }

    /// Kills a hero the way the horde would: a blow that lands.
    static func kill(_ sim: inout GameSimulation, hero: Int) {
        sim.combat.incidents.append(.strikeHero(hero: hero, amount: 100_000, direction: CGPoint(x: 1, y: 0)))
        sim.step(dt: dt)
    }

    /// Queues an action as if the hero had cast an ability.
    static func cast(_ sim: inout GameSimulation, hero: Int, _ action: EffectAction) {
        sim.perform(as: hero) { simulation in
            simulation.combat.pendingActions.append(QueuedAction(
                action: action, origin: simulation.player.position, targetID: nil, direction: CGPoint(x: 1, y: 0),
                depth: 0, ability: "test.ability"))
        }
    }

    static func events(_ sim: inout GameSimulation) -> [CombatEvent] {
        sim.drainPartyEvents().map { $0.event }
    }
}

/// The per-hero swap is what lets a single-hero simulation carry a party, so
/// nothing may be left out of it.
final class PartyHeroSwapTests: XCTestCase {
    private func names<T>(of value: T) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap { $0.label })
    }

    func testEveryCombatFieldIsEitherAHeroFieldOrShared() {
        let combat = CombatState(world: ToroidalWorld(width: 64, height: 64), tuning: CombatTuning(),
                                 gridCellSize: 1.5, capacity: 8, seed: 1)
        let expected = Set(CombatState.heroFieldNames + CombatState.sharedFieldNames)
        XCTAssertEqual(names(of: combat), expected,
                       "a stored property of CombatState was added or removed without being classified")
        XCTAssertEqual(Set(CombatState.heroFieldNames).intersection(CombatState.sharedFieldNames), [])
    }

    func testTheHeroCombatSlotHoldsExactlyTheHeroFields() {
        XCTAssertEqual(names(of: HeroCombat(seed: 1)), Set(CombatState.heroFieldNames))
    }

    func testEverySimulationFieldIsEitherAHeroFieldOrShared() {
        let sim = Party.make(2)
        let expected = Set(GameSimulation.heroFieldNames + GameSimulation.sharedFieldNames)
        XCTAssertEqual(names(of: sim), expected,
                       "a stored property of GameSimulation was added or removed without being classified")
        XCTAssertEqual(Set(GameSimulation.heroFieldNames).intersection(GameSimulation.sharedFieldNames), [])
    }

    func testTheHeroSlotHoldsExactlyTheHeroFields() {
        let sim = Party.make(2)
        let slot = sim.slots[1]
        XCTAssertEqual(names(of: slot), Set(GameSimulation.heroFieldNames + ["combat"]))
    }

    func testEachHeroKeepsTheirOwnBuildAndStatsAcrossSwaps() {
        var sim = Party.make(3, legacy: [[], [StatModifier(.maxHealth, .flat, 50)], [StatModifier(.maxHealth, .flat, 100)]])
        XCTAssertEqual(sim.heroSummary(0).maxHealth, 100, accuracy: 0.001)
        XCTAssertEqual(sim.heroSummary(1).maxHealth, 150, accuracy: 0.001)
        XCTAssertEqual(sim.heroSummary(2).maxHealth, 200, accuracy: 0.001)

        sim.perform(as: 1) { $0.grantLevels(3) }
        XCTAssertEqual(sim.perform(as: 0) { $0.progression.level }, 1)
        XCTAssertEqual(sim.perform(as: 1) { $0.progression.level }, 4)
        XCTAssertEqual(sim.perform(as: 2) { $0.progression.level }, 1)
        XCTAssertEqual(sim.activeHero, 0, "perform must hand the simulation back")
        // The hero who levelled has more health than they began with.
        XCTAssertGreaterThan(sim.heroSummary(1).maxHealth, 150)
        XCTAssertEqual(sim.heroSummary(2).maxHealth, 200, accuracy: 0.001)
    }

    func testSwappingBackAndForthLosesNothing() {
        var sim = Party.make(4)
        for hero in 0..<4 {
            Party.place(&sim, hero: hero, at: CGPoint(x: 10 + Double(hero) * 7, y: 20))
            Party.setHealth(&sim, hero: hero, 30 + Double(hero))
        }
        for _ in 0..<50 {
            sim.activate(3)
            sim.activate(1)
            sim.activate(2)
            sim.activate(0)
        }
        for hero in 0..<4 {
            XCTAssertEqual(sim.playerState(of: hero).position.x, 10 + CGFloat(hero) * 7, accuracy: 0.001)
            XCTAssertEqual(sim.playerState(of: hero).health, 30 + Double(hero), accuracy: 0.001)
        }
    }

    func testASoloRunHasNothingToSwap() {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 7)
        var sim = GameSimulation(run: run, tuning: .standard)
        XCTAssertEqual(sim.heroCount, 1)
        XCTAssertTrue(sim.slots.isEmpty)
        sim.activate(0)
        sim.activate(3)
        XCTAssertEqual(sim.activeHero, 0)
        XCTAssertFalse(sim.combat.isParty)
        for _ in 0..<120 { sim.step(dt: Party.dt, intent: PlayerIntent(move: CGPoint(x: 1, y: 0))) }
        XCTAssertGreaterThan(sim.player.position.x, sim.arena.playerSpawn.x)
    }

    func testAPartyOfOneIsASoloRun() {
        let sim = Party.make(1)
        XCTAssertEqual(sim.heroCount, 1)
        XCTAssertFalse(sim.combat.isParty)
    }

    func testAPartyStandsInARingAroundTheSpawn() {
        let sim = Party.make(4)
        let centre = sim.arena.playerSpawn
        for hero in 0..<4 {
            let distance = sim.world.distance(sim.playerState(of: hero).position, centre)
            XCTAssertEqual(distance, sim.tuning.party.startRingRadius, accuracy: 0.01)
        }
        XCTAssertEqual(sim.heroSummaries.map { $0.name }, ["Jesse", "Whitney", "Kevin", "Robin"])
        XCTAssertEqual(sim.heroSummaries.map { $0.slot }, [0, 1, 2, 3])
    }
}

final class PartyRelationshipTests: XCTestCase {
    func testDamageAndBlessingsAimAtDifferentPeople() {
        XCTAssertTrue(TargetRule.hostile.permits(.enemy))
        XCTAssertFalse(TargetRule.hostile.permits(.selfHero))
        XCTAssertFalse(TargetRule.hostile.permits(.ally))
        XCTAssertFalse(TargetRule.hostile.permits(.deadAlly))

        XCTAssertTrue(TargetRule.blessing.permits(.selfHero))
        XCTAssertTrue(TargetRule.blessing.permits(.ally))
        XCTAssertFalse(TargetRule.blessing.permits(.enemy))
        XCTAssertFalse(TargetRule.blessing.permits(.deadAlly))

        XCTAssertTrue(TargetRule.resurrection.permits(.deadAlly))
        XCTAssertFalse(TargetRule.resurrection.permits(.ally))
    }

    func testRelationshipsBetweenHeroes() {
        XCTAssertEqual(Relations.between(1, 1, otherIsDefeated: false), .selfHero)
        XCTAssertEqual(Relations.between(1, 2, otherIsDefeated: false), .ally)
        XCTAssertEqual(Relations.between(1, 2, otherIsDefeated: true), .deadAlly)
    }
}

final class PartyCombatTests: XCTestCase {
    func testTheHordeChoosesTheNearestHero() {
        var sim = Party.make(2)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 30, y: 0)))
        // A goblin close to the far hero, and none near the first.
        Party.addGoblin(&sim, at: sim.world.wrap(home + CGPoint(x: 26, y: 0)))
        Party.run(&sim, seconds: 3)
        let goblin = sim.combat.enemies.positions[0]
        let toFar = sim.world.distance(goblin, sim.playerState(of: 1).position)
        let toNear = sim.world.distance(goblin, sim.playerState(of: 0).position)
        XCTAssertLessThan(toFar, 2, "it should have gone for the hero beside it")
        XCTAssertGreaterThan(toNear, 20)
        XCTAssertEqual(Party.health(sim, 0), 100, accuracy: 0.001)
    }

    func testAnAreaAbilityHurtsTheHordeAndNeverThePartyStandingInIt() {
        var sim = Party.make(3)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 1, y: 0)))
        Party.place(&sim, hero: 2, at: sim.world.wrap(home + CGPoint(x: 0, y: 1.5)))
        let index = Party.addGoblin(&sim, at: sim.world.wrap(home + CGPoint(x: 2.5, y: 0)),
                                    definition: EnemyCatalog.goblin)
        let before = sim.combat.enemies.health[index]
        let nova = NovaSpec(radius: RankValue(4),
                            damage: DamageSpec(RankValue(6), .fire, tags: [.spell, .area, .ability]),
                            status: nil, visual: .fire)
        Party.cast(&sim, hero: 0, .nova(nova))
        sim.step(dt: Party.dt)

        XCTAssertLessThan(sim.combat.enemies.health[index], before, "the enemy should have been burned")
        for hero in 0..<3 {
            XCTAssertEqual(Party.health(sim, hero), 100, accuracy: 0.001, "friendly fire must not exist")
        }
    }

    func testAHealingAbilityHealsNearbyFriendsAndNotTheHorde() {
        var sim = Party.make(4)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 3, y: 0)))
        Party.place(&sim, hero: 2, at: sim.world.wrap(home + CGPoint(x: 25, y: 0)))
        Party.place(&sim, hero: 3, at: sim.world.wrap(home + CGPoint(x: 0, y: 3)))
        for hero in 0..<3 { Party.setHealth(&sim, hero: hero, 40) }
        Party.kill(&sim, hero: 3)
        XCTAssertTrue(sim.playerState(of: 3).isDefeated)

        let index = Party.addGoblin(&sim, at: sim.world.wrap(home + CGPoint(x: 4, y: 0)),
                                    definition: Party.dummy)
        sim.combat.enemies.health[index] = 300
        Party.cast(&sim, hero: 0, .heal(RankValue(0.25)))
        sim.step(dt: Party.dt)

        XCTAssertEqual(Party.health(sim, 0), 65, accuracy: 1.5, "the caster is healed")
        XCTAssertEqual(Party.health(sim, 1), 65, accuracy: 1.5, "a friend in range is healed")
        XCTAssertEqual(Party.health(sim, 2), 40, accuracy: 0.5, "a friend out of range is not")
        XCTAssertEqual(Party.health(sim, 3), 0, accuracy: 0.001, "a fallen friend is not healed")
        XCTAssertEqual(sim.combat.enemies.health[index], 300, accuracy: 0.001, "the horde is never healed")
    }

    func testAShieldFromAnAbilityReachesFriendsToo() {
        var sim = Party.make(2)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 2, y: 0)))
        Party.cast(&sim, hero: 0, .barrier(RankValue(0.2)))
        sim.step(dt: Party.dt)
        XCTAssertEqual(sim.playerState(of: 0).barrier, 20, accuracy: 0.5)
        XCTAssertEqual(sim.playerState(of: 1).barrier, 20, accuracy: 0.5)
    }

    func testHealingFromAPassiveStaysPersonal() {
        var sim = Party.make(2)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 2, y: 0)))
        Party.setHealth(&sim, hero: 0, 40)
        Party.setHealth(&sim, hero: 1, 40)
        // A trigger (no ability behind it) heals only who it belongs to.
        sim.perform(as: 0) { simulation in
            simulation.combat.pendingActions.append(QueuedAction(
                action: .heal(RankValue(0.25)), origin: simulation.player.position, targetID: nil,
                direction: .zero, depth: 1, ability: nil))
        }
        sim.step(dt: Party.dt)
        XCTAssertEqual(Party.health(sim, 0), 65, accuracy: 1.5)
        XCTAssertEqual(Party.health(sim, 1), 40, accuracy: 0.5)
    }

    func testAHealingFieldHelpsEveryoneStandingInIt() {
        var sim = Party.make(3)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 2, y: 0)))
        Party.place(&sim, hero: 2, at: sim.world.wrap(home + CGPoint(x: 25, y: 0)))
        for hero in 0..<3 { Party.setHealth(&sim, hero: hero, 40) }
        let field = ZoneSpec(radius: RankValue(4), duration: RankValue(6), tick: 0.5,
                             playerBuff: [ModifierSpec(.healthRegen, .flat, RankValue(40))], visual: .holy)
        Party.cast(&sim, hero: 0, .zone(field))
        Party.run(&sim, seconds: 1.5)

        XCTAssertGreaterThan(Party.health(sim, 0), 60, "whoever laid it is healed")
        XCTAssertGreaterThan(Party.health(sim, 1), 60, "a friend standing in it is healed")
        XCTAssertEqual(Party.health(sim, 2), 40, accuracy: 0.5, "a friend outside it is not")
    }

    func testEnemyShotsHitTheHeroTheyReach() {
        var sim = Party.make(2)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 8, y: 0)))
        let start = sim.world.wrap(home + CGPoint(x: 4, y: 0))
        var hit = Hit(amount: 20, type: .physical, tags: [.projectile], direction: CGPoint(x: 1, y: 0))
        hit.knockback = 0
        sim.combat.hostileProjectiles.append(Projectile(
            id: sim.combat.makeEntityID(), position: start, velocity: CGPoint(x: 10, y: 0), remainingLife: 3,
            pierceRemaining: 0, hit: hit, radius: 0.25, splashRadius: 0, spriteID: .projectileBolt,
            visual: .physical, isHostile: true))
        Party.run(&sim, seconds: 1)
        XCTAssertLessThan(Party.health(sim, 1), 100)
        XCTAssertEqual(Party.health(sim, 0), 100, accuracy: 0.001)
        XCTAssertTrue(sim.combat.hostileProjectiles.isEmpty, "a shot is spent on the first hero it reaches")
    }

    func testAPartyFacesABiggerHorde() {
        var solo = Party.make(1)
        var four = Party.make(4)
        solo.step(dt: Party.dt)
        four.step(dt: Party.dt)
        XCTAssertGreaterThan(four.combat.enemyHealthScale, solo.combat.enemyHealthScale * 2)
    }

    func testExperienceGatheredByOneHeroIsEveryonesAndFallenHeroesBankIt() {
        var sim = Party.make(3)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 30, y: 0)))
        Party.place(&sim, hero: 2, at: sim.world.wrap(home + CGPoint(x: 0, y: 30)))
        Party.kill(&sim, hero: 2)

        sim.combat.orbs.append(ExperienceOrb(id: sim.combat.makeEntityID(), position: home, value: 30))
        Party.run(&sim, seconds: 1)
        let first = sim.perform(as: 0) { $0.progression.level }
        let second = sim.perform(as: 1) { $0.progression.level }
        XCTAssertGreaterThan(first, 1)
        XCTAssertEqual(first, second, "the party levels together")
        XCTAssertEqual(sim.perform(as: 2) { $0.progression.level }, 1, "a fallen hero does not level")
        XCTAssertGreaterThan(sim.members[2].bankedExperience, 0, "but what they earned is kept for them")
    }

    func testAHeroInAMenuIsShelteredAndTheGameGoesOn() {
        var sim = Party.make(2)
        let home = sim.arena.playerSpawn
        Party.kill(&sim, hero: 0)
        Party.place(&sim, hero: 1, at: home)
        Party.addGoblin(&sim, at: sim.world.wrap(home + CGPoint(x: 0.7, y: 0)))
        sim.setMenuOpen(true, forHero: 1)
        Party.run(&sim, seconds: 3)
        XCTAssertEqual(Party.health(sim, 1), 100, accuracy: 0.001, "the hero is protected while their player chooses")

        sim.setMenuOpen(false, forHero: 1)
        Party.run(&sim, seconds: 4)
        XCTAssertLessThan(Party.health(sim, 1), 100, "and then the fight finds them")
    }

    func testTheShelterEndsByItself() {
        var sim = Party.make(2)
        sim.setMenuOpen(true, forHero: 1)
        Party.run(&sim, seconds: sim.tuning.party.menuShelterSeconds + 1)
        XCTAssertFalse(sim.members[1].menuOpen)
        XCTAssertFalse(sim.isSheltered(1))
    }

    func testADisconnectedHeroIsProtectedForAWhile() {
        var sim = Party.make(2)
        sim.setConnected(false, forHero: 1)
        XCTAssertTrue(sim.isSheltered(1))
        XCTAssertFalse(sim.isOut(1))
        Party.run(&sim, seconds: sim.tuning.party.disconnectGraceSeconds + 1)
        XCTAssertFalse(sim.isSheltered(1))
        XCTAssertTrue(sim.isOut(1), "after the grace the party carries on without them")
        sim.setConnected(true, forHero: 1)
        XCTAssertFalse(sim.isOut(1))
    }

    func testEnemyAfflictionsSurviveOneHeroFalling() {
        var sim = Party.make(2)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 20, y: 0)))
        let index = Party.addGoblin(&sim, at: sim.world.wrap(home + CGPoint(x: 6, y: 0)))
        sim.combat.enemies.statusMask[index] = StatusKind.burn.bit
        sim.combat.enemies.statusTime[StatusKind.burn.rawValue][index] = 10
        Party.kill(&sim, hero: 1)
        XCTAssertNotEqual(sim.combat.enemies.statusMask[index] & StatusKind.burn.bit, 0)
    }

    func testAStressedPartyOfFourKeepsRunning() {
        var sim = Party.make(4)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: true)
        sim.spawnEnemies(150)
        for step in 0..<600 {
            var intent = PlayerIntent(move: CGPoint(x: step % 2 == 0 ? 1 : -1, y: 0))
            intent.abilityPresses = 0b0111
            for hero in 0..<4 { sim.setIntent(intent, forHero: hero) }
            sim.step(dt: Party.dt)
        }
        XCTAssertGreaterThan(sim.enemies.count, 0)
        XCTAssertEqual(sim.activeHero, 0)
        XCTAssertFalse(sim.isPartyWiped)
    }
}

extension Party {
    /// An enemy that stands still and does nothing, for tests about healing.
    static let dummy = EnemyDefinition(
        id: "test.party.dummy", name: "Dummy", family: .goblinoid, maxHealth: 1000, moveSpeed: 0, radius: 0.3,
        attackDamage: 0, attackReach: 0, attackWindup: 1, attackCooldown: 1000, knockbackResistance: 1,
        damageType: .physical, behavior: .melee, experience: 0, spawnWeight: 0, earliestWave: 1,
        spriteVariants: [.enemyGoblin]
    )
}

final class PartyDeathAndReviveTests: XCTestCase {
    private func partyOfThree() -> GameSimulation {
        var sim = Party.make(3)
        let home = sim.arena.playerSpawn
        Party.place(&sim, hero: 0, at: home)
        Party.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 3, y: 0)))
        Party.place(&sim, hero: 2, at: sim.world.wrap(home + CGPoint(x: 0, y: 3)))
        return sim
    }

    private func press(_ sim: inout GameSimulation, hero: Int) {
        var intent = sim.members[hero].intent
        intent.interact = true
        sim.setIntent(intent, forHero: hero)
    }

    func testAFallenHeroLeavesAMarkerWhereTheyLay() {
        var sim = partyOfThree()
        let spot = sim.playerState(of: 1).position
        Party.kill(&sim, hero: 1)
        XCTAssertTrue(sim.playerState(of: 1).isDefeated)
        XCTAssertEqual(sim.reviveMarkers.count, 1)
        let marker = sim.reviveMarkers[0]
        XCTAssertEqual(marker.hero, 1)
        XCTAssertEqual(marker.position.x, spot.x, accuracy: 0.5)
        XCTAssertEqual(marker.position.y, spot.y, accuracy: 0.5)
        XCTAssertNil(marker.reviver)
        XCTAssertTrue(Party.events(&sim).contains {
            if case .heroFell(let hero, _) = $0 { return hero == 1 } else { return false }
        })
    }

    func testTheMarkerIsMadeOnlyOnce() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        Party.run(&sim, seconds: 2)
        XCTAssertEqual(sim.reviveMarkers.count, 1)
    }

    func testOneFallenHeroDoesNotEndTheRun() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        Party.run(&sim, seconds: 1)
        XCTAssertFalse(sim.isPartyWiped)
        XCTAssertNil(sim.timeSinceWipe)
        XCTAssertFalse(sim.playerState(of: 0).isDefeated)
    }

    func testAFallenHeroDoesNotMoveOrFight() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        let where1 = sim.playerState(of: 1).position
        for _ in 0..<60 {
            sim.setIntent(PlayerIntent(move: CGPoint(x: 1, y: 0)), forHero: 1)
            sim.step(dt: Party.dt)
        }
        XCTAssertEqual(sim.playerState(of: 1).position.x, where1.x, accuracy: 0.01)
    }

    func testTheHordeIgnoresAFallenHero() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        // A goblin beside the body and none near the living.
        Party.place(&sim, hero: 0, at: sim.world.wrap(sim.arena.playerSpawn + CGPoint(x: 40, y: 0)))
        Party.place(&sim, hero: 2, at: sim.world.wrap(sim.arena.playerSpawn + CGPoint(x: 0, y: 40)))
        let corpse = sim.playerState(of: 1).position
        Party.addGoblin(&sim, at: sim.world.wrap(corpse + CGPoint(x: 1, y: 0)))
        Party.run(&sim, seconds: 3)
        XCTAssertEqual(sim.playerState(of: 1).health, 0, accuracy: 0.001)
        XCTAssertEqual(sim.reviveMarkers.count, 1, "a marker is not a target")
    }

    func testAFriendNextToTheMarkerCanBeginAndFinishARevive() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        let marker = sim.reviveMarkers[0].position
        Party.place(&sim, hero: 0, at: sim.world.wrap(marker + CGPoint(x: 1, y: 0)))
        _ = Party.events(&sim)

        press(&sim, hero: 0)
        sim.step(dt: Party.dt)
        XCTAssertEqual(sim.reviveMarkers.first?.reviver, 0)
        XCTAssertTrue(Party.events(&sim).contains {
            if case .reviveStarted(let hero, let reviver) = $0 { return hero == 1 && reviver == 0 } else { return false }
        })

        // Not done yet, half way through.
        Party.run(&sim, seconds: sim.tuning.party.reviveSeconds / 2)
        XCTAssertTrue(sim.playerState(of: 1).isDefeated)
        XCTAssertEqual(sim.reviveMarkers.first?.progress ?? 0, 0.5, accuracy: 0.05)

        // Done.
        Party.run(&sim, seconds: sim.tuning.party.reviveSeconds / 2 + 0.2)
        let back = sim.playerState(of: 1)
        XCTAssertFalse(back.isDefeated)
        XCTAssertTrue(sim.reviveMarkers.isEmpty)
        XCTAssertEqual(back.health, back.maxHealth * sim.tuning.party.reviveHealthFraction, accuracy: 2)
        XCTAssertGreaterThan(back.invulnerability, 0, "a moment of grace so they are not struck straight down")
        XCTAssertTrue(Party.events(&sim).contains {
            if case .heroRevived(let hero, _) = $0 { return hero == 1 } else { return false }
        })
    }

    func testARevivedHeroFightsAgainAndKeepsTheirBuild() {
        var sim = partyOfThree()
        sim.perform(as: 1) { $0.grantLevels(2) }
        let level = sim.perform(as: 1) { $0.progression.level }
        Party.kill(&sim, hero: 1)
        let marker = sim.reviveMarkers[0].position
        Party.place(&sim, hero: 0, at: marker)
        press(&sim, hero: 0)
        Party.run(&sim, seconds: sim.tuning.party.reviveSeconds + 0.3)
        XCTAssertFalse(sim.playerState(of: 1).isDefeated)
        XCTAssertEqual(sim.perform(as: 1) { $0.progression.level }, level)

        sim.setIntent(PlayerIntent(move: CGPoint(x: 1, y: 0)), forHero: 1)
        let from = sim.playerState(of: 1).position.x
        Party.run(&sim, seconds: 1)
        XCTAssertGreaterThan(sim.world.delta(from: CGPoint(x: from, y: 0), to: CGPoint(x: sim.playerState(of: 1).position.x, y: 0)).x, 1)
    }

    func testBeingStruckWhileReviveBreaksTheChannel() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        let marker = sim.reviveMarkers[0].position
        Party.place(&sim, hero: 0, at: sim.world.wrap(marker + CGPoint(x: 1, y: 0)))
        press(&sim, hero: 0)
        Party.run(&sim, seconds: 1.5)
        XCTAssertNotNil(sim.reviveMarkers[0].reviver)
        XCTAssertGreaterThan(sim.reviveMarkers[0].progress, 0.3)
        _ = Party.events(&sim)

        // The reviver is hit.
        sim.combat.incidents.append(.strikeHero(hero: 0, amount: 5, direction: CGPoint(x: 1, y: 0)))
        sim.step(dt: Party.dt)
        XCTAssertNil(sim.reviveMarkers[0].reviver, "the channel is broken")
        XCTAssertEqual(sim.reviveMarkers[0].progress, 0, accuracy: 0.0001, "and the progress is lost")
        XCTAssertTrue(sim.playerState(of: 1).isDefeated)
        XCTAssertTrue(Party.events(&sim).contains {
            if case .reviveInterrupted(let hero) = $0 { return hero == 1 } else { return false }
        })

        // Waiting does not resume it: the friend has to start again.
        Party.run(&sim, seconds: 2)
        XCTAssertNil(sim.reviveMarkers[0].reviver)
        XCTAssertTrue(sim.playerState(of: 1).isDefeated)

        // Trying again, and finishing, works.
        press(&sim, hero: 0)
        Party.run(&sim, seconds: sim.tuning.party.reviveSeconds + 0.5)
        XCTAssertFalse(sim.playerState(of: 1).isDefeated)
    }

    func testDodgingABlowDoesNotBreakTheChannel() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        let marker = sim.reviveMarkers[0].position
        Party.place(&sim, hero: 0, at: sim.world.wrap(marker + CGPoint(x: 1, y: 0)))
        press(&sim, hero: 0)
        Party.run(&sim, seconds: 1)
        // A hit that lands on an invulnerable hero does nothing at all.
        sim.perform(as: 0) { $0.player.invulnerability = 5 }
        sim.combat.incidents.append(.strikeHero(hero: 0, amount: 50, direction: CGPoint(x: 1, y: 0)))
        sim.step(dt: Party.dt)
        XCTAssertEqual(sim.reviveMarkers.first?.reviver, 0)
        XCTAssertEqual(Party.health(sim, 0), 100, accuracy: 0.001)
    }

    func testWalkingAwayBreaksTheChannel() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        let marker = sim.reviveMarkers[0].position
        Party.place(&sim, hero: 0, at: sim.world.wrap(marker + CGPoint(x: 1, y: 0)))
        press(&sim, hero: 0)
        Party.run(&sim, seconds: 1)
        XCTAssertNotNil(sim.reviveMarkers[0].reviver)
        Party.place(&sim, hero: 0, at: sim.world.wrap(marker + CGPoint(x: 8, y: 0)))
        sim.step(dt: Party.dt)
        XCTAssertNil(sim.reviveMarkers[0].reviver)
        XCTAssertEqual(sim.reviveMarkers[0].progress, 0, accuracy: 0.0001)
    }

    func testTheReviverFallingBreaksTheChannel() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        let marker = sim.reviveMarkers[0].position
        Party.place(&sim, hero: 0, at: sim.world.wrap(marker + CGPoint(x: 1, y: 0)))
        press(&sim, hero: 0)
        Party.run(&sim, seconds: 1)
        Party.kill(&sim, hero: 0)
        Party.run(&sim, seconds: 0.5)
        XCTAssertEqual(sim.reviveMarkers.count, 2, "both now lie where they fell")
        XCTAssertTrue(sim.reviveMarkers.allSatisfy { $0.reviver == nil })
    }

    func testARevivedHeroCanReviveAnotherWhoFellLater() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        Party.place(&sim, hero: 0, at: sim.reviveMarkers[0].position)
        press(&sim, hero: 0)
        Party.run(&sim, seconds: sim.tuning.party.reviveSeconds + 0.3)
        XCTAssertFalse(sim.playerState(of: 1).isDefeated)
        Party.kill(&sim, hero: 0)
        Party.run(&sim, seconds: sim.tuning.party.reviveInvulnerability + 0.5)
        XCTAssertTrue(sim.playerState(of: 0).isDefeated)
        Party.place(&sim, hero: 1, at: sim.reviveMarkers.first { $0.hero == 0 }!.position)
        press(&sim, hero: 1)
        Party.run(&sim, seconds: sim.tuning.party.reviveSeconds + 0.3)
        XCTAssertFalse(sim.playerState(of: 0).isDefeated)
    }

    func testAFriendTooFarAwayCannotBegin() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        let marker = sim.reviveMarkers[0].position
        Party.place(&sim, hero: 0, at: sim.world.wrap(marker + CGPoint(x: 6, y: 0)))
        press(&sim, hero: 0)
        Party.run(&sim, seconds: 1)
        XCTAssertNil(sim.reviveMarkers[0].reviver)
    }

    func testAFallenHeroCannotReviveAnother() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        Party.kill(&sim, hero: 2)
        let marker = sim.reviveMarkers.first { $0.hero == 1 }!.position
        Party.place(&sim, hero: 2, at: marker)
        press(&sim, hero: 2)
        Party.run(&sim, seconds: 4)
        XCTAssertTrue(sim.playerState(of: 1).isDefeated)
    }

    func testTwoFriendsCannotReviveTheSameHeroTwice() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 2)
        let marker = sim.reviveMarkers[0].position
        Party.place(&sim, hero: 0, at: sim.world.wrap(marker + CGPoint(x: 1, y: 0)))
        Party.place(&sim, hero: 1, at: sim.world.wrap(marker + CGPoint(x: -1, y: 0)))
        press(&sim, hero: 0)
        press(&sim, hero: 1)
        sim.step(dt: Party.dt)
        XCTAssertEqual(sim.reviveMarkers.count, 1)
        XCTAssertNotNil(sim.reviveMarkers[0].reviver)
        Party.run(&sim, seconds: sim.tuning.party.reviveSeconds + 0.3)
        XCTAssertFalse(sim.playerState(of: 2).isDefeated)
        let events = Party.events(&sim)
        let revivals = events.filter { if case .heroRevived = $0 { return true } else { return false } }
        XCTAssertEqual(revivals.count, 1, "only one revive can take effect")
    }

    func testRevivingAHeroWhoIsAlreadyStandingChangesNothing() {
        var sim = partyOfThree()
        Party.setHealth(&sim, hero: 1, 12)
        sim.revive(1, at: sim.playerState(of: 1).position)
        XCTAssertEqual(Party.health(sim, 1), 12, accuracy: 0.001)
    }

    func testAMarkerSurvivesUntilItIsUsed() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        Party.run(&sim, seconds: 60)
        XCTAssertEqual(sim.reviveMarkers.count, 1)
    }

    func testTheWholePartyFallingIsAWipe() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 0)
        Party.kill(&sim, hero: 1)
        XCTAssertFalse(sim.isPartyWiped)
        Party.kill(&sim, hero: 2)
        XCTAssertTrue(sim.isPartyWiped)
        Party.run(&sim, seconds: 1)
        XCTAssertNotNil(sim.timeSinceWipe)
        XCTAssertGreaterThan(sim.timeSinceWipe ?? 0, 0.9)
    }

    func testAPlayerWhoLeavesDoesNotBlockTheEnd() {
        var sim = partyOfThree()
        sim.removeHero(2)
        XCTAssertTrue(sim.reviveMarkers.isEmpty, "a hero who left leaves no marker")
        Party.kill(&sim, hero: 0)
        Party.kill(&sim, hero: 1)
        XCTAssertTrue(sim.isPartyWiped)
    }

    func testFallenHeroesWaitEvenWhileTheirPlayerIsAway() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        sim.setConnected(false, forHero: 1)
        Party.run(&sim, seconds: 5)
        XCTAssertEqual(sim.reviveMarkers.count, 1, "reconnecting while dead means still dead, marker in place")
        sim.setConnected(true, forHero: 1)
        XCTAssertTrue(sim.playerState(of: 1).isDefeated)
    }

    func testEventsAreTaggedWithTheirHero() {
        var sim = partyOfThree()
        Party.kill(&sim, hero: 1)
        let tagged = sim.drainPartyEvents()
        XCTAssertTrue(tagged.contains { entry in
            if case .playerDefeated = entry.event { return entry.hero == 1 } else { return false }
        })
        XCTAssertTrue(sim.drainPartyEvents().isEmpty, "draining hands events over once")
    }

    func testAloneAFallenHeroIsARunEndNotAMarker() {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 7)
        var sim = GameSimulation(run: run, tuning: .standard)
        sim.cheats = SimulationCheats(godMode: false, spawningEnabled: false)
        sim.combat.incidents.append(.strikeHero(hero: 0, amount: 100_000, direction: CGPoint(x: 1, y: 0)))
        sim.step(dt: Party.dt, intent: .idle)
        sim.step(dt: Party.dt, intent: .idle)
        XCTAssertTrue(sim.isPlayerDefeated)
        XCTAssertTrue(sim.reviveMarkers.isEmpty)
        XCTAssertTrue(sim.isPartyWiped)
        XCTAssertNotNil(sim.timeSinceWipe)
    }
}
