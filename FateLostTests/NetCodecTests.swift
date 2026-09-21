import CoreGraphics
import Foundation
import XCTest
@testable import FateLost

final class ByteCodecTests: XCTestCase {
    func testEveryPrimitiveRoundTrips() {
        var writer = ByteWriter()
        writer.u8(200)
        writer.u16(51_234)
        writer.u32(4_000_000_123)
        writer.i8(-100)
        writer.i16(-20_000)
        writer.f32(3.25)
        writer.bool(true)
        writer.coord(-12.5)
        writer.point(CGPoint(x: 100.0625, y: 3.5))
        writer.fraction(0.5)
        writer.string("Wanderer \u{1F409}")

        var reader = ByteReader(writer.data)
        XCTAssertEqual(reader.u8(), 200)
        XCTAssertEqual(reader.u16(), 51_234)
        XCTAssertEqual(reader.u32(), 4_000_000_123)
        XCTAssertEqual(reader.i8(), -100)
        XCTAssertEqual(reader.i16(), -20_000)
        XCTAssertEqual(reader.f32(), 3.25)
        XCTAssertTrue(reader.bool())
        XCTAssertEqual(reader.coord(), -12.5, accuracy: 0.001)
        let point = reader.point()
        XCTAssertEqual(point.x, 100.0625, accuracy: 0.001)
        XCTAssertEqual(point.y, 3.5, accuracy: 0.001)
        XCTAssertEqual(reader.fraction(), 0.5, accuracy: 0.005)
        XCTAssertEqual(reader.string(), "Wanderer \u{1F409}")
        XCTAssertTrue(reader.isAtEnd)
        XCTAssertFalse(reader.failed)
    }

    func testPositionsKeepAboutAHundredthOfATile() {
        for value in stride(from: -50.0, through: 200.0, by: 7.3137) {
            var writer = ByteWriter()
            writer.coord(CGFloat(value))
            var reader = ByteReader(writer.data)
            XCTAssertEqual(Double(reader.coord()), value, accuracy: 0.04)
        }
    }

    func testDirectionsSurviveAsAnAngle() {
        for degrees in stride(from: 0.0, to: 360.0, by: 15.0) {
            let radians = degrees * .pi / 180
            let vector = CGPoint(x: cos(radians), y: sin(radians))
            var writer = ByteWriter()
            writer.direction(vector)
            var reader = ByteReader(writer.data)
            let back = reader.direction()
            XCTAssertEqual(back.length, 1, accuracy: 0.001)
            XCTAssertEqual(back.x, vector.x, accuracy: 0.03)
            XCTAssertEqual(back.y, vector.y, accuracy: 0.03)
        }
        var writer = ByteWriter()
        writer.direction(.zero)
        var reader = ByteReader(writer.data)
        XCTAssertEqual(reader.direction().length, 1, accuracy: 0.001, "no direction is sent as a direction")
    }

    func testAReadPastTheEndFailsQuietly() {
        var reader = ByteReader(Data([1, 2]))
        XCTAssertEqual(reader.u16(), 0x0201)
        XCTAssertEqual(reader.u32(), 0)
        XCTAssertTrue(reader.failed)
        XCTAssertEqual(reader.u8(), 0, "once failed, everything reads as zero")
    }

    func testAStringLongerThanTheLimitIsCutOnACharacterBoundary() {
        var writer = ByteWriter()
        writer.string(String(repeating: "\u{1F409}", count: 30))
        var reader = ByteReader(writer.data)
        let text = reader.string()
        XCTAssertFalse(reader.failed)
        XCTAssertTrue(text.allSatisfy { $0 == "\u{1F409}" })
        XCTAssertLessThanOrEqual(text.utf8.count, 60)
        XCTAssertFalse(text.isEmpty)
    }

    func testAStringThatClaimsToBeLongerThanTheDataFails() {
        var reader = ByteReader(Data([50, 65, 66]))
        _ = reader.string()
        XCTAssertTrue(reader.failed)
    }

    func testVelocitiesFitOneByteUpToFifteenTilesASecond() {
        for value in [-15.0, -4.2, 0, 0.3, 4.2, 15.0] {
            let byte = NetScale.velocityByte(CGFloat(value))
            XCTAssertEqual(Double(NetScale.velocity(fromByte: byte)), value, accuracy: 0.07)
        }
        XCTAssertEqual(NetScale.velocityByte(1_000), 127, "faster than the wire can say is clamped")
    }

    func testHashesOfEveryKnownThingAreDistinct() {
        XCTAssertEqual(NetTables.spriteByHash.count, Set(GameplaySprites.all).count, "a sprite hash collided")
        XCTAssertEqual(NetTables.enemyByHash.count, Set(EnemyCatalog.all.map { $0.id }).count, "an enemy hash collided")
    }
}

