import CoreGraphics
import SpriteKit
import XCTest
@testable import FateLost

/// A whole party run, host and guests, joined by the real codecs and no
/// network: the host simulates, each guest's input travels through
/// `NetInput` and `HostInput`, each guest's picture through `NetSnapshot`.
private struct Loopback {
    let dt: TimeInterval = 1.0 / 60
    var host: GameSimulation
    /// A mirror for every hero except the host.
    var guests: [Int: GameSimulation] = [:]
    let slots: [Int: UInt8]
    private var frame = 0
    private var sequence: UInt16 = 0

    /// What each guest's thumb and buttons are doing.
    var moves: [Int: CGPoint] = [:]
    var interact: Set<Int> = []

    init(heroes count: Int, seed: UInt64 = 11) {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: seed)
        let party = (0..<count).map { index in
            PartyHeroConfig(id: "p\(index)", name: ["Jesse", "Whitney", "Kevin", "Robin"][index], slot: index * 2 + 1,
                            weaponID: StarterWeapons.sword.id)
        }
        var sim = GameSimulation(run: run, tuning: .standard, party: party)
        sim.cheats = SimulationCheats(godMode: false, spawningEnabled: false)
        host = sim
        var seats: [Int: UInt8] = [:]
        for index in 0..<count {
            seats[index] = UInt8(index * 2 + 1)
            if index > 0 {
                var mirror = GameSimulation(run: run, tuning: .standard)
                mirror.beginMirroring(slot: UInt8(index * 2 + 1))
                guests[index] = mirror
            }
        }
        slots = seats
    }

    mutating func run(frames count: Int) {
        for _ in 0..<count { advance() }
    }

    private mutating func advance() {
        frame += 1
        // Guests send what they want; the host applies it.
        for index in guests.keys.sorted() {
            guard let mirror = guests[index] else { continue }
            var input = NetInput()
            sequence &+= 1
            input.sequence = sequence
            input.move = moves[index] ?? .zero
            input.interact = interact.contains(index)
            input.position = mirror.player.position
            let received = NetInput.decode(input.encoded())
            HostInput.apply(received, presses: 0, interact: received?.interact ?? false, toHero: index, in: &host)
        }
        host.step(dt: dt)
        // The host sends pictures (about every fourth frame at 60 Hz).
        let sendNow = frame % 4 == 0
        for index in guests.keys.sorted() {
            if sendNow, let snapshot = NetSnapshot.decode(host.snapshot(forViewer: index, radius: 26).encoded()) {
                guests[index]?.applyMirror(snapshot)
                let state = host.perform(as: index) { $0.captureSelfState() }
                if let data = try? JSONEncoder().encode(state), let decoded = try? JSONDecoder().decode(HeroSelfState.self, from: data) {
                    guests[index]?.applySelfState(decoded)
                }
            }
            var walking = PlayerIntent(move: moves[index] ?? .zero)
            walking.abilityPresses = 0
            guests[index]?.advanceMirror(dt: dt, intent: walking)
        }
        interact.removeAll()
    }

    func markers(seenBy index: Int) -> [NetMarker] {
        guests[index]?.mirror?.markers ?? []
    }

    func hero(_ slot: UInt8, seenBy index: Int) -> NetHero? {
        guests[index]?.mirror?.heroes.first { $0.slot == slot }
    }
}

final class PartyLoopbackTests: XCTestCase {
    private func addGoblin(_ sim: inout GameSimulation, at point: CGPoint, definition: EnemyDefinition = EnemyCatalog.goblin) {
        let kind = sim.combat.enemies.kindIndex(for: definition)
        sim.combat.enemies.append(id: sim.combat.makeEntityID(), kind: kind, position: point, speedScale: 1)
    }

    private func gather(_ loop: inout Loopback) {
        let home = loop.host.arena.playerSpawn
        for index in 0..<loop.host.heroCount {
            loop.host.perform(as: index) { sim in
                sim.player.position = sim.world.wrap(home + CGPoint(x: Double(index) * 1.2, y: 0))
                sim.combat.playerPosition = sim.player.position
            }
        }
        for (index, _) in loop.guests {
            loop.guests[index]?.applyMirror(loop.host.snapshot(forViewer: index, radius: 26))
        }
    }

