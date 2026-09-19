import XCTest
@testable import FateLost

/// Ten realms have to be ten places, not one place in ten palettes. These
/// tests hold that line, and check the wave clock each realm runs on.
final class RealmTests: XCTestCase {
    // MARK: Identity

    func testEveryRealmFieldsPropsNoOtherRealmDoes() {
        var seen: [RealmID: Set<DecorationKind>] = [:]
        for realm in RealmCatalog.all {
            seen[realm.id] = Set(realm.arena.theme.decorations.flatMap(kinds(of:)))
        }
        for realm in RealmCatalog.all {
            let mine = seen[realm.id] ?? []
            XCTAssertFalse(mine.isEmpty, "\(realm.name) has no set dressing at all")
            let others = seen.filter { $0.key != realm.id }.values.reduce(into: Set<DecorationKind>()) {
                $0.formUnion($1)
            }
            XCTAssertFalse(mine.subtracting(others).isEmpty,
                           "\(realm.name) fields nothing that isn't in some other realm")
        }
    }

    func testNoTwoRealmsShareASetOfProps() {
        var sets: [Set<DecorationKind>] = []
        for realm in RealmCatalog.all {
            let kinds = Set(realm.arena.theme.decorations.flatMap(kinds(of:)))
            XCTAssertFalse(sets.contains(kinds), "\(realm.name) is dressed exactly like another realm")
            sets.append(kinds)
        }
    }

    func testEveryRealmHasItsOwnGroundAndSky() {
        var palettes: [[RGBA]] = []
        var skies: [RGBA] = []
        for realm in RealmCatalog.all {
            let theme = realm.arena.theme
            let palette = theme.groundStyles.map(\.base)
            XCTAssertFalse(palettes.contains(palette), "\(realm.name) reuses another realm's ground")
            palettes.append(palette)
            XCTAssertFalse(skies.contains(theme.atmosphere.background),
                           "\(realm.name) reuses another realm's sky")
            skies.append(theme.atmosphere.background)
        }
    }

    // MARK: Rosters

    func testEveryRealmFieldsCreaturesNoOtherFirstRealmDoes() {
        for realm in RealmCatalog.all {
            let roster = EnemyCatalog.roster(for: realm.id)
            XCTAssertFalse(roster.isEmpty, "\(realm.name) has nothing to fight")
            XCTAssertTrue(roster.contains { $0.earliestWave <= 1 },
                          "\(realm.name) has nothing that can appear on wave one")
            XCTAssertNil(roster.first { $0.isBoss }, "\(realm.name) spawns a champion as ordinary horde")
        }
    }

    func testRostersDrawOnMoreThanOneFamilyBeyondTheFirstRealm() {
        for realm in RealmCatalog.all where realm.order > 1 {
            let families = Set(EnemyCatalog.roster(for: realm.id).map(\.family))
            XCTAssertGreaterThan(families.count, 1, "\(realm.name) fields a single family")
        }
    }

    func testEveryRealmHasChampionsAndTheyExist() {
        for realm in RealmCatalog.all {
            let bosses = EnemyCatalog.bosses(for: realm.id)
            XCTAssertFalse(bosses.isEmpty, "\(realm.name) has no champion")
            for id in bosses {
                let definition = EnemyCatalog.definition(for: id)
                XCTAssertNotNil(definition, "\(realm.name) names a champion that is not in the catalogue")
                XCTAssertTrue(definition?.isBoss ?? false, "\(id) is used as a champion but is not one")
            }
        }
    }

    func testSummonersOnlyCallCreaturesThatExist() {
        for definition in EnemyCatalog.all {
            guard case .summoner(let spawns, _, _, _) = definition.behavior else { continue }
            XCTAssertNotNil(EnemyCatalog.definition(for: spawns),
                            "\(definition.id) calls \(spawns), which is not in the catalogue")
        }
    }

    // MARK: The wave clock

    func testConquestAlwaysLandsOnAChampion() {
        for realm in RealmCatalog.all {
            guard let conquest = realm.conquestWave else { continue }
            XCTAssertTrue(realm.waves.isBossWave(conquest),
                          "\(realm.name) is conquered on wave \(conquest), which has no champion")
        }
    }

    func testChampionsArriveInOrderAndTheLastOneRepeats() {
        let plan = WavePlan(waveSeconds: 45, bossEvery: 5, bosses: ["a", "b"])
        XCTAssertNil(plan.boss(forWave: 4))
        XCTAssertEqual(plan.boss(forWave: 5), "a")
        XCTAssertEqual(plan.boss(forWave: 10), "b")
        XCTAssertEqual(plan.boss(forWave: 15), "b", "the last champion should keep coming back")
    }

    func testPressureRisesWithTheWave() {
        let plan = WavePlan()
        XCTAssertEqual(plan.pressure(atWave: 1), 1)
        XCTAssertGreaterThan(plan.pressure(atWave: 10), plan.pressure(atWave: 5))
    }

    // MARK: Helpers

    private func kinds(of rule: DecorationRule) -> [DecorationKind] {
        switch rule {
        case .scatter(let kind, _, _):
            return [kind]
        case .cluster(let cluster):
            return cluster.members.map(\.kind)
        }
    }
}
