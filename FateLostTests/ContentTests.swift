import CoreGraphics
import XCTest
@testable import FateLost

final class ArenaGeneratorTests: XCTestCase {
    private let definition = RealmCatalog.realm(.ashenWilds).arena

    func testSameSeedProducesIdenticalArena() {
        let a = ArenaGenerator(definition: definition, seed: 42).generate()
        let b = ArenaGenerator(definition: definition, seed: 42).generate()
        XCTAssertEqual(a.groundStyles, b.groundStyles)
        XCTAssertEqual(a.decorations, b.decorations)
    }

    func testDifferentSeedsProduceDifferentArenas() {
        let a = ArenaGenerator(definition: definition, seed: 1).generate()
        let b = ArenaGenerator(definition: definition, seed: 2).generate()
        XCTAssertNotEqual(a.decorations, b.decorations)
    }

    func testGroundCoversEveryTileWithAValidStyle() {
        let layout = ArenaGenerator(definition: definition, seed: 7).generate()
        XCTAssertEqual(layout.groundStyles.count, definition.columns * definition.rows)
        let styleCount = definition.theme.groundStyles.count
        XCTAssertTrue(layout.groundStyles.allSatisfy { Int($0) < styleCount })
    }

    func testRoadsContinueAcrossTheSeam() {
        let layout = ArenaGenerator(definition: definition, seed: 3).generate()
        // Every road row touching the east edge must be matched by a road
        // tile within one row on the west edge, or the seam would show.
        let lastColumn = layout.columns - 1
        for row in 0..<layout.rows where layout.isRoad(column: lastColumn, row: row) {
            let continues = (-1...1).contains { layout.isRoad(column: 0, row: row + $0) }
            XCTAssertTrue(continues, "Road breaks at the seam on row \(row)")
        }
    }

    func testSpawnAreaIsClearOfDecorations() {
        let layout = ArenaGenerator(definition: definition, seed: 11).generate()
        let clearRadius = definition.theme.spawnClearRadius
        for placement in layout.decorations {
            XCTAssertGreaterThanOrEqual(layout.world.distance(placement.position, layout.playerSpawn), clearRadius)
        }
    }

    func testStandingDecorationsDoNotOverlap() {
        let layout = ArenaGenerator(definition: definition, seed: 5).generate()
        let standing = layout.decorations.filter { DecorationCatalog.spec(for: $0.kind).layer == .standing }
        var grid = ToroidalSpatialGrid(world: layout.world, cellSize: 4)
        for (index, placement) in standing.enumerated() {
            grid.insert(index, at: placement.position)
        }
        var neighbours: [Int] = []
        for (index, placement) in standing.enumerated() {
            neighbours.removeAll()
            grid.query(around: placement.position, radius: 3, into: &neighbours)
            for other in neighbours where other != index {
                let minimum = DecorationCatalog.spec(for: placement.kind).footprintRadius
                    + DecorationCatalog.spec(for: standing[other].kind).footprintRadius
                XCTAssertGreaterThanOrEqual(
                    layout.world.distance(placement.position, standing[other].position), minimum - 1e-9
                )
            }
        }
    }

    func testPeriodicNoiseMatchesAcrossSeam() {
        let noise = PeriodicValueNoise(seed: 9, width: 128, height: 128, approximateCellSize: 9)
        for y in stride(from: 0.0, to: 128.0, by: 7.3) {
            XCTAssertEqual(noise.sample(x: 0, y: y), noise.sample(x: 128, y: y), accuracy: 1e-9)
            XCTAssertEqual(noise.sample(x: y, y: 0), noise.sample(x: y, y: 128), accuracy: 1e-9)
        }
    }
}

final class RealmCatalogTests: XCTestCase {
    func testCampaignHasTenRealmsInOrder() {
        XCTAssertEqual(RealmCatalog.all.count, 10)
        XCTAssertEqual(RealmCatalog.all.map(\.order), Array(1...10))
    }