    func testPlayersSeeEachOtherAndMovementSynchronises() {
        var loop = Loopback(heroes: 3)
        gather(&loop)
        loop.moves[1] = CGPoint(x: 1, y: 0)
        loop.moves[2] = CGPoint(x: 0, y: 1)
        loop.run(frames: 180)

        let host1 = loop.host.playerState(of: 1).position
        let host2 = loop.host.playerState(of: 2).position
        let mine1 = loop.guests[1]!.player.position
        // Each guest's own screen and the host agree about them.
        XCTAssertEqual(loop.host.world.distance(host1, mine1), 0, accuracy: 0.8)
        XCTAssertEqual(loop.host.world.distance(host2, loop.guests[2]!.player.position), 0, accuracy: 0.8)
        // And every screen shows every hero about where the host has them.
        for viewer in [1, 2] {
            for (hero, position) in [(1, host1), (2, host2), (0, loop.host.playerState(of: 0).position)] {
                let seen = loop.hero(loop.slots[hero]!, seenBy: viewer)
                XCTAssertNotNil(seen)
                XCTAssertEqual(loop.host.world.distance(seen!.position, position), 0, accuracy: 1.2,
                               "guest \(viewer) sees hero \(hero) in the wrong place")
            }
        }
        // Guests are in motion, not stuck.
        XCTAssertGreaterThan(loop.host.world.distance(host1, loop.host.arena.playerSpawn), 3)
    }

    func testFightsAreSharedEnemiesAppearAndFallOnEveryScreen() {
        var loop = Loopback(heroes: 3)
        gather(&loop)
        let home = loop.host.arena.playerSpawn
        for offset in 0..<8 {
            addGoblin(&loop.host, at: loop.host.world.wrap(home + CGPoint(x: 3 + Double(offset) * 0.4, y: Double(offset % 3))))
        }
        loop.run(frames: 8)
        let before = loop.guests[1]!.enemies.count
        XCTAssertGreaterThan(before, 0, "the guests see the horde")
        XCTAssertEqual(before, loop.guests[2]!.enemies.count)

        // The heroes fight; the horde thins on the host and on every screen.
        loop.run(frames: 480)
        loop.run(frames: 4)
        let hostIDs = Set((0..<loop.host.enemies.count).map { loop.host.enemies.ids[$0] })
        for viewer in [1, 2] {
            let mirror = loop.guests[viewer]!
            let seen = Set((0..<mirror.enemies.count).map { mirror.enemies.ids[$0] })
            XCTAssertTrue(seen.isSubset(of: hostIDs), "a screen shows an enemy the host has already killed")
            XCTAssertLessThan(mirror.enemies.count, before + 1)
        }
        XCTAssertLessThan(loop.host.enemies.count, 8, "somebody's weapon landed")
    }

    func testAGuestKeepsWalkingAtFullSpeedWhileTheHostLiesFallen() {
        var loop = Loopback(heroes: 2)
        gather(&loop)
        loop.host.combat.incidents.append(.strikeHero(hero: 0, amount: 100_000, direction: CGPoint(x: 1, y: 0)))
        loop.run(frames: 30)
        XCTAssertTrue(loop.host.playerState(of: 0).isDefeated)

        let start = loop.guests[1]!.player.position
        loop.moves[1] = CGPoint(x: 1, y: 0)
        loop.run(frames: 240)
        let guestScreen = loop.guests[1]!.player.position
        let hostView = loop.host.playerState(of: 1).position
        // Four seconds at 4.2 tiles a second, less the moment it takes to get going.
        XCTAssertGreaterThan(loop.host.world.distance(start, guestScreen), 4.2 * 4 * 0.85, "the guest was held back")
        XCTAssertGreaterThan(loop.host.world.distance(start, hostView), 4.2 * 4 * 0.8, "the host did not move the guest")
    }

    func testALaggingSnapshotDoesNotSlowAGuestDown() {
        var loop = Loopback(heroes: 2)
        gather(&loop)
        let start = loop.guests[1]!.player.position
        loop.moves[1] = CGPoint(x: 1, y: 0)
        loop.run(frames: 60)
        // A snapshot that is a third of a second old, as on a poor connection.
        var laggy = loop.host.snapshot(forViewer: 1, radius: 26)
        let behind = loop.host.playerState(of: 1).position - CGPoint(x: 4.2 * 0.33, y: 0)
        for index in laggy.heroes.indices where laggy.heroes[index].slot == loop.slots[1] {
            laggy.heroes[index].position = behind
        }
        let before = loop.guests[1]!.player.position
        for _ in 0..<15 {
            loop.guests[1]?.applyMirror(laggy)
        }
        XCTAssertEqual(loop.guests[1]!.player.position.x, before.x, accuracy: 0.001,
                       "lag alone must not drag a walking guest back")
        XCTAssertGreaterThan(before.x - start.x, 3)
    }