/// A snapshot has to carry a fight's worth of things, in a frame the relay allows.
final class NetSnapshotTests: XCTestCase {
    private func rich() -> NetSnapshot {
        var snapshot = NetSnapshot()
        snapshot.tickMilliseconds = 123_456
        snapshot.wave = NetWave(index: 7, phase: NetWave.bossFight, bossFraction: 0.4, bossTitle: "Grukk, Warchief",
                                curseSeconds: 12)
        snapshot.heroes = [
            NetHero(slot: 0, flags: NetHero.connected, position: CGPoint(x: 64.5, y: 30.25), velocity: CGPoint(x: 3, y: -1.5),
                    facing: CGPoint(x: 0, y: 1), health: 88, maxHealth: 120, barrier: 20, level: 9,
                    weaponSprite: .weaponSword, form: nil),
            NetHero(slot: 2, flags: NetHero.connected | NetHero.defeated, position: CGPoint(x: 70, y: 32), velocity: .zero,
                    facing: CGPoint(x: 1, y: 0), health: 0, maxHealth: 140, barrier: 0, level: 8,
                    weaponSprite: .weaponBow, form: "form.bear"),
        ]
        snapshot.markers = [NetMarker(slot: 2, position: CGPoint(x: 70, y: 32), progress: 0.5, reviver: 0)]
        var enemies: [NetEnemy] = []
        for index in 0..<40 {
            let x: Double = 60 + Double(index) * 0.5
            let windup: Double = index % 5 == 0 ? 0.5 : 0
            let enemy = NetEnemy(id: UInt32(1000 + index), kind: NetTables.hash16(EnemyCatalog.goblin.id),
                                 strain: UInt8(index % 3), position: CGPoint(x: x, y: 28), healthFraction: 0.75,
                                 heading: CGPoint(x: -1, y: 0), statusMask: UInt16(index % 4), windupFraction: windup,
                                 aim: CGPoint(x: 0, y: 1), isCharging: index == 7)
            enemies.append(enemy)
        }
        snapshot.enemies = enemies
        snapshot.projectiles = [
            NetProjectile(id: 9, position: CGPoint(x: 65, y: 31), velocity: CGPoint(x: 12, y: 0),
                          sprite: NetTables.hash(of: .projectileArrow), visual: 1, radius: 0.25, isHostile: false),
            NetProjectile(id: 10, position: CGPoint(x: 66, y: 31), velocity: CGPoint(x: -8, y: 1),
                          sprite: NetTables.hash(of: .projectileBolt), visual: 2, radius: 0.22, isHostile: true),
        ]
        snapshot.zones = [NetZone(id: 20, position: CGPoint(x: 64, y: 30), radius: 3.5, visual: 5, isAura: false, remaining: 4.5),
                          NetZone(id: 21, position: CGPoint(x: 64, y: 30), radius: 2, visual: 3, isAura: true, remaining: nil)]
        snapshot.allies = [NetAlly(id: 30, position: CGPoint(x: 63, y: 30), heading: CGPoint(x: 0, y: -1),
                                   sprite: NetTables.hash(of: .allyBear), scale: 1.25, tint: [200, 100, 50],
                                   behavior: NetAlly.melee, visual: 0, healthFraction: 0.6, attackedRecently: true),
                           NetAlly(id: 31, position: CGPoint(x: 62, y: 30), heading: CGPoint(x: 1, y: 0),
                                   sprite: NetTables.hash(of: .allyBlade), scale: 1, tint: nil,
                                   behavior: NetAlly.orbit, visual: 3, healthFraction: nil, attackedRecently: false)]
        snapshot.orbs = [NetOrb(id: 40, position: CGPoint(x: 61, y: 33), value: 12, attracted: true)]
        snapshot.drops = [NetDrop(id: 50, position: CGPoint(x: 67, y: 29), code: NetTables.dropCode(.chest(.hoard)), attracted: false)]
        snapshot.shrines = [NetShrine(id: 60, position: CGPoint(x: 80, y: 20), kind: NetTables.shrineIndex(.ruin))]
        return snapshot
    }

    func testARichSnapshotRoundTrips() throws {
        let original = rich()
        let decoded = try XCTUnwrap(NetSnapshot.decode(original.encoded()))
        XCTAssertEqual(decoded.tickMilliseconds, original.tickMilliseconds)
        XCTAssertEqual(decoded.wave, original.wave)
        XCTAssertEqual(decoded.heroes.count, 2)
        XCTAssertEqual(decoded.heroes[1].form, "form.bear")
        XCTAssertEqual(decoded.heroes[1].isDefeated, true)
        XCTAssertEqual(decoded.heroes[0].weaponSprite, .weaponSword)
        XCTAssertEqual(decoded.heroes[0].health, 88)
        XCTAssertEqual(decoded.heroes[0].position.x, 64.5, accuracy: 0.01)
        XCTAssertEqual(decoded.markers.count, 1)
        XCTAssertEqual(decoded.markers[0].reviver, 0)
        XCTAssertEqual(decoded.markers[0].progress, 0.5, accuracy: 0.01)
        XCTAssertEqual(decoded.enemies.count, 40)
        XCTAssertEqual(decoded.enemies[7].isCharging, true)
        XCTAssertEqual(decoded.enemies[5].windupFraction, 0.5, accuracy: 0.01)
        XCTAssertEqual(decoded.enemies[3].id, 1003)
        XCTAssertEqual(decoded.projectiles.map { $0.isHostile }, [false, true])
        XCTAssertEqual(decoded.zones[0].remaining ?? 0, 4.5, accuracy: 0.1)
        XCTAssertNil(decoded.zones[1].remaining)
        XCTAssertEqual(decoded.allies[0].tint, [200, 100, 50])
        XCTAssertNil(decoded.allies[1].healthFraction)
        XCTAssertEqual(decoded.orbs[0].value, 12)
        XCTAssertEqual(NetTables.drop(decoded.drops[0].code), .chest(.hoard))
        XCTAssertEqual(NetTables.shrine(decoded.shrines[0].kind), .ruin)
    }

