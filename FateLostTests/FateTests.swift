import CoreGraphics
import XCTest
@testable import FateLost

/// The endgame: Fate at the end of the Abyss, and Fate's Echo after it.
/// Each test is one line of the checklist the fight was built against.
final class FateTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60

    private func simulation(_ realm: RealmID, godMode: Bool = true) -> GameSimulation {
        var sim = GameSimulation(run: RunConfiguration(realmID: realm, starterWeaponID: StarterWeapons.sword.id,
                                                       seed: 11),
                                 tuning: .standard)
        sim.cheats = SimulationCheats(godMode: godMode, spawningEnabled: false)
        return sim
    }

    @discardableResult
    private func place(_ definition: EnemyDefinition, in sim: inout GameSimulation, offset: CGPoint) -> Int {
        let kind = sim.combat.enemies.kindIndex(for: definition)
        let id = sim.combat.makeEntityID()
        sim.combat.enemies.append(id: id, kind: kind, position: sim.world.wrap(sim.player.position + offset),
                                  speedScale: 1)
        return id
    }

    private func hit(_ amount: Double) -> Hit {
        Hit(amount: amount, type: .physical, tags: [], direction: CGPoint(x: 1, y: 0), knockback: 0,
            canCrit: false, depth: 1, source: .environment)
    }

    // MARK: Who Fate is

    func testFateIsTheAbyssesLastChampionAndConqueringItIsBeatingFate() {
        let abyss = RealmCatalog.realm(.abyss)
        XCTAssertEqual(abyss.conquestWave, FateTuning.abyssFinalWave)
        XCTAssertEqual(abyss.waves.boss(forWave: FateTuning.abyssFinalWave), EnemyCatalog.fate.id)
        XCTAssertEqual(EnemyCatalog.bosses(for: .abyss).last, EnemyCatalog.fate.id)
        XCTAssertFalse(EnemyCatalog.bosses(for: .abyss).dropLast().contains(EnemyCatalog.fate.id),
                       "Fate is met once, at the end")
    }

    func testFateHasSixTimesTheHealthOfTheStrongestChampion() {
        XCTAssertEqual(EnemyCatalog.fate.maxHealth, EnemyCatalog.bossAbyssalEcho.maxHealth * 6, accuracy: 0.001)
        XCTAssertTrue(EnemyCatalog.fate.isBoss)
    }

    func testFateIsTwiceTheSizeOfATypicalChampionInArtAndInBody() {
        let champions = EnemyCatalog.champions
        let typicalScale = champions.map(\.drawScale).reduce(0, +) / CGFloat(champions.count)
        let typicalRadius = champions.map(\.radius).reduce(0, +) / CGFloat(champions.count)
        XCTAssertEqual(EnemyCatalog.fate.drawScale / typicalScale, 2, accuracy: 0.35)
        XCTAssertEqual(EnemyCatalog.fate.radius / typicalRadius, 2, accuracy: 0.35,
                       "its body, and so its hitbox, grows with it")
        XCTAssertNotNil(PlaceholderArt.sprite(for: .enemyBossFate))
    }

    // MARK: The barrier

    func testTheBarrierIsDepletedBeforeHealth() throws {
        var sim = simulation(.abyss)
        let id = place(EnemyCatalog.fate, in: &sim, offset: CGPoint(x: 30, y: 0))
        let index = try XCTUnwrap(sim.combat.index(ofEnemy: id))
        let health = sim.combat.enemies.health[index]
        let barrier = sim.combat.enemies.barrier[index]
        XCTAssertEqual(barrier, health * 0.2, accuracy: health * 0.001, "it starts behind a fifth of its health in barrier")

        sim.combat.strike(index, with: hit(barrier * 0.5))
        XCTAssertEqual(sim.combat.enemies.health[index], health, "health did not move while the barrier held")
        XCTAssertLessThan(sim.combat.enemies.barrier[index], barrier)

        sim.combat.strike(index, with: hit(barrier * 3))
        XCTAssertEqual(sim.combat.enemies.barrier[index], 0)
        XCTAssertLessThan(sim.combat.enemies.health[index], health, "health falls once the barrier is gone")
    }

    func testOnlyFateStartsBehindABarrier() {
        for champion in EnemyCatalog.champions {
            XCTAssertEqual(champion.kit?.barrierFraction ?? 0, 0, "\(champion.name) should not have a barrier")
        }
    }

    func testTheBarrierBreakingIsAnEvent() throws {
        var sim = simulation(.abyss)
        let id = place(EnemyCatalog.fate, in: &sim, offset: CGPoint(x: 4, y: 0))
        let index = try XCTUnwrap(sim.combat.index(ofEnemy: id))
        sim.step(dt: dt)
        _ = sim.drainEvents()
        sim.combat.strike(index, with: hit(sim.combat.enemies.barrier[index] * 4))
        sim.step(dt: dt)
        let events = sim.drainEvents()
        XCTAssertTrue(events.contains { if case .shieldBroke = $0 { return true } else { return false } })
    }

    // MARK: The scythe

    func testTheScytheReachesItsWholeWideMark() throws {
        var sim = simulation(.abyss)
        place(EnemyCatalog.fate, in: &sim, offset: CGPoint(x: 3, y: 0))
        var cone: Hazard?
        for _ in 0..<Int(30 / dt) where cone == nil {
            sim.step(dt: dt)
            cone = sim.combat.hazards.first { $0.shape == .cone && !$0.isGuide }
        }
        let scythe = try XCTUnwrap(cone, "Fate never swung")
        let kit = try XCTUnwrap(EnemyCatalog.fate.kit)
        XCTAssertEqual(Double(scythe.size), (3.8 + 0.08 * Double(kit.intensity)) * kit.reachScale, accuracy: 0.01)
        XCTAssertGreaterThan(scythe.size, 6, "it threatens a hero standing well back, not only at its feet")
        XCTAssertGreaterThanOrEqual(scythe.warning, BossSystem.minimumWarning)
    }

    // MARK: Firebombs

    func testFirebombsLandOneAfterAnotherAndBurn() throws {
        var sim = simulation(.abyss)
        let kit = try XCTUnwrap(EnemyCatalog.fate.kit)
        let hero = AITarget(position: sim.player.position, isAlive: true, isHidden: false, hero: 0, maxHealth: 100)
        BossSystem.firebombRain(kit: kit, base: 20, aim: CGPoint(x: 1, y: 0), heroes: [hero], combat: &sim.combat)
        let bombs = sim.combat.hazards
        XCTAssertEqual(bombs.count, FateTuning.firebombCount)
        let landings = bombs.map(\.warning).sorted()
        XCTAssertEqual(Set(landings).count, landings.count, "no two land at the same moment")
        XCTAssertGreaterThan((landings.last ?? 0) - (landings.first ?? 0), 1, "they fall over time, not at once")
        XCTAssertTrue(bombs.allSatisfy { $0.burnTicks > 0 && $0.burnTickDamage > 0 }, "the Powder Fiend's burn")
        XCTAssertTrue(bombs.allSatisfy { $0.warning >= BossSystem.minimumWarning })
    }

    func testFirebombsNeverFallOnTheSafeCircle() throws {
        var sim = simulation(.abyss)
        let kit = try XCTUnwrap(EnemyCatalog.fate.kit)
        let centre = sim.player.position
        sim.combat.darkness = DarknessState(safeCenter: centre, safeRadius: FateTuning.eclipseSafeRadius,
                                            warningRemaining: 4, activeRemaining: 6, damagePerSecond: 0.05)
        // The hero stands in the circle: even the bomb aimed at them must go elsewhere.
        let hero = AITarget(position: centre, isAlive: true, isHidden: false, hero: 0, maxHealth: 100)
        for _ in 0..<20 {
            sim.combat.hazards.removeAll()
            BossSystem.firebombRain(kit: kit, base: 20, aim: CGPoint(x: 1, y: 0), heroes: [hero], combat: &sim.combat)
            XCTAssertGreaterThanOrEqual(sim.combat.hazards.count, 3, "standing in the circle does not stop the rain")
            for bomb in sim.combat.hazards {
                XCTAssertGreaterThan(sim.world.distance(bomb.position, centre),
                                     FateTuning.eclipseSafeRadius + bomb.size, "a bomb reached the safe circle")
            }
        }
    }

    // MARK: The Encroaching Abyss

    func testTheDarkWarnsThenHurtsOnlyOutsideTheCircle() {
        var sim = simulation(.abyss)
        // Fate far off, beyond any move it could make: only its dark is under test.
        place(EnemyCatalog.fate, in: &sim, offset: CGPoint(x: 40, y: 0))
        let centre = sim.player.position
        sim.combat.darkness = DarknessState(safeCenter: centre, safeRadius: 2.6, warningRemaining: 1,
                                            activeRemaining: 5, damagePerSecond: 0.05)
        let inside = AITarget(position: centre, isAlive: true, isHidden: false, hero: 0, maxHealth: 200)
        let outside = AITarget(position: sim.world.wrap(centre + CGPoint(x: 5, y: 0)), isAlive: true,
                               isHidden: false, hero: 1, maxHealth: 200)

        // The warning: nothing yet, for anyone.
        sim.combat.incidents.removeAll()
        BossSystem.step(&sim.combat, targets: [inside, outside], dt: 0.5)
        XCTAssertTrue(sim.combat.incidents.isEmpty, "the dark hurt during its warning")

        // Past it: 5% of max health a second, only outside.
        BossSystem.step(&sim.combat, targets: [inside, outside], dt: 0.6)
        sim.combat.incidents.removeAll()
        BossSystem.step(&sim.combat, targets: [inside, outside], dt: 1)
        var hurt: [Int: Double] = [:]
        for incident in sim.combat.incidents {
            if case let .strikeHero(hero, amount, _) = incident { hurt[hero, default: 0] += amount }
        }
        XCTAssertNil(hurt[0], "the safe circle is safe")
        XCTAssertEqual(hurt[1] ?? 0, 200 * 0.05, accuracy: 0.001)
    }

    func testTheDarkLiftsWhenFateIsGone() {
        var sim = simulation(.abyss)
        sim.combat.darkness = DarknessState(safeCenter: sim.player.position, safeRadius: 2.6, warningRemaining: 0,
                                            activeRemaining: 5, damagePerSecond: 0.05)
        BossSystem.step(&sim.combat, targets: [], dt: dt)
        XCTAssertNil(sim.combat.darkness)
    }

    func testTheSafeCircleIsAlwaysReachableInTheWarning() {
        // A hero at an ordinary walking pace crosses the farthest it can open
        // with time to spare.
        let walk = 4.2
        let needed = Double(FateTuning.eclipseSafeDistance) / walk
        XCTAssertLessThan(needed, FateTuning.eclipseWarning * 0.75)
        XCTAssertEqual(FateTuning.eclipseDamagePerSecond, 0.05)
    }

    // MARK: Summons

    func testEverySummonExistsAndNoneIsFatesOwnKindOrARiftBoss() throws {
        let kit = try XCTUnwrap(EnemyCatalog.fate.kit)
        XCTAssertFalse(kit.summonPool.isEmpty)
        XCTAssertLessThanOrEqual(kit.maxSimultaneousSummons, 2)
        let rift = Set(EnemyCatalog.riftBosses.map(\.id))
        for entry in kit.summonPool {
            let definition = try XCTUnwrap(EnemyCatalog.definition(for: entry.kind), "\(entry.kind)")
            XCTAssertNotEqual(definition.id, EnemyCatalog.fate.id)
            XCTAssertFalse(rift.contains(definition.id), "a rift boss belongs to its own arena")
        }
        // Returning champions are the rare call; elites the common one.
        let bossWeight = kit.summonPool.filter { EnemyCatalog.definition(for: $0.kind)?.isBoss ?? false }
            .reduce(0) { $0 + $1.weight }
        let eliteWeight = kit.summonPool.filter { !(EnemyCatalog.definition(for: $0.kind)?.isBoss ?? true) }
            .reduce(0) { $0 + $1.weight }
        XCTAssertLessThan(bossWeight, eliteWeight)
    }

    func testASummonedChampionFallingEndsNothing() throws {
        var sim = simulation(.abyss)
        let fateID = place(EnemyCatalog.fate, in: &sim, offset: CGPoint(x: 30, y: 0))
        let echoID = place(EnemyCatalog.bossWarchief, in: &sim, offset: CGPoint(x: -30, y: 0))
        var state = sim.wave
        state.index = FateTuning.abyssFinalWave
        state.phase = .bossFight
        state.bossID = fateID
        state.bossTitle = "Fate"
        sim.waves.mirror(state)

        let echo = try XCTUnwrap(sim.combat.index(ofEnemy: echoID))
        sim.combat.enemies.health[echo] = 0
        for _ in 0..<10 { sim.step(dt: dt) }
        XCTAssertFalse(sim.isRealmConquered, "a returning champion's fall is not Fate's")
        XCTAssertEqual(sim.wave.phase, .bossFight)
        XCTAssertEqual(sim.wave.bossID, fateID)

        let fate = try XCTUnwrap(sim.combat.index(ofEnemy: fateID))
        sim.combat.enemies.health[fate] = 0
        for _ in 0..<10 { sim.step(dt: dt) }
        XCTAssertTrue(sim.isRealmConquered, "Fate's fall is the Abyss conquered")
    }

    // MARK: The unlock

    func testDefeatingFateUnlocksFatesEchoForGood() throws {
        var profile = LegacyProfile()
        XCTAssertFalse(profile.realms.hasEverDefeatedFate)
        let summary = RunSummary(realm: .abyss, weapon: StarterWeapons.sword.id, secondsSurvived: 1500,
                                 stats: RunStats(), level: 40, allocation: SkillAllocation(), outcome: .conquered,
                                 wave: FateTuning.abyssFinalWave)
        profile.record(summary, realm: RealmCatalog.realm(.abyss))
        XCTAssertTrue(profile.realms.hasEverDefeatedFate)
        XCTAssertTrue(RealmUnlockRules.isUnlocked(RealmCatalog.realm(.fatesEcho), progress: profile.realms,
                                                  catalog: RealmCatalog.all))
        // Through a save and a reload, as a restart would.
        let restored = try JSONDecoder().decode(LegacyProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertTrue(restored.realms.hasEverDefeatedFate)

        // Losing the Abyss later takes nothing back.
        var lost = summary
        lost.outcome = .defeated
        profile.record(lost, realm: RealmCatalog.realm(.abyss))
        XCTAssertTrue(profile.realms.hasEverDefeatedFate)
    }

    // MARK: Fate's Echo

    func testFatesEchoIsEndlessWithNoChampions() {
        let echo = RealmCatalog.realm(.fatesEcho)
        XCTAssertTrue(echo.isEndless)
        XCTAssertTrue(EnemyCatalog.bosses(for: .fatesEcho).isEmpty)
        XCTAssertNotEqual(echo.arena.theme, RealmCatalog.realm(.abyss).arena.theme, "an atmosphere of its own")
        XCTAssertFalse(EnemyCatalog.roster(for: .fatesEcho).isEmpty)
    }

    func testTheHordeGrowsEveryFiveWavesAndOnlyThen() {
        for wave in 1...5 { XCTAssertEqual(FateTuning.echoHealthMultiplier(atWave: wave), 1, accuracy: 1e-9) }
        for wave in 6...10 {
            XCTAssertEqual(FateTuning.echoHealthMultiplier(atWave: wave), 1.2, accuracy: 1e-9)
            XCTAssertEqual(FateTuning.echoDamageMultiplier(atWave: wave), 1.1, accuracy: 1e-9)
        }
        for wave in 11...15 {
            XCTAssertEqual(FateTuning.echoHealthMultiplier(atWave: wave), 1.44, accuracy: 1e-9)
            XCTAssertEqual(FateTuning.echoDamageMultiplier(atWave: wave), 1.21, accuracy: 1e-9)
        }
    }

    func testTheSimulationScalesAtWavesSixAndEleven() {
        var sim = simulation(.fatesEcho)
        func scale(atWave wave: Int) -> (health: Double, damage: Double) {
            var state = sim.wave
            state.index = wave
            sim.waves.mirror(state)
            sim.updateEnemyScaling()
            return (sim.combat.enemyHealthScale, sim.combat.enemyDamageScale)
        }
        let first = scale(atWave: 5)
        XCTAssertEqual(first.health, FateTuning.echoBaseHealth, accuracy: 1e-9)
        XCTAssertEqual(first.damage, FateTuning.echoBaseDamage, accuracy: 1e-9)
        XCTAssertEqual(scale(atWave: 6).health, FateTuning.echoBaseHealth * 1.2, accuracy: 1e-9)
        XCTAssertEqual(scale(atWave: 11).health, FateTuning.echoBaseHealth * 1.44, accuracy: 1e-9)
        XCTAssertEqual(scale(atWave: 11).damage, FateTuning.echoBaseDamage * 1.21, accuracy: 1e-9)
    }

    func testScalingNeverOverflowsHoweverLongTheRun() {
        for wave in [100, 1_000, 100_000, Int.max / 2] {
            let health = FateTuning.echoHealthMultiplier(atWave: wave)
            XCTAssertTrue(health.isFinite)
            XCTAssertLessThan(health * EnemyCatalog.fate.maxHealth, Double(Int.max), "a health that can still be shown")
            XCTAssertTrue(FateTuning.echoDamageMultiplier(atWave: wave).isFinite)
        }
    }

    func testTheBankOrGoOnChoiceComesAfterWavesTenAndTwenty() {
        var sim = simulation(.fatesEcho)
        for (began, offered) in [(2, nil), (10, nil), (11, 10), (12, nil), (21, 20)] as [(Int, Int?)] {
            sim.echoOffer = nil
            var state = sim.wave
            state.index = began
            sim.waves.mirror(state)
            sim.step(dt: dt)
            XCTAssertEqual(sim.echoOffer?.completedWave, offered, "starting wave \(began)")
        }
    }

    func testOtherRealmsNeverOfferIt() {
        var sim = simulation(.abyss)
        var state = sim.wave
        state.index = 11
        sim.waves.mirror(state)
        sim.step(dt: dt)
        XCTAssertNil(sim.echoOffer)
    }

    func testBankingPaysAndFallingBeforeBankingLosesIt() {
        var stats = RunStats()
        stats.kills = 400
        stats.eliteKills = 6
        let realm = RealmCatalog.realm(.fatesEcho)
        func summary(_ outcome: RunSummary.Outcome) -> RunSummary {
            RunSummary(realm: .fatesEcho, weapon: StarterWeapons.sword.id, secondsSurvived: 600, stats: stats,
                       level: 25, allocation: SkillAllocation(), outcome: outcome, wave: 20)
        }
        var banked = LegacyProfile()
        banked.record(summary(.collected), realm: realm)
        XCTAssertGreaterThan(banked.echoes, 0)
        XCTAssertEqual(banked.lifetime.deaths, 0, "leaving is not dying")

        var fell = LegacyProfile()
        fell.record(summary(.defeated), realm: realm)
        XCTAssertEqual(fell.echoes, 0, "fell before banking")
        XCTAssertEqual(LegacyProfile().payout(for: summary(.collected), realm: realm), banked.echoes,
                       "what the offer shows is what banking pays")

        // A party is never offered the choice, so it is paid as always.
        var party = LegacyProfile()
        party.record(summary(.defeated), realm: realm, echoes: 50)
        XCTAssertEqual(party.echoes, 50)

        // Everywhere else, falling pays as it always has.
        var elsewhere = LegacyProfile()
        let other = RunSummary(realm: .abyss, weapon: StarterWeapons.sword.id, secondsSurvived: 600, stats: stats,
                               level: 25, allocation: SkillAllocation(), outcome: .defeated, wave: 20)
        elsewhere.record(other, realm: RealmCatalog.realm(.abyss))
        XCTAssertGreaterThan(elsewhere.echoes, 0)
    }
}