    func testAnAreaHealHealsFriendsAndTheirScreensShowIt() {
        var loop = Loopback(heroes: 3)
        gather(&loop)
        for index in 0..<3 { loop.host.perform(as: index) { $0.player.health = 40 } }
        loop.host.perform(as: 0) { sim in
            sim.combat.pendingActions.append(QueuedAction(action: .heal(RankValue(0.25)), origin: sim.player.position,
                                                          targetID: nil, direction: CGPoint(x: 1, y: 0), depth: 0,
                                                          ability: "test.ability"))
        }
        loop.run(frames: 12)
        for index in 0..<3 {
            XCTAssertEqual(loop.host.playerState(of: index).health, 65, accuracy: 2, "hero \(index)")
        }
        // A guest's own health bar follows.
        XCTAssertEqual(loop.guests[1]!.player.health, 65, accuracy: 2)
        XCTAssertEqual(loop.hero(loop.slots[2]!, seenBy: 1)?.health ?? 0, 65, accuracy: 2)
    }

    func testDeathMarkerReviveAndTheReturnToTheFight() {
        var loop = Loopback(heroes: 3)
        gather(&loop)
        loop.host.combat.incidents.append(.strikeHero(hero: 2, amount: 100_000, direction: CGPoint(x: 1, y: 0)))
        loop.run(frames: 12)

        XCTAssertTrue(loop.host.playerState(of: 2).isDefeated)
        XCTAssertFalse(loop.host.isPartyWiped, "one death does not end the run")
        // Every screen has the marker, at the same place, named by seat.
        for viewer in [1, 2] {
            XCTAssertEqual(loop.markers(seenBy: viewer).map { $0.slot }, [UInt8(5)])
        }
        XCTAssertTrue(loop.hero(5, seenBy: 1)?.isDefeated ?? false)
        XCTAssertTrue(loop.guests[2]!.player.isDefeated, "the fallen player's own screen knows")

        // A friend beside the marker starts the revive.
        let marker = loop.host.reviveMarkers[0].position
        loop.host.perform(as: 1) { sim in
            sim.player.position = sim.world.wrap(marker + CGPoint(x: 1, y: 0))
            sim.combat.playerPosition = sim.player.position
        }
        loop.guests[1]?.applyMirror(loop.host.snapshot(forViewer: 1, radius: 26))
        loop.interact.insert(1)
        loop.run(frames: 8)
        XCTAssertEqual(loop.host.reviveMarkers.first?.reviver, 1)
        XCTAssertNotNil(loop.markers(seenBy: 2).first?.reviver, "the fallen player sees a friend at work")

        // Struck while channelling: broken, and every screen sees it break.
        loop.run(frames: 60)
        loop.host.combat.incidents.append(.strikeHero(hero: 1, amount: 3, direction: CGPoint(x: 1, y: 0)))
        loop.run(frames: 8)
        XCTAssertNil(loop.host.reviveMarkers.first?.reviver)
        XCTAssertNil(loop.markers(seenBy: 2).first?.reviver)

        // Again, and finish.
        loop.run(frames: 60)
        loop.interact.insert(1)
        loop.run(frames: 8)
        loop.run(frames: Int(loop.host.tuning.party.reviveSeconds * 60) + 20)
        XCTAssertFalse(loop.host.playerState(of: 2).isDefeated)
        XCTAssertTrue(loop.host.reviveMarkers.isEmpty)
        XCTAssertTrue(loop.markers(seenBy: 1).isEmpty)
        XCTAssertFalse(loop.guests[2]!.player.isDefeated, "the revived player's own screen agrees")
        XCTAssertEqual(loop.guests[2]!.player.health, loop.host.playerState(of: 2).health, accuracy: 3)
    }

    func testWhenEveryoneFallsTheRunIsOverForTheWholeParty() {
        var loop = Loopback(heroes: 4)
        gather(&loop)
        for hero in 0..<4 {
            loop.host.combat.incidents.append(.strikeHero(hero: hero, amount: 100_000, direction: CGPoint(x: 1, y: 0)))
        }
        loop.run(frames: 90)
        XCTAssertTrue(loop.host.isPartyWiped)
        XCTAssertNotNil(loop.host.timeSinceWipe)
        XCTAssertEqual(loop.host.reviveMarkers.count, 4)
        for viewer in 1...3 {
            XCTAssertEqual(loop.markers(seenBy: viewer).count, 4)
            XCTAssertTrue(loop.guests[viewer]!.player.isDefeated)
        }
    }

