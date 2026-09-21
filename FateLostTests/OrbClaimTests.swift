import CoreGraphics
import XCTest
@testable import FateLost

/// In a party the pickup step runs once for each hero, over the same orbs. An
/// orb has to fly to the hero who drew it in, not be pulled by all of them.
final class OrbClaimTests: XCTestCase {
    private let world = ToroidalWorld(width: 128, height: 128)
    private let dt: TimeInterval = 1.0 / 60
    private let host = PlayerState(position: CGPoint(x: 40, y: 64), maxHealth: 100)
    private let guest = PlayerState(position: CGPoint(x: 64, y: 64), maxHealth: 100)

    private func combat() -> CombatState {
        CombatState(world: world, tuning: CombatTuning(), gridCellSize: 1.5, capacity: 16, seed: 3)
    }

    private var targets: [AITarget] {
        [AITarget(position: host.position, isAlive: true, isHidden: false, hero: 0),
         AITarget(position: guest.position, isAlive: true, isHidden: false, hero: 1)]
    }

    /// One tick of the party's gathering, in the given order of turns.
    private func tick(_ combat: inout CombatState, order: [Int]) {
        for hero in order {
            PickupSystem.step(&combat, player: hero == 0 ? host : guest, hero: hero, targets: targets, dt: dt)
        }
    }

    func testAnOrbDrawnInByTheGuestFliesToTheGuestNotTheHost() {
        for order in [[0, 1], [1, 0]] {
            var c = combat()
            c.orbs.append(ExperienceOrb(id: 1, position: CGPoint(x: 62.6, y: 64), value: 5))
            var previous = world.distance(c.orbs[0].position, guest.position)
            var collected = false
            for _ in 0..<120 {
                tick(&c, order: order)
                guard let orb = c.orbs.first else { collected = true; break }
                let now = world.distance(orb.position, guest.position)
                XCTAssertLessThanOrEqual(now, previous + 0.0001, "the orb moved away from the guest (order \(order))")
                XCTAssertGreaterThan(orb.position.x, 60, "the orb was pulled toward the host (order \(order))")
                previous = now
            }
            XCTAssertTrue(collected, "the guest never collected it (order \(order))")
            XCTAssertEqual(c.experienceCollected, 5)
        }
    }

    func testAnOrbFliesAtOneHeroesSpeedNotTwo() {
        var c = combat()
        c.orbs.append(ExperienceOrb(id: 1, position: CGPoint(x: 62.6, y: 64), value: 5))
        tick(&c, order: [0, 1])
        tick(&c, order: [0, 1])
        // Two ticks at 3 then about 3.5 tiles a second is a few hundredths of a tile.
        XCTAssertGreaterThan(c.orbs[0].position.x, 62.6, "it should have moved toward the guest")
        XCTAssertLessThan(c.orbs[0].position.x - 62.6, 0.16, "it moved as if two heroes were pulling")
    }

    func testAnOrbChangesHandsWhenItsHeroIsGoneOrAnotherIsClearlyNearer() {
        var c = combat()
        var orb = ExperienceOrb(id: 1, position: CGPoint(x: 62.6, y: 64), value: 5)
        orb.attracted = true
        orb.speed = 3
        orb.claimedBy = 0
        c.orbs.append(orb)
        // Hero 0 is far away and out of range: the orb stays claimed but does not move for hero 1 unless nearer.
        let before = c.orbs[0].position
        var far = targets
        far[0].position = CGPoint(x: 62.7, y: 64)     // the claimant is right beside it
        PickupSystem.step(&c, player: guest, hero: 1, targets: far, dt: dt)
        XCTAssertEqual(c.orbs[0].position.x, before.x, accuracy: 0.0001, "the guest is not clearly nearer, so it does not take it")
        XCTAssertEqual(c.orbs[0].claimedBy, 0)

        // The claimant goes down: the next hero to gather takes it.
        var gone = targets
        gone[0].isAlive = false
        PickupSystem.step(&c, player: guest, hero: 1, targets: gone, dt: dt)
        XCTAssertEqual(c.orbs.first?.claimedBy ?? 1, 1)
    }

    // MARK: Shrines

    private func party(_ count: Int) -> GameSimulation {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 11)
        let heroes = (0..<count).map { index in
            PartyHeroConfig(id: "o\(index)", name: "Hero \(index)", slot: index, weaponID: StarterWeapons.sword.id,
                            legacy: [])
        }
        return GameSimulation(run: run, tuning: .standard, party: heroes)
    }

    func testAShrineIsRaisedNearAnyStandingHeroNotAlwaysTheHost() {
        var sim = party(2)
        let home = sim.arena.playerSpawn
        sim.perform(as: 0) { $0.player.position = home; $0.combat.playerPosition = home }
        let far = sim.world.wrap(home + CGPoint(x: 50, y: 0))
        sim.perform(as: 1) { $0.player.position = far; $0.combat.playerPosition = far }
        var chosen = Set<Int>()
        for _ in 0..<40 {
            let anchor = sim.randomStandingPlayer()
            chosen.insert(sim.world.distance(anchor.position, home) < 5 ? 0 : 1)
        }
        XCTAssertEqual(chosen, [0, 1], "shrines should appear near either player")
    }

    func testALoneHeroIsAlwaysTheAnchorAndUsesNoRandomness() {
        var sim = party(1)
        let before = sim.combat.lootRandom.unit()
        var again = party(1)
        _ = again.randomStandingPlayer()
        XCTAssertEqual(again.combat.lootRandom.unit(), before, "picking the only hero must not disturb the loot stream")
    }

    func testAMagnetSendsEveryOrbToWhoeverTookIt() {
        var c = combat()
        c.orbs.append(ExperienceOrb(id: 1, position: CGPoint(x: 50, y: 64), value: 3))
        c.drops.append(Drop(id: 2, kind: .magnet, position: CGPoint(x: 64.1, y: 64)))
        c.drops[0].attracted = true
        c.drops[0].claimedBy = 1
        tick(&c, order: [0, 1])
        XCTAssertTrue(c.orbs.first?.attracted ?? false)
        XCTAssertEqual(c.orbs.first?.claimedBy, 1, "the guest picked up the magnet, so the orbs are theirs")
    }
}