    private func crowd(_ count: Int) -> [NetEnemy] {
        var list: [NetEnemy] = []
        let kind = NetTables.hash16(EnemyCatalog.goblin.id)
        let right = CGPoint(x: 1, y: 0)
        for index in 0..<count {
            list.append(NetEnemy(id: UInt32(index), kind: kind, strain: 1, position: CGPoint(x: 10, y: 10),
                                 healthFraction: 1, heading: right, statusMask: 0xFFFF, windupFraction: 1, aim: right,
                                 isCharging: true))
        }
        return list
    }

    func testAFullFightStillFitsTheRelaysLimit() {
        var snapshot = rich()
        snapshot.enemies = crowd(NetSnapshot.Limit.enemies)
        var shots: [NetProjectile] = []
        for index in 0..<NetSnapshot.Limit.projectiles {
            shots.append(NetProjectile(id: UInt32(index), position: .zero, velocity: .zero, sprite: 1, visual: 0,
                                       radius: 0.2, isHostile: true))
        }
        snapshot.projectiles = shots
        var friends: [NetAlly] = []
        for index in 0..<NetSnapshot.Limit.allies {
            friends.append(NetAlly(id: UInt32(index), position: .zero, heading: CGPoint(x: 1, y: 0), sprite: 1, scale: 1,
                                   tint: [1, 2, 3], behavior: 1, visual: 0, healthFraction: 1, attackedRecently: true))
        }
        snapshot.allies = friends
        var orbs: [NetOrb] = []
        for index in 0..<NetSnapshot.Limit.orbs {
            orbs.append(NetOrb(id: UInt32(index), position: .zero, value: 1, attracted: true))
        }
        snapshot.orbs = orbs
        var zones: [NetZone] = []
        for index in 0..<NetSnapshot.Limit.zones {
            zones.append(NetZone(id: UInt32(index), position: .zero, radius: 3, visual: 0, isAura: false, remaining: 5))
        }
        snapshot.zones = zones
        let size = snapshot.encoded().count
        XCTAssertLessThan(size, PartyProtocol.maxHostFrame, "\(size) bytes")
    }

    func testMoreThanTheLimitIsCutNotSent() {
        var snapshot = NetSnapshot()
        snapshot.enemies = crowd(NetSnapshot.Limit.enemies + 200)
        let decoded = NetSnapshot.decode(snapshot.encoded())
        XCTAssertEqual(decoded?.enemies.count, NetSnapshot.Limit.enemies)
    }

    func testAnEmptySnapshotIsTiny() {
        XCTAssertLessThan(NetSnapshot().encoded().count, 32)
    }

    func testASnapshotFromDifferentContentIsRefused() {
        var bytes = Array(rich().encoded())
        bytes[0] = NetTables.contentVersion &+ 1
        XCTAssertNil(NetSnapshot.decode(Data(bytes)))
    }

    func testTruncatedAndBrokenSnapshotsNeverCrash() {
        let good = Array(rich().encoded())
        for length in [0, 1, 5, 20, good.count / 2, good.count - 1] {
            XCTAssertNil(NetSnapshot.decode(Data(good.prefix(length))), "length \(length)")
        }
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<400 {
            var junk = (0..<Int.random(in: 0...300, using: &generator)).map { _ in UInt8.random(in: 0...255, using: &generator) }
            if !junk.isEmpty { junk[0] = NetTables.contentVersion }
            _ = NetSnapshot.decode(Data(junk))
        }
        // A corrupted copy of a good one.
        for index in stride(from: 1, to: good.count, by: 17) {
            var corrupted = good
            corrupted[index] = corrupted[index] ^ 0xFF
            _ = NetSnapshot.decode(Data(corrupted))
        }
    }

    func testTooManyThingsClaimedIsRefused() {
        var writer = ByteWriter()
        writer.u8(NetTables.contentVersion)
        writer.u32(0)
        writer.u16(1); writer.u8(0); writer.u8(0); writer.u8(0); writer.string("")
        writer.u8(9) // nine heroes
        XCTAssertNil(NetSnapshot.decode(writer.data))
    }
}

