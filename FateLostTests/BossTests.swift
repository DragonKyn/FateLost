import XCTest
@testable import FateLost

final class BossTests: XCTestCase {
    private let world = ToroidalWorld(width: 128, height: 128)
    private let dt: TimeInterval = 1.0 / 60

    // MARK: Marked ground

    private func hazard(_ shape: Hazard.Shape, at position: CGPoint = CGPoint(x: 20, y: 20),
                        direction: CGPoint = CGPoint(x: 1, y: 0), size: CGFloat, width: CGFloat = 0) -> Hazard {
        Hazard(id: 1, shape: shape, position: position, direction: direction, size: size, width: width,
               warning: 1, damage: 10, type: .physical, visual: .physical)
    }

    func testACircleCoversItsRadiusAndAHeroesBody() {
        let disc = hazard(.circle, size: 2)
        XCTAssertTrue(disc.covers(CGPoint(x: 21.5, y: 20), radius: 0.34, world: world))
        XCTAssertTrue(disc.covers(CGPoint(x: 22.2, y: 20), radius: 0.34, world: world), "a body's edge counts")
        XCTAssertFalse(disc.covers(CGPoint(x: 22.5, y: 20), radius: 0.34, world: world))
    }

    func testAConeCoversAWedgeAheadAndNothingBehind() {
        let wedge = hazard(.cone, size: 4, width: 0.95)
        XCTAssertTrue(wedge.covers(CGPoint(x: 23, y: 20), radius: 0.34, world: world), "straight ahead")
        XCTAssertTrue(wedge.covers(CGPoint(x: 22, y: 22), radius: 0.34, world: world), "inside the edge of the wedge")
        XCTAssertFalse(wedge.covers(CGPoint(x: 20.2, y: 24), radius: 0.34, world: world), "off to the side")
        XCTAssertFalse(wedge.covers(CGPoint(x: 16, y: 20), radius: 0.34, world: world), "behind")
        XCTAssertFalse(wedge.covers(CGPoint(x: 25, y: 20), radius: 0.34, world: world), "past its reach")
        XCTAssertTrue(wedge.covers(CGPoint(x: 20.2, y: 20.1), radius: 0.34, world: world), "the point of it")
    }

    func testALaneCoversAStripAndLeavesGapsBesideIt() {
        let strip = hazard(.lane, size: 16, width: 0.75)
        XCTAssertTrue(strip.covers(CGPoint(x: 30, y: 20.5), radius: 0.34, world: world))
        XCTAssertTrue(strip.covers(CGPoint(x: 30, y: 21.05), radius: 0.34, world: world), "the edge of a body")
        XCTAssertFalse(strip.covers(CGPoint(x: 30, y: 21.4), radius: 0.34, world: world))
        XCTAssertFalse(strip.covers(CGPoint(x: 40, y: 20), radius: 0.34, world: world), "past its end")
        XCTAssertFalse(strip.covers(CGPoint(x: 18, y: 20), radius: 0.34, world: world), "before its start")
    }

    func testGroundIsMeasuredAcrossTheSeam() {
        let disc = hazard(.circle, at: CGPoint(x: 127, y: 20), size: 2)
        XCTAssertTrue(disc.covers(CGPoint(x: 0.5, y: 20), radius: 0.34, world: world), "the map wraps")
    }

    func testMarkedGroundHurtsOnceAndOnlyAfterItsWarning() {
        var sim = Squad.make(1)
        let home = sim.arena.playerSpawn
        Squad.place(&sim, hero: 0, at: home)
        sim.combat.hazards.append(Hazard(id: sim.combat.makeEntityID(), shape: .circle, position: home,
                                         direction: CGPoint(x: 1, y: 0), size: 2, width: 0, warning: 1,
                                         damage: 20, type: .physical, visual: .physical))
        let before = Squad.health(sim, 0)
        Squad.run(&sim, seconds: 0.9)
        XCTAssertEqual(Squad.health(sim, 0), before, accuracy: 0.001, "nothing hurts during the warning")
        Squad.run(&sim, seconds: 0.4)
        let after = Squad.health(sim, 0)
        XCTAssertLessThan(after, before, "it lands on whoever stayed")
        Squad.run(&sim, seconds: 1.5)
        XCTAssertGreaterThanOrEqual(Squad.health(sim, 0), after - 0.001, "and only once")
        XCTAssertTrue(sim.combat.hazards.isEmpty, "then it is gone")
    }