    func testTheNextRunStartsFreshWithTheSameParty() {
        var first = Loopback(heroes: 3, seed: 21)
        gather(&first)
        first.host.combat.incidents.append(.strikeHero(hero: 1, amount: 100_000, direction: CGPoint(x: 1, y: 0)))
        first.host.spawnEnemies(20)
        first.run(frames: 200)
        XCTAssertGreaterThan(first.host.elapsed, 3)
        XCTAssertFalse(first.host.reviveMarkers.isEmpty)

        // Run two: the same three people, a fresh seed, a new simulation.
        var second = Loopback(heroes: 3, seed: 22)
        XCTAssertEqual(second.host.elapsed, 0)
        XCTAssertTrue(second.host.reviveMarkers.isEmpty)
        XCTAssertEqual(second.host.enemies.count, 0)
        XCTAssertEqual(second.host.combat.orbs.count, 0)
        XCTAssertNil(second.host.timeSinceWipe)
        XCTAssertEqual(second.host.wave.index, 1)
        for index in 0..<3 {
            let state = second.host.playerState(of: index)
            XCTAssertEqual(state.health, state.maxHealth, "hero \(index) starts whole")
            XCTAssertEqual(second.host.perform(as: index) { $0.progression.level } , 1)
            XCTAssertEqual(second.host.perform(as: index) { $0.relics.count }, 0)
            XCTAssertEqual(second.host.perform(as: index) { $0.combat.stats.kills }, 0)
        }
        XCTAssertEqual(second.host.heroSummaries.map { $0.name }, first.host.heroSummaries.map { $0.name })
        XCTAssertNotEqual(second.host.arena.playerSpawn, .zero)
    }

    func testAGuestsBuildDecisionsTravelToTheHostAndBack() throws {
        var loop = Loopback(heroes: 2)
        gather(&loop)
        loop.host.perform(as: 1) { $0.grantLevels(3) }
        loop.run(frames: 12)
        XCTAssertEqual(loop.guests[1]!.progression.level, 4)
        let points = loop.guests[1]!.progression.unspentPoints
        XCTAssertGreaterThan(points, 0)

        // The guest picks a skill; the command is the same JSON the network carries.
        let skill = SkillCatalog.skills(for: .warrior).first { $0.tier == .one }!
        var draft = SkillAllocation()
        draft.add(skill)
        let command = NetCommand(kind: .commit, ranks: draft.ranks, slots: [nil, nil, nil, nil])
        let arrived = try XCTUnwrap(NetCommand.decode(command.encoded()))
        HostInput.apply(arrived, toHero: 1, in: &loop.host)
        loop.run(frames: 12)
        XCTAssertEqual(loop.host.perform(as: 1) { $0.allocation.rank(of: skill.id) }, 1)
        XCTAssertEqual(loop.guests[1]!.allocation.rank(of: skill.id), 1, "and the host's word reaches their screen")
        XCTAssertEqual(loop.guests[1]!.progression.unspentPoints, points - 1)
    }

    func testAGuestWhoLiesAboutWhereTheyAreDoesNotTeleport() {
        var loop = Loopback(heroes: 2)
        gather(&loop)
        let honest = loop.host.playerState(of: 1).position
        var lie = NetInput()
        lie.position = loop.host.world.wrap(honest + CGPoint(x: 40, y: 0))
        HostInput.apply(NetInput.decode(lie.encoded()), presses: 0, interact: false, toHero: 1, in: &loop.host)
        XCTAssertEqual(loop.host.world.distance(loop.host.playerState(of: 1).position, honest), 0, accuracy: 0.001)
        var small = NetInput()
        small.position = loop.host.world.wrap(honest + CGPoint(x: 1, y: 0))
        HostInput.apply(NetInput.decode(small.encoded()), presses: 0, interact: false, toHero: 1, in: &loop.host)
        // A believable report is walked toward, a share at a time: never a step.
        let firstStep = loop.host.world.distance(loop.host.playerState(of: 1).position, honest)
        XCTAssertEqual(firstStep, HostInput.adoptionShare, accuracy: 0.05)
        for _ in 0..<14 {
            HostInput.apply(NetInput.decode(small.encoded()), presses: 0, interact: false, toHero: 1, in: &loop.host)
        }
        XCTAssertEqual(loop.host.world.distance(loop.host.playerState(of: 1).position, honest), 1, accuracy: 0.05)
    }