final class NetEventCodecTests: XCTestCase {
    private var everyEvent: [CombatEvent] {
        let p = CGPoint(x: 12.5, y: 30.25)
        let d = CGPoint(x: 0, y: 1)
        return [
            .meleeSwing(origin: p, direction: d, range: 2.2, arcDegrees: 120),
            .projectileFired(spriteID: .projectileArrow, origin: p, direction: d),
            .enemyHit(enemyID: 77, position: p, amount: 41.5, isCritical: true, direction: d, type: .fire, isDot: false),
            .enemyKilled(enemyID: 77, kind: EnemyCatalog.goblin.id, position: p, direction: d),
            .enemyWindup(enemyID: 78),
            .burst(position: p, radius: 3, visual: .fire),
            .cone(origin: p, direction: d, range: 4, arcDegrees: 90, visual: .frost),
            .chain(points: [p, CGPoint(x: 14, y: 31), CGPoint(x: 15, y: 32)], visual: .lightning),
            .strikeIncoming(position: p, radius: 1.5, delay: 0.45, visual: .arcane),
            .bolt(position: p, visual: .lightning),
            .dash(from: p, to: CGPoint(x: 16, y: 30), visual: .shadow),
            .abilityCast(id: "renewal", visual: .holy),
            .summoned(position: p, visual: .nature),
            .allyFell(position: p, visual: .shadow),
            .summonsDismissed, .summonsRecalled,
            .enemyExploded(position: p, radius: 2.4),
            .playerHit(amount: 12, direction: d), .playerDodged, .playerHealed(amount: 30), .barrierGained,
            .stealthStarted, .formChanged("form.bear"), .formChanged(nil), .cheatedDeath,
            .waveBegan(wave: 9), .bossArrived(title: "Grukk, Warchief"), .bossDefeated(title: "Grukk, Warchief"),
            .realmConquered, .experienceCollected(amount: 25),
            .shrineAppeared(kind: .blood, position: p), .shrineUsed(kind: .fortune, position: p),
            .dropCollected(kind: .chest(.chest), position: p), .weaponWielded(title: "Keen Katana", rarity: .rare),
            .relicGained(id: "relic.whetstone", rank: 2), .levelUp(level: 12, position: p), .playerDefeated,
            .heroFell(hero: 2, position: p), .reviveStarted(hero: 2, reviver: 0), .reviveInterrupted(hero: 2),
            .heroRevived(hero: 2, position: p),
            .riftOpened(kind: .tides, position: p), .riftEntered(kind: .void),
        ]
    }

    private func nearlyEqual(_ a: CombatEvent, _ b: CombatEvent) -> Bool {
        // Positions are quantised and angles are a byte, so compare by re-encoding.
        NetEventCodec.encode([a], slotOf: { UInt8($0) }) == NetEventCodec.encode([b], slotOf: { UInt8($0) })
    }

    func testEveryKindOfEventRoundTrips() throws {
        let events = everyEvent
        XCTAssertEqual(events.count, 43)
        for event in events {
            let bytes = NetEventCodec.encode([event], slotOf: { UInt8($0) })
            let decoded = try XCTUnwrap(NetEventCodec.decode(bytes), "\(event)")
            XCTAssertEqual(decoded.count, 1)
            XCTAssertTrue(nearlyEqual(decoded[0], event), "\(event) came back as \(decoded[0])")
        }
    }

    func testExactFieldsSurvive() throws {
        let bytes = NetEventCodec.encode([
            .enemyHit(enemyID: 123_456, position: CGPoint(x: 5, y: 6), amount: 41.5, isCritical: true,
                      direction: CGPoint(x: 1, y: 0), type: .cold, isDot: true),
            .abilityCast(id: "hallowedGround", visual: .holy),
            .levelUp(level: 300, position: .zero),
            .experienceCollected(amount: 70_000),
        ], slotOf: { UInt8($0) })
        let events = try XCTUnwrap(NetEventCodec.decode(bytes))
        guard case .enemyHit(let id, _, let amount, let critical, _, let type, let dot) = events[0] else { return XCTFail() }
        XCTAssertEqual(id, 123_456)
        XCTAssertEqual(amount, 41.5, accuracy: 0.001)
        XCTAssertTrue(critical)
        XCTAssertTrue(dot)
        XCTAssertEqual(type, .cold)
        XCTAssertEqual(events[1], .abilityCast(id: "hallowedGround", visual: .holy))
        XCTAssertEqual(events[2], .levelUp(level: 300, position: .zero))
        XCTAssertEqual(events[3], .experienceCollected(amount: 70_000))
    }

    func testHeroNumbersTravelAsSeats() throws {
        // Hero 1 in the simulation sits in seat 3 on the relay.
        let bytes = NetEventCodec.encode([.heroFell(hero: 1, position: .zero)], slotOf: { $0 == 1 ? 3 : 0 })
        XCTAssertEqual(try XCTUnwrap(NetEventCodec.decode(bytes)), [.heroFell(hero: 3, position: .zero)])
    }

    func testTooManyHitsAreThinnedButNothingImportantIs() {
        var events: [CombatEvent] = (0..<200).map { index in
            .enemyHit(enemyID: index, position: .zero, amount: 5, isCritical: false, direction: CGPoint(x: 1, y: 0),
                      type: .physical, isDot: false)
        }
        events.append(.heroFell(hero: 1, position: .zero))
        events.append(.enemyHit(enemyID: 999, position: .zero, amount: 99, isCritical: true, direction: CGPoint(x: 1, y: 0),
                                type: .fire, isDot: false))
        events.append(.bossArrived(title: "Grukk"))
        let trimmed = NetEventCodec.trimmed(events)
        XCTAssertLessThanOrEqual(trimmed.count, NetEventCodec.maximumPerPacket)
        XCTAssertTrue(trimmed.contains(.heroFell(hero: 1, position: .zero)))
        XCTAssertTrue(trimmed.contains(.bossArrived(title: "Grukk")))
        XCTAssertTrue(trimmed.contains { if case .enemyHit(999, _, _, _, _, _, _) = $0 { return true } else { return false } })
    }