    func testAHeroWhoStepsOutIsNotHurt() {
        var sim = Squad.make(2)
        let home = sim.arena.playerSpawn
        Squad.place(&sim, hero: 0, at: home)
        Squad.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 9, y: 0)))
        sim.combat.hazards.append(Hazard(id: sim.combat.makeEntityID(), shape: .circle, position: home,
                                         direction: CGPoint(x: 1, y: 0), size: 2, width: 0, warning: 1,
                                         damage: 30, type: .physical, visual: .physical))
        let before = Squad.health(sim, 1)
        Squad.run(&sim, seconds: 1.5)
        XCTAssertEqual(Squad.health(sim, 1), before, accuracy: 0.001, "the friend outside it is untouched")
        XCTAssertLessThan(Squad.health(sim, 0), Squad.health(sim, 1), "the one inside it is not")
    }

    // MARK: The kits

    func testEveryChampionHasAKitAndTheKitsGrow() {
        let champions = EnemyCatalog.champions
        XCTAssertEqual(champions.count, 27)
        XCTAssertEqual(Set(champions.map(\.id)).count, champions.count, "two champions share an id")
        var previousIntensity = 0
        var previousTempo = Double.greatestFiniteMagnitude
        for champion in champions {
            guard let kit = champion.kit else { return XCTFail("\(champion.name) has no repertoire") }
            XCTAssertGreaterThanOrEqual(kit.intensity, previousIntensity, "\(champion.name) is easier than the last")
            XCTAssertLessThanOrEqual(kit.tempo, previousTempo, "\(champion.name) is slower than the last")
            XCTAssertEqual(Set(kit.moves).count, kit.moves.count, "\(champion.name) repeats a move")
            XCTAssertGreaterThanOrEqual(kit.moves.count, 2)
            XCTAssertTrue(kit.intensity >= 1 && kit.intensity <= 10)
            if kit.moves.contains(.summon) {
                XCTAssertNotNil(kit.adds.flatMap { EnemyCatalog.definition(for: $0) },
                                "\(champion.name) summons but calls nothing that exists")
            }
            if let signature = kit.signature {
                XCTAssertTrue(kit.moves.contains(signature), "\(champion.name) favours a move it does not have")
            }
            previousIntensity = kit.intensity
            previousTempo = kit.tempo
        }
        XCTAssertGreaterThanOrEqual(champions.last?.kit?.moves.count ?? 0, 8, "the last champion should have everything")
        XCTAssertTrue(EnemyCatalog.goblin.kit == nil, "ordinary enemies have no repertoire")
    }

    func testNoRealmSendsTheSameChampionTwice() {
        for realm in RealmCatalog.all {
            let bosses = EnemyCatalog.bosses(for: realm.id)
            XCTAssertEqual(Set(bosses).count, bosses.count, "\(realm.name) repeats a champion")
            if let conquest = realm.conquestWave {
                XCTAssertGreaterThanOrEqual(bosses.count, conquest / realm.waves.bossEvery,
                                            "\(realm.name) runs out of champions before it is conquered")
                // Every boss wave up to the conquest meets a different one.
                var met = Set<EnemyKindID>()
                for wave in stride(from: realm.waves.bossEvery, through: conquest, by: realm.waves.bossEvery) {
                    guard let id = realm.waves.boss(forWave: wave) else { return XCTFail("no champion on wave \(wave)") }
                    XCTAssertTrue(met.insert(id).inserted, "\(realm.name) meets \(id) twice")
                }
            }
        }
    }

    func testMovesOpenUpAsTheFightGoes() {
        let kit = BossKit(moves: [.slam, .fan, .ring, .lanes, .spiral], intensity: 5, tempo: 5)
        XCTAssertEqual(BossSystem.phase(healthFraction: 1), 0)
        XCTAssertEqual(BossSystem.phase(healthFraction: 0.6), 1)
        XCTAssertEqual(BossSystem.phase(healthFraction: 0.2), 2)
        XCTAssertEqual(BossSystem.availableMoves(kit, phase: 0), [.slam, .fan])
        XCTAssertEqual(BossSystem.availableMoves(kit, phase: 1), [.slam, .fan, .ring, .lanes])
        XCTAssertEqual(BossSystem.availableMoves(kit, phase: 2), [.slam, .fan, .ring, .lanes, .spiral])
        let three = BossKit(moves: [.slam, .fan, .ring], intensity: 1, tempo: 5)
        XCTAssertEqual(BossSystem.availableMoves(three, phase: 0), [.slam, .fan])
        XCTAssertEqual(BossSystem.availableMoves(three, phase: 1), [.slam, .fan, .ring])
        let short = BossKit(moves: [.slam], intensity: 1, tempo: 5)
        XCTAssertEqual(BossSystem.availableMoves(short, phase: 2), [.slam])
    }

    func testWarningsNeverShrinkBelowTheFloor() {
        for intensity in 1...10 {
            let kit = BossKit(moves: [.slam], intensity: intensity, tempo: 4)
            for base in [1.0, 1.3, 1.4, 1.5] {
                XCTAssertGreaterThanOrEqual(BossSystem.warning(base, kit: kit), BossSystem.minimumWarning)
            }
        }
    }

    // MARK: In a fight

    private func fight(_ champion: EnemyDefinition, healthFraction: Double = 0.2,
                       distance: CGFloat = 1.7) -> (sim: GameSimulation, boss: Int) {
        var sim = Squad.make(1)
        sim.cheats = SimulationCheats(godMode: true, spawningEnabled: false)
        let home = sim.arena.playerSpawn
        Squad.place(&sim, hero: 0, at: home)
        let index = Squad.addGoblin(&sim, at: sim.world.wrap(home + CGPoint(x: distance, y: 0)), definition: champion)
        sim.combat.enemies.health[index] = sim.combat.enemies.maxHealth[index] * healthFraction
        return (sim, index)
    }

    /// The shortest walk that takes a body clear of every marked area, in tiles.
    private func escapeDistance(from point: CGPoint, of marks: [Hazard], world: ToroidalWorld) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        for step in 0..<48 {
            let angle = 2 * CGFloat.pi * CGFloat(step) / 48
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            var walked: CGFloat = 0
            while walked < 12 {
                let spot = world.wrap(point + direction * walked)
                if !marks.contains(where: { $0.covers(spot, radius: 0.34, world: world) }) { break }
                walked += 0.1
            }
            best = min(best, walked)
        }
        return best
    }

    func testEveryChampionsGroundIsMarkedFirstAndCanBeLeftInTime() {
        let speed = 4.2
        let reaction = 0.25
        for champion in EnemyCatalog.champions {
            var (sim, _) = fight(champion)
            var seen = Set<Int>()
            var madeAny = false
            for _ in 0..<Int(70 / dt) {
                sim.step(dt: dt)
                let marks = sim.combat.hazards.filter { !$0.isGuide }
                for mark in marks where !seen.contains(mark.id) {
                    seen.insert(mark.id)
                    madeAny = true
                    XCTAssertFalse(mark.hasLanded, "\(champion.name): ground appeared already landed")
                    XCTAssertLessThanOrEqual(mark.age, dt * 2, "\(champion.name): ground appeared late")
                    XCTAssertGreaterThanOrEqual(mark.warning, BossSystem.minimumWarning,
                                                "\(champion.name): too little warning")
                    // The hero is standing at melee range, the worst place to be caught.
                    let here = sim.playerState(of: 0).position
                    let onTheSameWarning = marks.filter { $0.warning >= mark.warning - 0.001 && $0.age <= dt * 2 }
                    let need = Double(escapeDistance(from: here, of: onTheSameWarning, world: sim.world))
                    XCTAssertLessThanOrEqual(need, speed * (mark.warning - reaction),
                                             "\(champion.name): \(need) tiles to safety with only \(mark.warning) s")
                }
            }
            XCTAssertTrue(madeAny, "\(champion.name) never marked any ground in seventy seconds")
        }
    }

    func testAChampionHoldsStillWhileItCastsAndCatchesItsBreath() {
        var (sim, boss) = fight(EnemyCatalog.bossIronSaint, healthFraction: 1, distance: 6)
        var id = sim.combat.enemies.ids[boss]
        var caught = false
        for _ in 0..<Int(40 / dt) {
            sim.step(dt: dt)
            guard let index = sim.combat.index(ofEnemy: id), let brain = sim.combat.bossBrains[id] else { continue }
            id = sim.combat.enemies.ids[index]
            if brain.isBusy {
                let where0 = sim.combat.enemies.positions[index]
                for _ in 0..<10 { sim.step(dt: dt) }
                if let now = sim.combat.index(ofEnemy: id), sim.combat.bossBrains[id]?.isBusy == true {
                    XCTAssertEqual(sim.combat.enemies.positions[now].x, where0.x, accuracy: 0.001)
                    XCTAssertEqual(sim.combat.enemies.positions[now].y, where0.y, accuracy: 0.001)
                    caught = true
                    break
                }
            }
        }
        XCTAssertTrue(caught, "the boss never stood still to cast")
    }

    func testNoShotIsFasterThanAHeroCanReadAndWeaveThrough() {
        XCTAssertLessThanOrEqual(BossSystem.fastestShot, 8)
        var (sim, _) = fight(EnemyCatalog.bossAbyssalEcho, distance: 4)
        var fastest: CGFloat = 0
        var shots = 0
        for _ in 0..<Int(60 / dt) {
            sim.step(dt: dt)
            for shot in sim.combat.hostileProjectiles {
                fastest = max(fastest, shot.velocity.length)
                shots += 1
            }
        }
        XCTAssertGreaterThan(shots, 20, "the last champion should fill the air")
        XCTAssertLessThanOrEqual(fastest, BossSystem.fastestShot + 0.001)
    }

    func testAStunnedChampionLosesItsPattern() {
        var (sim, boss) = fight(EnemyCatalog.bossVoidmaw, distance: 5)
        let id = sim.combat.enemies.ids[boss]
        for _ in 0..<Int(30 / dt) {
            sim.step(dt: dt)
            if let brain = sim.combat.bossBrains[id], !brain.beats.isEmpty { break }
        }
        guard let brain = sim.combat.bossBrains[id], !brain.beats.isEmpty else {
            return XCTFail("the boss never started a pattern")
        }
        guard let index = sim.combat.index(ofEnemy: id) else { return XCTFail("the boss is gone") }
        sim.combat.enemies.statusMask[index] |= StatusKind.stun.bit
        sim.step(dt: dt)
        XCTAssertTrue(sim.combat.bossBrains[id]?.beats.isEmpty ?? true)
        XCTAssertFalse(sim.combat.bossBrains[id]?.isBusy ?? false)
    }

    func testAFallenChampionsBrainIsForgotten() {
        var (sim, boss) = fight(EnemyCatalog.bossWarchief, distance: 5)
        Squad.run(&sim, seconds: 1)
        XCTAssertFalse(sim.combat.bossBrains.isEmpty)
        sim.combat.enemies.health[boss] = 0
        sim.combat.enemies.remove(at: boss)
        Squad.run(&sim, seconds: 0.1)
        XCTAssertTrue(sim.combat.bossBrains.isEmpty)
    }

    // MARK: The newer moves

    private func mark(at point: CGPoint, sim: inout GameSimulation, size: CGFloat = 2, warning: Double = 1,
                      damage: Double = 20, tune: (inout Hazard) -> Void = { _ in }) {
        var hazard = Hazard(id: sim.combat.makeEntityID(), shape: .circle, position: point,
                            direction: CGPoint(x: 1, y: 0), size: size, width: 0, warning: warning, damage: damage,
                            type: .physical, visual: .physical)
        tune(&hazard)
        sim.combat.hazards.append(hazard)
    }

    func testAPoolKeepsHurtingAfterItLandsAndOnlyThoseInIt() {
        var sim = Squad.make(2)
        let home = sim.arena.playerSpawn
        Squad.place(&sim, hero: 0, at: home)
        Squad.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: 12, y: 0)))
        mark(at: home, sim: &sim, damage: 0) { pool in
            pool.linger = 4
            pool.tickDamage = 6
            pool.tickEvery = 0.5
        }
        let outside = Squad.health(sim, 1)
        var hits = 0
        var last = Squad.health(sim, 0)
        for _ in 0..<Int(4.5 / dt) {
            sim.step(dt: dt)
            let now = Squad.health(sim, 0)
            if now < last - 0.01 { hits += 1 }
            last = now
        }
        XCTAssertGreaterThanOrEqual(hits, 2, "a pool hurts more than once")
        XCTAssertEqual(Squad.health(sim, 1), outside, accuracy: 0.001, "and never whoever is outside it")
        XCTAssertTrue(sim.combat.hazards.isEmpty, "and burns out")
    }

    func testABeamSweepsAcrossItsWedgeAndHurtsOnlyWhatItPasses() {
        var sim = Squad.make(2)
        let home = sim.arena.playerSpawn
        Squad.place(&sim, hero: 0, at: sim.world.wrap(home + CGPoint(x: 5, y: 0)))     // on the beam's path
        Squad.place(&sim, hero: 1, at: sim.world.wrap(home + CGPoint(x: -5, y: 0)))    // behind the boss
        var beam = Hazard(id: sim.combat.makeEntityID(), shape: .lane, position: home,
                          direction: CGPoint(x: 0, y: 1), size: 9, width: 0.7, warning: 0.8, damage: 0,
                          type: .physical, visual: .physical)
        beam.linger = 3
        beam.tickDamage = 8
        beam.tickEvery = 0.25
        beam.spin = -0.8     // clockwise, from straight up toward the hero on the right
        sim.combat.hazards.append(beam)
        let before = Squad.health(sim, 0)
        let behind = Squad.health(sim, 1)
        var turned = false
        for _ in 0..<Int(3.5 / dt) {
            sim.step(dt: dt)
            if let now = sim.combat.hazards.first, now.direction.x > 0.5 { turned = true }
        }
        XCTAssertTrue(turned, "the beam never turned")
        XCTAssertLessThan(Squad.health(sim, 0), before, "the beam swept over the hero in its path")
        XCTAssertEqual(Squad.health(sim, 1), behind, accuracy: 0.001, "and missed the one behind")
    }

    func testAHuntFollowsItsHeroThenLocksSoTheyCanStepOut() {
        var sim = Squad.make(1)
        let home = sim.arena.playerSpawn
        Squad.place(&sim, hero: 0, at: home)
        mark(at: home, sim: &sim, size: 1.5, warning: 2, damage: 30) { hunt in
            hunt.follows = 0
            hunt.lockTime = 0.7
        }
        // Walking away drags the mark along...
        Squad.place(&sim, hero: 0, at: sim.world.wrap(home + CGPoint(x: 6, y: 0)))
        Squad.run(&sim, seconds: 0.1)
        let following = sim.combat.hazards[0].position
        XCTAssertEqual(sim.world.distance(following, sim.world.wrap(home + CGPoint(x: 6, y: 0))), 0, accuracy: 0.05)
        // ...until the last 0.7 s, when it holds still, and a step away is enough.
        Squad.run(&sim, seconds: 1.3)
        let locked = sim.combat.hazards[0].position
        Squad.place(&sim, hero: 0, at: sim.world.wrap(locked + CGPoint(x: 4, y: 0)))
        let before = Squad.health(sim, 0)
        Squad.run(&sim, seconds: 1.2)
        XCTAssertEqual(sim.world.distance(sim.combat.hazards.first?.position ?? locked, locked), 0, accuracy: 0.05,
                       "it kept following after it locked")
        XCTAssertEqual(Squad.health(sim, 0), before, accuracy: 0.001, "the hero who stepped out was hit")
    }

    func testABlinkPutsTheChampionWhereItsSlamLands() {
        var (sim, boss) = fight(EnemyCatalog.bossWarchief, healthFraction: 1, distance: 8)
        sim.combat.bossBrains.removeAll()
        let id = sim.combat.enemies.ids[boss]
        let destination = sim.world.wrap(sim.arena.playerSpawn + CGPoint(x: 3, y: 3))
        mark(at: destination, sim: &sim, size: 2.6, warning: 1.2, damage: 10) { blink in blink.carriesBoss = id }
        Squad.run(&sim, seconds: 0.6)
        XCTAssertGreaterThan(sim.world.distance(sim.combat.enemies.positions[sim.combat.index(ofEnemy: id) ?? 0],
                                                destination), 1, "it moved before the slam landed")
        Squad.run(&sim, seconds: 0.8)
        guard let index = sim.combat.index(ofEnemy: id) else { return XCTFail("the champion vanished") }
        XCTAssertLessThan(sim.world.distance(sim.combat.enemies.positions[index], destination), 1.5,
                          "it did not arrive where the slam landed")
    }

    func testEachNewPhaseIsAnEventThatHappensOncePerPhase() {
        var (sim, boss) = fight(EnemyCatalog.bossGraveWarden, healthFraction: 1, distance: 6)
        let id = sim.combat.enemies.ids[boss]
        Squad.run(&sim, seconds: 2)
        XCTAssertEqual(sim.combat.bossBrains[id]?.phase, 0)
        // Two thirds of its health gone: the phase changes once, with a marked slam and its own kind called in.
        let crowd = sim.combat.enemies.count
        if let index = sim.combat.index(ofEnemy: id) {
            sim.combat.enemies.health[index] = sim.combat.enemies.maxHealth[index] * 0.6
        }
        Squad.run(&sim, seconds: 0.5)
        XCTAssertEqual(sim.combat.bossBrains[id]?.phase, 1)
        XCTAssertGreaterThan(sim.combat.enemies.count, crowd, "it should have called reinforcements")
        Squad.run(&sim, seconds: 20)
        XCTAssertEqual(sim.combat.bossBrains[id]?.phase, 1, "the same phase must not shift twice")
    }

    func testTheGuideNeverHurtsAndTheRestDoes() {
        var sim = Squad.make(1)
        let home = sim.arena.playerSpawn
        Squad.place(&sim, hero: 0, at: home)
        mark(at: home, sim: &sim, size: 3, warning: 0.8, damage: 50) { $0.isGuide = true }
        let before = Squad.health(sim, 0)
        Squad.run(&sim, seconds: 1.5)
        XCTAssertEqual(Squad.health(sim, 0), before, accuracy: 0.001)
    }

    // MARK: Across the wire

    func testMarkedGroundTravelsToGuestsAndIsDrawnThere() {
        var host = Squad.make(2)
        let home = host.arena.playerSpawn
        var beam = Hazard(id: 77, shape: .lane, position: home, direction: CGPoint(x: 1, y: 0),
                          size: 16, width: 0.75, warning: 1.4, age: 0.5, damage: 30, type: .fire, visual: .fire)
        beam.linger = 2.5
        host.combat.hazards.append(beam)
        var guide = Hazard(id: 78, shape: .cone, position: home, direction: CGPoint(x: 0, y: 1),
                           size: 9, width: 0.95, warning: 3, age: 0.5, damage: 0, type: .fire, visual: .fire)
        guide.isGuide = true
        host.combat.hazards.append(guide)
        let snapshot = host.snapshot(forViewer: 1, radius: 40)
        XCTAssertEqual(snapshot.hazards.count, 2)

        guard let decoded = NetSnapshot.decode(snapshot.encoded()) else { return XCTFail("did not decode") }
        XCTAssertEqual(decoded.hazards.count, 2)
        XCTAssertEqual(decoded.hazards[0].linger, 2.5, accuracy: 0.06)
        XCTAssertEqual(decoded.hazards[0].flags, 0)
        XCTAssertEqual(decoded.hazards[1].flags & NetHazard.guide, NetHazard.guide, "a guide stays a guide across the wire")
        let net = decoded.hazards[0]
        XCTAssertEqual(net.id, 77)
        XCTAssertEqual(net.shape, Hazard.Shape.lane.rawValue)
        XCTAssertEqual(net.size, 16, accuracy: 0.13)
        XCTAssertEqual(net.width, 0.75, accuracy: 0.02)
        XCTAssertEqual(net.warning, 1.4, accuracy: 0.03)
        XCTAssertEqual(net.age, 0.5, accuracy: 0.02)

        var guest = Squad.make(2)
        guest.beginMirroring(slot: 1)
        guest.applyMirror(decoded)
        XCTAssertEqual(guest.allHazards.count, 2)
        XCTAssertEqual(guest.allHazards[0].damage, 0, "a guest only draws it; the host decides who is hurt")
        XCTAssertTrue(guest.allHazards[1].isGuide)
        guest.advanceMirror(dt: 0.5, intent: .idle)
        XCTAssertEqual(guest.allHazards[0].age, 1.0, accuracy: 0.05, "and it keeps counting between snapshots")
    }

    func testGroundFarFromAHeroIsNotSent() {
        var host = Squad.make(2)
        let home = host.arena.playerSpawn
        host.combat.hazards.append(Hazard(id: 5, shape: .circle, position: host.world.wrap(home + CGPoint(x: 60, y: 0)),
                                          direction: CGPoint(x: 1, y: 0), size: 2, width: 0, warning: 1, damage: 5,
                                          type: .fire, visual: .fire))
        XCTAssertTrue(host.snapshot(forViewer: 0, radius: 20).hazards.isEmpty)
    }
}

/// Just enough of a party to fight a champion in.
private enum Squad {
    static let dt: TimeInterval = 1.0 / 60

    static func make(_ count: Int, seed: UInt64 = 7) -> GameSimulation {
        let run = RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: seed)
        let party = (0..<count).map { index in
            PartyHeroConfig(id: "s\(index)", name: "Hero \(index)", slot: index, weaponID: StarterWeapons.sword.id,
                            legacy: [])
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

    @discardableResult
    static func addGoblin(_ sim: inout GameSimulation, at point: CGPoint, definition: EnemyDefinition) -> Int {
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
}
