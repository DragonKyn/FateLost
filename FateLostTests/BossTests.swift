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
        XCTAssertEqual(champions.count, 10)
        var previousIntensity = 0
        var previousMoves = 0
        var previousTempo = Double.greatestFiniteMagnitude
        for champion in champions {
            guard let kit = champion.kit else { return XCTFail("\(champion.name) has no repertoire") }
            XCTAssertGreaterThan(kit.intensity, previousIntensity, "\(champion.name) is no harder than the last")
            XCTAssertGreaterThanOrEqual(kit.moves.count, previousMoves, "\(champion.name) knows fewer moves than the last")
            XCTAssertLessThan(kit.tempo, previousTempo, "\(champion.name) is no quicker than the last")
            XCTAssertEqual(Set(kit.moves).count, kit.moves.count, "\(champion.name) repeats a move")
            XCTAssertLessThanOrEqual(kit.intensity, 10)
            previousIntensity = kit.intensity
            previousMoves = kit.moves.count
            previousTempo = kit.tempo
        }
        XCTAssertGreaterThanOrEqual(champions.last?.kit?.moves.count ?? 0, 5)
        XCTAssertTrue(EnemyCatalog.goblin.kit == nil, "ordinary enemies have no repertoire")
    }

    func testMovesOpenUpAsTheFightGoes() {
        let kit = BossKit(moves: [.slam, .fan, .ring, .lanes, .spiral], intensity: 5, tempo: 5)
        XCTAssertEqual(BossSystem.phase(healthFraction: 1), 0)
        XCTAssertEqual(BossSystem.phase(healthFraction: 0.6), 1)
        XCTAssertEqual(BossSystem.phase(healthFraction: 0.2), 2)
        XCTAssertEqual(BossSystem.availableMoves(kit, phase: 0), [.slam, .fan])
        XCTAssertEqual(BossSystem.availableMoves(kit, phase: 1), [.slam, .fan, .ring])
        XCTAssertEqual(BossSystem.availableMoves(kit, phase: 2), [.slam, .fan, .ring, .lanes])
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
                let marks = sim.combat.hazards
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

    // MARK: Across the wire

    func testMarkedGroundTravelsToGuestsAndIsDrawnThere() {
        var host = Squad.make(2)
        let home = host.arena.playerSpawn
        host.combat.hazards.append(Hazard(id: 77, shape: .lane, position: home, direction: CGPoint(x: 1, y: 0),
                                          size: 16, width: 0.75, warning: 1.4, age: 0.5, damage: 30,
                                          type: .fire, visual: .fire))
        let snapshot = host.snapshot(forViewer: 1, radius: 40)
        XCTAssertEqual(snapshot.hazards.count, 1)

        guard let decoded = NetSnapshot.decode(snapshot.encoded()) else { return XCTFail("did not decode") }
        XCTAssertEqual(decoded.hazards.count, 1)
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
        XCTAssertEqual(guest.allHazards.count, 1)
        XCTAssertEqual(guest.allHazards[0].damage, 0, "a guest only draws it; the host decides who is hurt")
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