    func testUnknownAndBrokenEventDataIsRefused() {
        XCTAssertNil(NetEventCodec.decode(Data([1, 250])), "no such event")
        XCTAssertNil(NetEventCodec.decode(Data([3, 0])), "promises three, delivers one byte")
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let junk = (0..<Int.random(in: 0...80, using: &generator)).map { _ in UInt8.random(in: 0...255, using: &generator) }
            _ = NetEventCodec.decode(Data(junk))
        }
    }

    func testPersonalEventsAreTheOnesAboutTheHeroThemself() {
        XCTAssertTrue(CombatEvent.playerHit(amount: 1, direction: .zero).isPersonal)
        XCTAssertTrue(CombatEvent.levelUp(level: 2, position: .zero).isPersonal)
        XCTAssertTrue(CombatEvent.relicGained(id: "x", rank: 1).isPersonal)
        XCTAssertFalse(CombatEvent.burst(position: .zero, radius: 1, visual: .fire).isPersonal)
        XCTAssertFalse(CombatEvent.enemyKilled(enemyID: 1, kind: "k", position: .zero, direction: .zero).isPersonal)
        XCTAssertFalse(CombatEvent.heroFell(hero: 1, position: .zero).isPersonal)
        XCTAssertFalse(CombatEvent.abilityCast(id: "a", visual: .holy).isPersonal, "everyone sees a spell cast")
    }
}

final class NetInputTests: XCTestCase {
    func testInputRoundTrips() throws {
        var input = NetInput()
        input.sequence = 4_321
        input.move = CGPoint(x: 0.6, y: -0.8)
        input.abilityPresses = 0b0101
        input.interact = true
        input.menuOpen = true
        input.position = CGPoint(x: 50.25, y: 60.5)
        let decoded = try XCTUnwrap(NetInput.decode(input.encoded()))
        XCTAssertEqual(decoded.sequence, 4_321)
        XCTAssertEqual(decoded.move.x, 0.6, accuracy: 0.01)
        XCTAssertEqual(decoded.move.y, -0.8, accuracy: 0.01)
        XCTAssertEqual(decoded.abilityPresses, 0b0101)
        XCTAssertTrue(decoded.interact)
        XCTAssertTrue(decoded.menuOpen)
        XCTAssertEqual(decoded.position.x, 50.25, accuracy: 0.01)
    }

    func testAnInputIsTenBytes() {
        XCTAssertEqual(NetInput().encoded().count, 10)
    }

    func testAStickCannotPushHarderThanItsFullTravel() throws {
        var bytes = Array(NetInput().encoded())
        bytes[2] = 127
        bytes[3] = 127
        let decoded = try XCTUnwrap(NetInput.decode(Data(bytes)))
        XCTAssertEqual(decoded.move.length, 1, accuracy: 0.001)
    }

    func testPressesBeyondTheFourSlotsAreDropped() throws {
        var bytes = Array(NetInput().encoded())
        bytes[4] = 0xFF
        XCTAssertEqual(try XCTUnwrap(NetInput.decode(Data(bytes))).abilityPresses, 0x0F)
    }

    func testShortInputIsRefused() {
        XCTAssertNil(NetInput.decode(Data([1, 2, 3])))
        XCTAssertNil(NetInput.decode(Data()))
    }

    func testCommandsRoundTripAndAreBounded() throws {
        let command = NetCommand(kind: .commit, ranks: ["core.hallowedGround": 2], slots: ["a", nil, nil, nil])
        XCTAssertEqual(NetCommand.decode(command.encoded()), command)
        XCTAssertEqual(NetCommand.decode(NetCommand(kind: .chooseRelic, index: 2).encoded())?.index, 2)

        let tooManySkills = NetCommand(kind: .commit, ranks: Dictionary(uniqueKeysWithValues: (0..<500).map { ("s\($0)", 1) }))
        XCTAssertNil(NetCommand.decode(tooManySkills.encoded()))
        XCTAssertNil(NetCommand.decode(NetCommand(kind: .commit, ranks: ["x": 99]).encoded()), "no skill has ninety-nine ranks")
        XCTAssertNil(NetCommand.decode(NetCommand(kind: .commit, ranks: ["x": -1]).encoded()))
        XCTAssertNil(NetCommand.decode(NetCommand(kind: .equip, slots: ["a", "b", "c", "d", "e"]).encoded()))
        XCTAssertNil(NetCommand.decode(Data("not json".utf8)))
        XCTAssertNil(NetCommand.decode(Data(repeating: 32, count: 5_000)))
    }
}

// MARK: - The host's picture, and a guest's mirror of it

final class NetMirrorTests: XCTestCase {
    private let dt: TimeInterval = 1.0 / 60