    func testOnlyTheAbyssIsEndless() {
        let endless = RealmCatalog.all.filter(\.isEndless)
        XCTAssertEqual(endless.map(\.id), [.abyss])
    }

    func testConquestWavesAndLegacyMultipliersEscalate() {
        let campaign = RealmCatalog.all.filter { !$0.isEndless }
        let waves = campaign.compactMap(\.conquestWave)
        XCTAssertEqual(waves.count, campaign.count, "every campaign realm needs a conquest wave")
        // Later realms ask for longer, and none of them asks for an evening.
        XCTAssertEqual(waves, waves.sorted())
        XCTAssertEqual(waves.first, 10)
        XCTAssertLessThanOrEqual(waves.last ?? 0, 30)
        let multipliers = RealmCatalog.all.map(\.legacyMultiplier)
        XCTAssertEqual(multipliers, multipliers.sorted())
        XCTAssertEqual(RealmCatalog.realm(.ashenWilds).legacyMultiplier, 1.0)
    }

    func testRoadMeandersCloseOnThemselves() {
        for realm in RealmCatalog.all {
            guard let roads = realm.arena.theme.roads else { continue }
            XCTAssertGreaterThanOrEqual(roads.meanderCycles, 1, "\(realm.name) roads would not wrap")
        }
    }

    func testArenasAreFarLargerThanTheVisibleArea() {
        // The wrapping renderer assumes the camera never sees half the arena.
        for realm in RealmCatalog.all {
            XCTAssertGreaterThanOrEqual(realm.arena.columns, 96)
            XCTAssertGreaterThanOrEqual(realm.arena.rows, 96)
        }
    }
}

final class RealmUnlockTests: XCTestCase {
    private let catalog = RealmCatalog.all

    func testOnlyFirstRealmStartsUnlocked() {
        let progress = RealmProgress()
        let unlocked = catalog.filter { RealmUnlockRules.isUnlocked($0, progress: progress, catalog: catalog) }
        XCTAssertEqual(unlocked.map(\.id), [.ashenWilds])
    }

    func testConqueringARealmUnlocksTheNext() {
        let progress = RealmProgress(conquered: [.ashenWilds])
        XCTAssertTrue(RealmUnlockRules.isUnlocked(RealmCatalog.realm(.drownedFen), progress: progress, catalog: catalog))
        XCTAssertFalse(RealmUnlockRules.isUnlocked(RealmCatalog.realm(.hollowForest), progress: progress,
                                                   catalog: catalog))
    }

    func testPrerequisiteIsThePreviousRealm() {
        XCTAssertNil(RealmUnlockRules.prerequisite(for: RealmCatalog.realm(.ashenWilds), catalog: catalog))
        XCTAssertEqual(RealmUnlockRules.prerequisite(for: RealmCatalog.realm(.abyss), catalog: catalog)?.id,
                       .gateOfRuin)
    }
}

final class StarterWeaponTests: XCTestCase {
    func testStartersAreDistinctAndThreeAreFree() {
        let ids = StarterWeapons.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "two starters share an id")
        XCTAssertEqual(StarterWeapons.defaultUnlocked.count, 3)
        for id in StarterWeapons.defaultUnlocked {
            XCTAssertNotNil(StarterWeapons.definition(for: id), "\(id) is free but not in the catalogue")
        }
    }

    func testStartersHaveDistinctRoles() {
        let sword = StarterWeapons.sword
        let bow = StarterWeapons.bow
        let staff = StarterWeapons.staff
        XCTAssertTrue(sword.tags.contains(.melee))
        XCTAssertGreaterThan(bow.range, sword.range)
        XCTAssertEqual(staff.damageType, .arcane)
        if case .projectile(let profile) = staff.delivery {
            XCTAssertGreaterThan(profile.splashRadius, 0)
        } else {
            XCTFail("Staff should fire projectiles")
        }
    }

    func testRarityOrdering() {
        XCTAssertLessThan(ItemRarity.common, ItemRarity.legendary)
        XCTAssertEqual(ItemRarity.allCases.sorted(), ItemRarity.allCases)
    }
}
