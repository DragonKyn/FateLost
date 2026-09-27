import XCTest
@testable import FateLost

/// End-game difficulty modifiers: switching a conquered realm's rules
/// harder, on purpose, for more echoes.
final class DifficultyModifierTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60

    private func solo(modifiers: [RunModifierSelection] = [], realm: RealmID = .ashenWilds,
                      godMode: Bool = true) -> GameSimulation {
        let run = RunConfiguration(realmID: realm, starterWeaponID: StarterWeapons.sword.id, seed: 9,
                                   modifiers: modifiers)
        var sim = GameSimulation(run: run, tuning: .standard)
        sim.cheats = SimulationCheats(godMode: godMode, spawningEnabled: false)
        return sim
    }

    private func run(_ sim: inout GameSimulation, seconds: Double) {
        for _ in 0..<Int((seconds * 60).rounded()) { sim.step(dt: dt) }
    }

    // MARK: Catalog

    func testEveryModifierHasACatalogEntry() {
        for id in DifficultyModifierID.allCases {
            XCTAssertEqual(DifficultyModifierCatalog.definition(id).id, id)
        }
    }

    func testReinforcedEnemiesPayoutInterpolatesAcrossItsRange() {
        let minimum = RunModifierSelection(id: .reinforcedEnemies, intensity: 0)
        let maximum = RunModifierSelection(id: .reinforcedEnemies, intensity: 1)
        XCTAssertEqual(DifficultyModifierCatalog.payoutBonus(for: minimum), 0.02, accuracy: 0.0001)
        XCTAssertEqual(DifficultyModifierCatalog.payoutBonus(for: maximum), 0.20, accuracy: 0.0001)
    }

    func testTogglesPayTheSameBonusRegardlessOfIntensity() {
        let a = RunModifierSelection(id: .swarm, intensity: 0)
        let b = RunModifierSelection(id: .swarm, intensity: 1)
        XCTAssertEqual(DifficultyModifierCatalog.payoutBonus(for: a), DifficultyModifierCatalog.payoutBonus(for: b))
    }

    func testEffectsSumAcrossSeveralActiveModifiers() {
        let effects = DifficultyModifierCatalog.effects(for: [
            RunModifierSelection(id: .swarm), RunModifierSelection(id: .viciousFoes),
        ])
        XCTAssertEqual(effects.spawnRateBonus, 0.2, accuracy: 0.0001)
        XCTAssertEqual(effects.enemyDamageBonus, 0.25, accuracy: 0.0001)
        XCTAssertEqual(effects.payoutBonus, 0.19, accuracy: 0.0001)
    }

    func testExtraElitesRaisesTheSimultaneousCapAndForcesElitesIntoEveryRealm() {
        let effects = DifficultyModifierCatalog.effects(for: [RunModifierSelection(id: .extraElites)])
        XCTAssertEqual(effects.maxSimultaneousElites, 2)
        XCTAssertTrue(effects.includesRareElites)
    }

    func testElitistBoostsWeightWithoutRaisingTheCap() {
        let effects = DifficultyModifierCatalog.effects(for: [RunModifierSelection(id: .elitist)])
        XCTAssertEqual(effects.maxSimultaneousElites, 1)
        XCTAssertGreaterThan(effects.eliteWeightBonus, 0)
        XCTAssertTrue(effects.includesRareElites)
    }

    // MARK: Roster injection

    func testAnEliteRelatedModifierAddsRareElitesToARealmTooEarlyForThem() {
        let plain = EnemyCatalog.roster(for: .ashenWilds)
        XCTAssertFalse(plain.contains { $0.eliteKit != nil }, "the first realm has no rare elites by default")

        let forced = EnemyCatalog.roster(for: .ashenWilds, includingRareElites: true)
        XCTAssertTrue(forced.contains { $0.id == EnemyCatalog.shieldbreaker.id })
        XCTAssertTrue(forced.contains { $0.id == EnemyCatalog.explosiveElite.id })
    }

    func testForcingRareElitesIntoARealmThatAlreadyHasThemDoesNotDuplicateThem() {
        let normal = EnemyCatalog.roster(for: .frozenWastes)
        let forced = EnemyCatalog.roster(for: .frozenWastes, includingRareElites: true)
        XCTAssertEqual(normal.count, forced.count)
    }

    // MARK: Simulation effects

    func testReinforcedEnemiesScalesEnemyHealth() {
        var plain = solo()
        var reinforced = solo(modifiers: [RunModifierSelection(id: .reinforcedEnemies, intensity: 0)])
        plain.step(dt: dt)
        reinforced.step(dt: dt)
        // At intensity 0 the bonus is +50% flat.
        XCTAssertEqual(reinforced.combat.enemyHealthScale, plain.combat.enemyHealthScale * 1.5, accuracy: 0.001)
    }

    func testViciousFoesScalesEnemyDamage() {
        var plain = solo()
        var vicious = solo(modifiers: [RunModifierSelection(id: .viciousFoes)])
        plain.step(dt: dt)
        vicious.step(dt: dt)
        XCTAssertEqual(vicious.combat.enemyDamageScale, plain.combat.enemyDamageScale * 1.25, accuracy: 0.001)
    }

    func testGlassCannonMakesTheHeroHitHarderAndTakeMoreDamage() {
        let plain = solo()
        let glassCannon = solo(modifiers: [RunModifierSelection(id: .glassCannon)])
        XCTAssertEqual(glassCannon.combat.playerDamageTakenScale, 1.2, accuracy: 0.0001)
        XCTAssertGreaterThan(glassCannon.sheet[.damage], plain.sheet[.damage])
    }

    func testGlassCannonDamageTakenScaleAppliesInStrikePlayer() {
        var sim = solo(modifiers: [RunModifierSelection(id: .glassCannon)], godMode: false)
        var player = sim.player
        let before = player.health
        sim.combat.strikePlayer(&player, amount: 10, direction: CGPoint(x: 1, y: 0), godMode: false)
        // Armour is 0 by default, so the whole scaled amount lands.
        XCTAssertEqual(before - player.health, 12, accuracy: 0.01)
    }

    func testThinIceRemovesDodgeEntirely() {
        let sim = solo(modifiers: [RunModifierSelection(id: .thinIce)])
        XCTAssertEqual(sim.sheet[.dodgeChance], 0)
    }

    func testIronLungHalvesHealingReceived() {
        let plain = solo()
        let ironLung = solo(modifiers: [RunModifierSelection(id: .ironLung)])
        XCTAssertEqual(ironLung.sheet[.healingReceived], plain.sheet[.healingReceived] * 0.5, accuracy: 0.001)
    }

    func testNoSecondWindZeroesHealthRegen() {
        let sim = solo(modifiers: [RunModifierSelection(id: .noSecondWind)])
        XCTAssertEqual(sim.sheet[.healthRegen], 0)
    }

    func testDontStopTicksDamageOncePastTheGracePeriod() {
        var sim = solo(modifiers: [RunModifierSelection(id: .dontStop)], godMode: false)
        let maxHealth = sim.player.maxHealth
        // Standing still: no intent is ever set, so the hero never moves.
        run(&sim, seconds: 2.5)
        XCTAssertLessThan(sim.player.health, maxHealth, "a tick should have landed just past the 2s grace")
    }

    func testDontStopDoesNothingWhileMoving() {
        var sim = solo(modifiers: [RunModifierSelection(id: .dontStop)], godMode: false)
        let maxHealth = sim.player.maxHealth
        for _ in 0..<Int(3 * 60) {
            sim.step(dt: dt, intent: PlayerIntent(move: CGPoint(x: 1, y: 0)))
        }
        XCTAssertEqual(sim.player.health, maxHealth, accuracy: 0.01)
    }

    func testDontStopIsInertWhenNotChosen() {
        var sim = solo(godMode: false)
        let maxHealth = sim.player.maxHealth
        run(&sim, seconds: 3)
        XCTAssertEqual(sim.player.health, maxHealth, accuracy: 0.01)
    }

    // MARK: Payout

    func testDifficultyBonusAddsToEchoesEarned() {
        var profile = LegacyProfile()
        let realm = RealmCatalog.realm(.ashenWilds)
        let stats = RunStats()
        let summaryPlain = RunSummary(realm: .ashenWilds, weapon: StarterWeapons.sword.id, secondsSurvived: 120,
                                      stats: stats, level: 3, allocation: SkillAllocation())
        var summaryBoosted = summaryPlain
        summaryBoosted.difficultyBonus = 0.5

        var plainProfile = profile
        plainProfile.record(summaryPlain, realm: realm)
        profile.record(summaryBoosted, realm: realm)

        XCTAssertGreaterThan(profile.echoes, plainProfile.echoes)
    }

    // MARK: Persistence

    func testRealmProgressDecodesOldSavesWithoutActiveModifiers() throws {
        let json = Data("{\"conquered\":[\"ashenWilds\"]}".utf8)
        let decoded = try JSONDecoder().decode(RealmProgress.self, from: json)
        XCTAssertEqual(decoded.conquered, [.ashenWilds])
        XCTAssertTrue(decoded.activeModifiers.isEmpty)
    }

    func testRealmProgressRoundTripsActiveModifiers() throws {
        var progress = RealmProgress()
        progress.activeModifiers[.ashenWilds] = [RunModifierSelection(id: .swarm)]
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(RealmProgress.self, from: data)
        XCTAssertEqual(decoded.activeModifiers[.ashenWilds], [RunModifierSelection(id: .swarm)])
    }
}