    private func host(_ count: Int = 3) -> GameSimulation {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 5)
        let party = (0..<count).map { index in
            PartyHeroConfig(id: "p\(index)", name: ["Jesse", "Whitney", "Kevin"][index], slot: index * 2 + 1,
                            weaponID: StarterWeapons.sword.id)
        }
        var sim = GameSimulation(run: run, tuning: .standard, party: party)
        sim.cheats = SimulationCheats(godMode: false, spawningEnabled: false)
        return sim
    }

    private func guest(slot: UInt8) -> GameSimulation {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 5)
        var sim = GameSimulation(run: run, tuning: .standard)
        sim.beginMirroring(slot: slot)
        return sim
    }

    private func addGoblin(_ sim: inout GameSimulation, at point: CGPoint) {
        let kind = sim.combat.enemies.kindIndex(for: EnemyCatalog.goblin)
        sim.combat.enemies.append(id: sim.combat.makeEntityID(), kind: kind, position: point, speedScale: 1)
    }

    func testAGuestSeesTheHostsWorld() throws {
        var hostSim = host()
        let home = hostSim.arena.playerSpawn
        addGoblin(&hostSim, at: hostSim.world.wrap(home + CGPoint(x: 5, y: 0)))
        addGoblin(&hostSim, at: hostSim.world.wrap(home + CGPoint(x: -6, y: 2)))
        hostSim.combat.orbs.append(ExperienceOrb(id: hostSim.combat.makeEntityID(), position: home, value: 9))
        for _ in 0..<30 { hostSim.step(dt: dt) }

        let picture = hostSim.snapshot(forViewer: 1, radius: 26)
        let decoded = try XCTUnwrap(NetSnapshot.decode(picture.encoded()))
        var mirror = guest(slot: 3)
        mirror.applyMirror(decoded)

        XCTAssertTrue(mirror.hasMirroredState)
        XCTAssertEqual(mirror.enemies.count, hostSim.enemies.count)
        XCTAssertEqual(mirror.combat.orbs.count, hostSim.combat.orbs.count)
        XCTAssertEqual(mirror.mirror?.heroes.count, 3, "the whole party is always in the picture")
        XCTAssertEqual(mirror.mirror?.heroes.map { $0.slot }.sorted(), [1, 3, 5])
        XCTAssertEqual(mirror.elapsed, hostSim.elapsed, accuracy: 0.01)
        // The local hero takes their place from the host's word.
        let mine = hostSim.playerState(of: 1)
        XCTAssertEqual(mirror.player.position.x, mine.position.x, accuracy: 0.1)
        XCTAssertEqual(mirror.player.maxHealth, mine.maxHealth, accuracy: 1)
    }

    func testOnlyWhatIsNearAGuestIsSentToThem() throws {
        var hostSim = host(2)
        let home = hostSim.arena.playerSpawn
        for index in 0..<2 {
            hostSim.perform(as: index) { sim in
                sim.player.position = home
                sim.combat.playerPosition = home
            }
        }
        addGoblin(&hostSim, at: hostSim.world.wrap(home + CGPoint(x: 8, y: 0)))
        addGoblin(&hostSim, at: hostSim.world.wrap(home + CGPoint(x: 60, y: 0)))
        let near = hostSim.snapshot(forViewer: 1, radius: 26)
        XCTAssertEqual(near.enemies.count, 1, "the far goblin is not their concern")
        let wide = hostSim.snapshot(forViewer: 1, radius: 100)
        XCTAssertEqual(wide.enemies.count, 2)
    }

    func testTheNearestEnemiesWinWhenThereAreTooMany() {
        var hostSim = host(2)
        let home = hostSim.arena.playerSpawn
        hostSim.perform(as: 1) { $0.player.position = home }
        for index in 0..<(NetSnapshot.Limit.enemies + 60) {
            addGoblin(&hostSim, at: hostSim.world.wrap(home + CGPoint(x: 1 + Double(index % 40) * 0.5, y: Double(index / 40))))
        }
        let picture = hostSim.snapshot(forViewer: 1, radius: 26)
        XCTAssertEqual(picture.enemies.count, NetSnapshot.Limit.enemies)
    }

    func testFallenHeroesAndTheirMarkersReachEveryone() throws {
        var hostSim = host()
        hostSim.combat.incidents.append(.strikeHero(hero: 2, amount: 100_000, direction: CGPoint(x: 1, y: 0)))
        hostSim.step(dt: dt)
        let decoded = try XCTUnwrap(NetSnapshot.decode(hostSim.snapshot(forViewer: 0, radius: 26).encoded()))
        XCTAssertEqual(decoded.markers.count, 1)
        XCTAssertEqual(decoded.markers[0].slot, 5, "markers are named by seat, not by simulation index")
        let fallen = try XCTUnwrap(decoded.heroes.first { $0.slot == 5 })
        XCTAssertTrue(fallen.isDefeated)

        var mirror = guest(slot: 1)
        mirror.applyMirror(decoded)
        XCTAssertEqual(mirror.mirror?.markers.count, 1)
        XCTAssertFalse(mirror.player.isDefeated, "the local hero is not the fallen one")
    }

    func testTheLocalHeroWalksAtOnceAndIsPulledBackOnlyWhenTheHostDisagrees() throws {
        var hostSim = host(2)
        var mirror = guest(slot: 3)
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        let start = mirror.player.position

        // The stick is held for a second before any word comes back.
        for _ in 0..<60 { mirror.advanceMirror(dt: dt, intent: PlayerIntent(move: CGPoint(x: 1, y: 0))) }
        XCTAssertGreaterThan(mirror.world.delta(from: start, to: mirror.player.position).x, 2.5, "walking is immediate")

        // The host has the hero where they are, a little behind: leave them be.
        hostSim.perform(as: 1) { $0.player.position = mirror.world.wrap(mirror.player.position - CGPoint(x: 0.3, y: 0)) }
        let before = mirror.player.position
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        XCTAssertEqual(mirror.world.distance(before, mirror.player.position), 0, accuracy: 0.001)

        // The host shoved them a long way: follow, not jump.
        hostSim.perform(as: 1) { $0.player.position = mirror.world.wrap(mirror.player.position + CGPoint(x: 3, y: 0)) }
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        let moved = mirror.world.distance(before, mirror.player.position)
        XCTAssertGreaterThan(moved, 0.5)
        XCTAssertLessThan(moved, 3)

        // Or a very long way: snap.
        let far = mirror.world.wrap(mirror.player.position + CGPoint(x: 30, y: 0))
        hostSim.perform(as: 1) { $0.player.position = far }
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        XCTAssertEqual(mirror.world.distance(mirror.player.position, far), 0, accuracy: 0.1)
    }

    func testEnemiesEaseTowardTheirNewPlacesInsteadOfJumping() throws {
        var hostSim = host(2)
        let home = hostSim.arena.playerSpawn
        addGoblin(&hostSim, at: hostSim.world.wrap(home + CGPoint(x: 6, y: 0)))
        var mirror = guest(slot: 3)
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        let first = mirror.enemies.positions[0]

        hostSim.combat.enemies.positions[0] = hostSim.world.wrap(hostSim.combat.enemies.positions[0] + CGPoint(x: 1.5, y: 0))
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        XCTAssertEqual(mirror.world.distance(first, mirror.enemies.positions[0]), 0, accuracy: 0.001, "it stays where it was drawn")
        for _ in 0..<30 { mirror.advanceMirror(dt: dt, intent: .idle) }
        XCTAssertEqual(mirror.world.distance(mirror.enemies.positions[0], hostSim.combat.enemies.positions[0]), 0, accuracy: 0.05)
    }

    func testShotsFlyOnBetweenPictures() throws {
        var hostSim = host(2)
        let home = hostSim.arena.playerSpawn
        var hit = Hit(amount: 5, type: .physical, tags: [.projectile], direction: CGPoint(x: 1, y: 0))
        hit.knockback = 0
        hostSim.combat.hostileProjectiles.append(Projectile(
            id: hostSim.combat.makeEntityID(), position: hostSim.world.wrap(home + CGPoint(x: 6, y: 0)),
            velocity: CGPoint(x: 8, y: 0), remainingLife: 3, pierceRemaining: 0, hit: hit, radius: 0.25, splashRadius: 0,
            spriteID: .projectileBolt, visual: .physical, isHostile: true))
        var mirror = guest(slot: 3)
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        let start = mirror.projectiles[0].position
        for _ in 0..<30 { mirror.advanceMirror(dt: dt, intent: .idle) }
        XCTAssertEqual(mirror.world.delta(from: start, to: mirror.projectiles[0].position).x, 4, accuracy: 0.2)
    }

    func testAGuestsOwnBuildArrivesFromTheHostAndIsPlayable() throws {
        var hostSim = host(2)
        hostSim.perform(as: 1) { sim in
            sim.grantLevels(4)
            let skill = SkillCatalog.skills(for: .warrior).first { $0.tier == .one }!
            var draft = SkillAllocation()
            draft.add(skill)
            XCTAssertTrue(sim.commit(draft, slots: [nil, nil, nil, nil]))
        }
        let state = hostSim.perform(as: 1) { $0.captureSelfState() }
        let data = try JSONEncoder().encode(state)
        XCTAssertLessThan(data.count, 4_000, "a state is a few hundred bytes")
        let decoded = try JSONDecoder().decode(HeroSelfState.self, from: data)

        var mirror = guest(slot: 3)
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        mirror.applySelfState(decoded)
        XCTAssertEqual(mirror.progression.level, 5)
        XCTAssertEqual(mirror.progression.unspentPoints, state.unspentPoints)
        XCTAssertEqual(mirror.allocation.ranks, state.ranks)
        XCTAssertEqual(mirror.progression.earnedPoints, state.earnedPoints)
        XCTAssertEqual(mirror.abilitySlots.count, AbilitySlots.count)
    }

    func testAFindAndItsWeaponTravelIntact() throws {
        var hostSim = host(2)
        hostSim.perform(as: 1) { sim in
            var random = SeededRandom(seed: 99)
            var offer = RelicRoller.offer(tier: .hoard, wave: 8, inventory: sim.relics, wielding: nil, random: &random)
            offer.weapon = WeaponFind(weapon: StarterWeapons.katana.id, rarity: .epic,
                                      affixes: [WeaponAffixCatalog.keen, WeaponAffixCatalog.swift], damageScale: 1.2)
            sim.offer = offer
        }
        let state = hostSim.perform(as: 1) { $0.captureSelfState() }
        let round = try JSONDecoder().decode(HeroSelfState.self, from: JSONEncoder().encode(state))
        var mirror = guest(slot: 3)
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        mirror.applySelfState(round)
        let original = hostSim.perform(as: 1) { $0.offer }
        XCTAssertEqual(mirror.offer?.choices, original?.choices)
        XCTAssertEqual(mirror.offer?.weapon?.weapon, StarterWeapons.katana.id)
        XCTAssertEqual(mirror.offer?.weapon?.affixes.map { $0.id }, ["keen", "swift"])
        XCTAssertEqual(mirror.offer?.rerollsLeft, original?.rerollsLeft)
    }

    func testRelicsAndAWieldedWeaponTravelToo() throws {
        var hostSim = host(2)
        hostSim.perform(as: 1) { sim in
            sim.grantRelic(RelicChoice(relic: RelicCatalog.all[0].id, rank: 2))
            sim.wielded = WeaponFind(weapon: StarterWeapons.bow.id, rarity: .rare, affixes: [WeaponAffixCatalog.heavy],
                                     damageScale: 1.1)
        }
        let state = hostSim.perform(as: 1) { $0.captureSelfState() }
        var mirror = guest(slot: 3)
        mirror.applyMirror(hostSim.snapshot(forViewer: 1, radius: 26))
        mirror.applySelfState(state)
        XCTAssertEqual(mirror.relics.rank(of: RelicCatalog.all[0].id), min(2, RelicCatalog.all[0].maxRank))
        XCTAssertEqual(mirror.weapon.id, StarterWeapons.bow.id)
        XCTAssertEqual(mirror.wielded?.affixes.first?.id, "heavy")
    }

    func testCooldownsAreTheHostsAndCountDownBetweenReports() throws {
        var mirror = guest(slot: 3)
        var state = HeroSelfState(level: 1, experience: 0, required: 10, earnedPoints: 0, unspentPoints: 0, ranks: [:],
                                  slots: [nil, nil, nil, nil], buildVersion: 0, relics: [], offer: nil,
                                  weapon: StarterWeapons.sword.id, wielded: nil, cooldowns: ["x": .init(remaining: 5, total: 10)],
                                  moveSpeed: 1.2, summonsDismissed: false, hasSummons: false, allyCount: 0,
                                  stats: RunStats(), shelterSecondsLeft: 0)
        state.moveSpeed = 1.2
        mirror.applySelfState(state)
        XCTAssertEqual(mirror.mirror?.cooldowns["x"]?.remaining, 5)
        for _ in 0..<60 { mirror.advanceMirror(dt: dt, intent: .idle) }
        XCTAssertEqual(mirror.mirror?.cooldowns["x"]?.remaining ?? 0, 4, accuracy: 0.05)
        XCTAssertEqual(mirror.mirror?.moveSpeed, 1.2)
    }
}