    func testAGuestCannotMoveAFallenHeroOrRevivedHeroInstantly() {
        var loop = Loopback(heroes: 2)
        gather(&loop)
        loop.host.combat.incidents.append(.strikeHero(hero: 1, amount: 100_000, direction: CGPoint(x: 1, y: 0)))
        loop.run(frames: 6)
        let body = loop.host.playerState(of: 1).position
        var input = NetInput()
        input.move = CGPoint(x: 1, y: 0)
        input.position = loop.host.world.wrap(body + CGPoint(x: 1, y: 0))
        HostInput.apply(input, presses: 0b1111, interact: true, toHero: 1, in: &loop.host)
        loop.host.step(dt: 1.0 / 60)
        XCTAssertEqual(loop.host.world.distance(loop.host.playerState(of: 1).position, body), 0, accuracy: 0.001)
    }
}

@MainActor
final class FallenAllyIndicatorTests: XCTestCase {
    private let screen = CGSize(width: 800, height: 360)

    private func arrows(in layer: BeaconLayer) -> [SKShapeNode] {
        layer.children.compactMap { $0 as? SKShapeNode }
    }

    private func labels(in layer: BeaconLayer) -> [SKLabelNode] {
        layer.children.compactMap { $0 as? SKLabelNode }
    }

    func testAnArrowPointsTowardAFallenFriendWhoIsOffScreenAndNamesThem() throws {
        let layer = BeaconLayer()
        let mark = BeaconMark(id: -1005, offset: CGPoint(x: 900, y: 0), color: .white, label: "Kevin", isFallenAlly: true)
        layer.show([mark], screenSize: screen, time: 0)
        let arrow = try XCTUnwrap(arrows(in: layer).first { !$0.isHidden })
        XCTAssertEqual(arrow.zRotation, 0, accuracy: 0.001, "pointing right")
        XCTAssertLessThanOrEqual(arrow.position.x, screen.width / 2, "at the edge, not off it")
        XCTAssertEqual(labels(in: layer).first { !$0.isHidden }?.text, "Kevin")
    }

    func testTheArrowTurnsAsThePlayerMovesAround() throws {
        let layer = BeaconLayer()
        let fromAbove = BeaconMark(id: 1, offset: CGPoint(x: 0, y: 900), color: .white, label: "Kevin", isFallenAlly: true)
        layer.show([fromAbove], screenSize: screen, time: 0)
        XCTAssertEqual(try XCTUnwrap(arrows(in: layer).first { !$0.isHidden }).zRotation, .pi / 2, accuracy: 0.001)
        let behind = BeaconMark(id: 1, offset: CGPoint(x: -900, y: 0), color: .white, label: "Kevin", isFallenAlly: true)
        layer.show([behind], screenSize: screen, time: 0)
        let turned = try XCTUnwrap(arrows(in: layer).first { !$0.isHidden }).zRotation
        XCTAssertEqual(abs(turned), .pi, accuracy: 0.001)
    }

    func testTheArrowVanishesWhenTheFriendIsOnScreenOrRevived() {
        let layer = BeaconLayer()
        layer.show([BeaconMark(id: 1, offset: CGPoint(x: 100, y: 20), color: .white, label: "Kevin", isFallenAlly: true)],
                   screenSize: screen, time: 0)
        XCTAssertTrue(arrows(in: layer).allSatisfy { $0.isHidden }, "on screen, the marker itself is the signal")
        layer.show([BeaconMark(id: 1, offset: CGPoint(x: 900, y: 20), color: .white, label: "Kevin", isFallenAlly: true)],
                   screenSize: screen, time: 0)
        XCTAssertTrue(arrows(in: layer).contains { !$0.isHidden })
        layer.show([], screenSize: screen, time: 0)
        XCTAssertTrue(arrows(in: layer).allSatisfy { $0.isHidden }, "revived, no marker, no arrow")
        XCTAssertTrue(labels(in: layer).allSatisfy { $0.isHidden })
    }

    func testSeveralFallenFriendsAreEachShownAndAShrineStillPointsToo() {
        let layer = BeaconLayer()
        let marks = [
            BeaconMark(id: -1001, offset: CGPoint(x: 900, y: 0), color: .white, label: "Whitney", isFallenAlly: true),
            BeaconMark(id: -1003, offset: CGPoint(x: -900, y: 100), color: .white, label: "Kevin", isFallenAlly: true),
            BeaconMark(id: 7, offset: CGPoint(x: 0, y: -900), color: .orange),
        ]
        layer.show(marks, screenSize: screen, time: 0)
        XCTAssertEqual(arrows(in: layer).filter { !$0.isHidden }.count, 3)
        XCTAssertEqual(Set(labels(in: layer).filter { !$0.isHidden }.compactMap { $0.text }), ["Whitney", "Kevin"])
    }
}
