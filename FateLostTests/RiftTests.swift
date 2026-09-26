import XCTest
@testable import FateLost

/// The rare portals behind a fallen champion, and the fight on the far side.
final class RiftTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60

    private func solo(chance: Double = 0.05) -> GameSimulation {
        var tuning = GameTuning.standard
        tuning.simulation.riftChance = chance
        var sim = GameSimulation(run: RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id,
                                                       seed: 9), tuning: tuning)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        return sim
    }

    private func party(_ count: Int) -> GameSimulation {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 9)
        let heroes = (0..<count).map { index in
            PartyHeroConfig(id: "r\(index)", name: "Hero \(index)", slot: index, weaponID: StarterWeapons.sword.id,
                            legacy: [])
        }
        var sim = GameSimulation(run: run, tuning: .standard, party: heroes)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        return sim
    }

    private func run(_ sim: inout GameSimulation, seconds: Double) {
        for _ in 0..<Int((seconds * 60).rounded()) { sim.step(dt: dt) }
    }

    private func place(_ sim: inout GameSimulation, hero: Int, at point: CGPoint) {
        sim.perform(as: hero) { sim in
            sim.player.position = point
            sim.combat.playerPosition = point
        }
    }

    // MARK: The bosses

    func testEveryRiftHasAGreatOneWhoIsBiggerThanAnyChampion() {
        XCTAssertEqual(RiftKind.allCases.count, 4)
        var sprites = Set<SpriteID>()
        for kind in RiftKind.allCases {
            guard let boss = EnemyCatalog.definition(for: kind.bossID) else { return XCTFail("\(kind) has no boss") }
            XCTAssertTrue(boss.isBoss)
            XCTAssertNotNil(boss.kit)
            XCTAssertGreaterThanOrEqual(boss.kit?.moves.count ?? 0, 8, "\(boss.name) should have almost everything")
            XCTAssertGreaterThanOrEqual(boss.kit?.intensity ?? 0, 9)
            XCTAssertNotNil(boss.kit?.adds.flatMap { EnemyCatalog.definition(for: $0) })
            for champion in EnemyCatalog.champions {
                XCTAssertGreaterThan(boss.drawScale * boss.radius, champion.drawScale * champion.radius,
                                     "\(boss.name) is not bigger than \(champion.name)")
                XCTAssertGreaterThan(boss.maxHealth, champion.maxHealth * 0.6)
            }
            XCTAssertTrue(sprites.insert(boss.spriteID).inserted, "two rifts share a boss")
            XCTAssertFalse(EnemyCatalog.champions.contains { $0.id == boss.id }, "a rift boss is not a realm champion")
            XCTAssertFalse(EnemyCatalog.roster(for: .abyss).contains { $0.id == boss.id }, "it walks the field as horde")
        }
    }

    func testARiftPaysInEpicAndLegendaryRelicsOnly() {
        for rarity in ItemRarity.allCases {
            let weight = LootTier.rift.weight(of: rarity)
            if rarity == .epic || rarity == .legendary {
                XCTAssertGreaterThan(weight, 0)
            } else {
                XCTAssertEqual(weight, 0, "\(rarity) should not come out of a rift")
            }
        }
        XCTAssertGreaterThan(LootTier.rift.weight(of: .epic), LootTier.rift.weight(of: .legendary),
                             "legendary is the rarer of the two")
        XCTAssertGreaterThan(LootTier.rift.weight(of: .legendary), LootTier.hoard.weight(of: .legendary),
                             "and better than a hoard")
    }

    // MARK: The portal

    func testAFallenChampionOpensAPortalWithTheChanceItIsGivenAndNotOtherwise() {
        for (chance, expected) in [(1.0, true), (0.0, false)] {
            var sim = solo(chance: chance)
            for _ in 0..<4 { sim.waves.skipToNextWave(&sim.combat) }
            run(&sim, seconds: 3.2)
            guard let index = (0..<sim.combat.enemies.count).first(where: { sim.combat.enemies.definition(at: $0).isBoss }) else {
                return XCTFail("the champion never landed")
            }
            sim.combat.enemies.health[index] = 0
            run(&sim, seconds: 0.5)
            XCTAssertEqual(!sim.combat.portals.isEmpty, expected, "chance \(chance)")
        }
        XCTAssertEqual(RiftTuning.chance, 0.10, "about one champion in ten")
    }

    func testAPortalWaitsAndThenCloses() {
        var sim = solo()
        let far = sim.world.wrap(sim.arena.playerSpawn + CGPoint(x: 30, y: 0))
        sim.openPortal(.tides, at: far)
        run(&sim, seconds: RiftTuning.lifetime - 5)
        XCTAssertEqual(sim.combat.portals.count, 1)
        run(&sim, seconds: 10)
        XCTAssertTrue(sim.combat.portals.isEmpty, "an unentered portal should close")
    }

    // MARK: The fight

    func testStepThroughTakesTheWholePartyAwayAndRaisesTheFallen() {
        var sim = party(2)
        let home = sim.arena.playerSpawn
        place(&sim, hero: 0, at: home)
        place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 6, y: 0)))
        // Something is fighting them, and one of them has fallen.
        let goblin = sim.combat.enemies.kindIndex(for: EnemyCatalog.goblin)
        sim.combat.enemies.append(id: sim.combat.makeEntityID(), kind: goblin,
                                  position: sim.world.wrap(home + CGPoint(x: 4, y: 4)), speedScale: 1)
        sim.perform(as: 1) { $0.player.health = 0 }
        sim.openPortal(.winter, at: sim.world.wrap(home + CGPoint(x: 0.5, y: 0)))
        run(&sim, seconds: 0.2)

        guard let rift = sim.combat.rift else { return XCTFail("the party did not go through") }
        XCTAssertEqual(rift.kind, .winter)
        XCTAssertEqual(sim.activeRiftKind, .winter)
        for hero in 0..<2 {
            let state = sim.playerState(of: hero)
            XCTAssertGreaterThan(sim.world.distance(state.position, home), 40, "hero \(hero) is still here")
            XCTAssertFalse(state.isDefeated, "hero \(hero) was left fallen")
        }
        XCTAssertTrue(sim.combat.enemies.isEmpty, "the horde stays behind")
        XCTAssertTrue(sim.combat.portals.isEmpty)

        // Nothing but the great one arrives, and the waves wait.
        run(&sim, seconds: RiftTuning.arrivalSeconds + 1)
        XCTAssertEqual(sim.combat.rift?.stage, .fighting)
        let bosses = (0..<sim.combat.enemies.count).filter { sim.combat.enemies.definition(at: $0).isBoss }
        XCTAssertEqual(bosses.count, 1)
        XCTAssertEqual(sim.combat.enemies.definition(at: bosses[0]).id, RiftKind.winter.bossID)
        XCTAssertTrue(sim.waves.state.isBossActive, "the health bar should show the great one")
        let wave = sim.waves.state.index
        run(&sim, seconds: 30)
        XCTAssertEqual(sim.waves.state.index, wave, "the waves must not move on inside a rift")
    }

    func testWinningPaysExperienceAndARiftFindThenOpensTheWayHome() {
        var sim = solo()
        let home = sim.arena.playerSpawn
        sim.player.position = home
        sim.combat.playerPosition = home
        let wave = sim.waves.state
        sim.openPortal(.cinders, at: sim.world.wrap(home + CGPoint(x: 0.4, y: 0)))
        run(&sim, seconds: RiftTuning.arrivalSeconds + 0.5)
        guard let index = (0..<sim.combat.enemies.count).first(where: { sim.combat.enemies.definition(at: $0).isBoss }) else {
            return XCTFail("the great one never appeared")
        }
        sim.combat.enemies.health[index] = 0
        run(&sim, seconds: 0.3)

        XCTAssertEqual(sim.combat.rift?.stage, .won)
        XCTAssertTrue(sim.combat.portals.contains { $0.isReturn }, "there should be a way home")
        XCTAssertFalse(sim.combat.orbs.isEmpty, "and experience on the ground")
        guard let offer = sim.offer else { return XCTFail("no find was offered") }
        XCTAssertEqual(offer.tier, .rift)
        for choice in offer.choices {
            let rarity = RelicCatalog.relic(choice.relic)?.rarity
            XCTAssertTrue(rarity == .epic || rarity == .legendary, "a rift find dealt \(String(describing: rarity))")
        }

        // Walking onto the way home takes the party back to where it stood.
        let door = sim.combat.portals.first { $0.isReturn }?.position ?? .zero
        place(&sim, hero: 0, at: door)
        run(&sim, seconds: 0.2)
        XCTAssertNil(sim.combat.rift, "still in the rift")
        XCTAssertLessThan(sim.world.distance(sim.playerState(of: 0).position, home), 1, "not back where it was")
        XCTAssertEqual(sim.waves.state.index, wave.index)
        XCTAssertEqual(sim.waves.state.phase, wave.phase, "the wave clock should carry on where it stopped")
        XCTAssertTrue(sim.combat.portals.isEmpty)
    }

    // MARK: Across the wire

    func testPortalsAndTheRiftReachGuests() {
        var host = party(2)
        let home = host.arena.playerSpawn
        host.openPortal(.void, at: host.world.wrap(home + CGPoint(x: 10, y: 0)))
        var snapshot = host.snapshot(forViewer: 1, radius: 40)
        XCTAssertEqual(snapshot.portals.count, 1)
        XCTAssertEqual(snapshot.rift, NetSnapshot.noRift)

        guard let decoded = NetSnapshot.decode(snapshot.encoded()) else { return XCTFail("did not decode") }
        XCTAssertEqual(decoded.portals.first?.kind, UInt8(RiftKind.void.rawValue))
        XCTAssertEqual(decoded.portals.first?.isReturn, false)

        var guest = party(2)
        guest.beginMirroring(slot: 1)
        guest.applyMirror(decoded)
        XCTAssertEqual(guest.allPortals.first?.kind, .void)
        XCTAssertNil(guest.activeRiftKind)

        snapshot.rift = UInt8(RiftKind.void.rawValue)
        guard let inside = NetSnapshot.decode(snapshot.encoded()) else { return XCTFail("did not decode") }
        guest.applyMirror(inside)
        XCTAssertEqual(guest.activeRiftKind, .void)
    }
}