/// A guest asks; the host decides. Nothing a guest sends can do more than ask.
final class HostAuthorityTests: XCTestCase {
    private func host() -> GameSimulation {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 5)
        let party = (0..<2).map { index in
            PartyHeroConfig(id: "p\(index)", name: "P\(index)", slot: index, weaponID: StarterWeapons.sword.id)
        }
        var sim = GameSimulation(run: run, tuning: .standard, party: party)
        sim.cheats = SimulationCheats(godMode: false, spawningEnabled: false)
        return sim
    }

    func testAGuestCannotSpendPointsItHasNotEarned() {
        var sim = host()
        let refused = sim.perform(as: 1) { simulation -> Bool in
            var draft = SkillAllocation()
            for skill in SkillCatalog.skills(for: .warrior).filter({ $0.tier == .one }).prefix(4) {
                draft.add(skill)
            }
            return simulation.commit(draft, slots: [nil, nil, nil, nil])
        }
        XCTAssertFalse(refused, "a level-one hero has no points to spend")
        XCTAssertEqual(sim.perform(as: 1) { $0.allocation.spent }, 0)
    }

    func testAGuestCannotPickACardThatIsNotOnOffer() {
        var sim = host()
        XCTAssertFalse(sim.perform(as: 1) { $0.chooseRelic(at: 0) })
        XCTAssertFalse(sim.perform(as: 1) { $0.chooseWeapon() })
        XCTAssertFalse(sim.perform(as: 1) { $0.rerollOffer() })
        XCTAssertEqual(sim.perform(as: 1) { $0.relics.count }, 0)
    }

    func testAGuestCannotDropSkillsItAlreadyHas() {
        var sim = host()
        sim.perform(as: 1) { simulation in
            simulation.grantLevels(3)
            let skill = SkillCatalog.skills(for: .warrior).first { $0.tier == .one }!
            var draft = SkillAllocation()
            draft.add(skill)
            XCTAssertTrue(simulation.commit(draft, slots: [nil, nil, nil, nil]))
            XCTAssertFalse(simulation.commit(SkillAllocation(), slots: [nil, nil, nil, nil]), "no refunds mid-run")
        }
    }

    func testGuestsAbilityPressesOnlyFireAbilitiesTheyHave() {
        var sim = host()
        sim.setIntent(PlayerIntent(move: .zero, abilityPresses: 0b1111, interact: false), forHero: 1)
        for _ in 0..<10 { sim.step(dt: 1.0 / 60) }
        XCTAssertEqual(sim.perform(as: 1) { $0.combat.stats.abilityUses.count }, 0)
    }
}
