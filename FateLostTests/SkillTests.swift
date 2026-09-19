import CoreGraphics
import XCTest
@testable import FateLost

final class SkillCatalogTests: XCTestCase {
    func testEveryArchetypeHasAFullTree() {
        XCTAssertEqual(SkillCatalog.archetypes.count, ArchetypeID.allCases.count)
        for archetype in SkillCatalog.archetypes {
            let skills = SkillCatalog.skills(for: archetype.id)
            XCTAssertEqual(archetype.paths.count, 3, archetype.name)
            XCTAssertEqual(skills.count, 21, archetype.name)
            XCTAssertEqual(skills.filter { $0.path == nil }.count, 3, "\(archetype.name) core")
            for path in archetype.paths {
                let pathSkills = skills.filter { $0.path == path.id }
                XCTAssertEqual(pathSkills.count, 6, path.name)
                XCTAssertEqual(pathSkills.filter { $0.tier == .capstone }.count, 1, path.name)
            }
        }
    }

    func testIdentifiersAreUnique() {
        let ids = SkillCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        let abilities = SkillCatalog.all.compactMap(\.ability).map(\.id)
        XCTAssertEqual(Set(abilities).count, abilities.count)
    }

    func testPrerequisitesPointDownTheSameTree() {
        for skill in SkillCatalog.all {
            for id in skill.prerequisites {
                guard let prerequisite = SkillCatalog.skill(id) else {
                    XCTFail("\(skill.id) requires unknown \(id)")
                    continue
                }
                XCTAssertEqual(prerequisite.archetype, skill.archetype, skill.id)
                XCTAssertLessThan(prerequisite.tier, skill.tier, skill.id)
            }
        }
    }

    func testDescriptionsResolveEveryPlaceholder() {
        for skill in SkillCatalog.all {
            for rank in 1...skill.maxRank {
                let text = skill.description(atRank: rank)
                XCTAssertFalse(text.contains("{"), "\(skill.id) rank \(rank): \(text)")
            }
            XCTAssertFalse(skill.symbol.isEmpty, skill.id)
        }
    }

    func testFormsAndSummonsExist() {
        for skill in SkillCatalog.all {
            for effect in skill.effects {
                if case .permanentForm(let form) = effect {
                    XCTAssertNotNil(FormCatalog.form(form), skill.id)
                }
                if case .ability(let ability) = effect, case .transform(let form) = ability.action {
                    XCTAssertNotNil(FormCatalog.form(form), skill.id)
                }
            }
        }
    }
}

final class SkillRulesTests: XCTestCase {
    private let rules = SkillTreeRules.standard

    private func skill(_ id: String) -> SkillDefinition {
        guard let skill = SkillCatalog.skill(id) else { fatalError("missing \(id)") }
        return skill
    }

    func testHigherTiersNeedPointsBelow() {
        var allocation = SkillAllocation()
        let cleave = skill("warrior.slayer.cleave")
        XCTAssertEqual(rules.denial(for: cleave, in: allocation, availablePoints: 5), .needsPoints(3))
        let discipline = skill("warrior.core.weaponDiscipline")
        for _ in 0..<3 {
            XCTAssertNil(rules.denial(for: discipline, in: allocation, availablePoints: 5))
            allocation.add(discipline)
        }
        XCTAssertNil(rules.denial(for: cleave, in: allocation, availablePoints: 5))
        XCTAssertEqual(rules.denial(for: cleave, in: allocation, availablePoints: 0), .noPoints)
    }

    func testPointsInOtherArchetypesDoNotOpenTiers() {
        var allocation = SkillAllocation()
        let keenEdge = skill("rogue.core.keenEdge")
        for _ in 0..<5 { allocation.add(keenEdge) }
        XCTAssertEqual(rules.denial(for: skill("warrior.slayer.cleave"), in: allocation, availablePoints: 1),
                       .needsPoints(3))
    }

    func testOnlyOneCapstonePerArchetype() {
        var allocation = SkillAllocation()
        for skill in SkillCatalog.skills(for: .monk) where skill.tier != .capstone {
            for _ in 0..<skill.maxRank { allocation.add(skill) }
        }
        let capstones = SkillCatalog.skills(for: .monk).filter { $0.tier == .capstone }
        XCTAssertNil(rules.denial(for: capstones[0], in: allocation, availablePoints: 1))
        allocation.add(capstones[0])
        XCTAssertEqual(rules.denial(for: capstones[1], in: allocation, availablePoints: 1),
                       .capstoneTaken(capstones[0].id))
        XCTAssertTrue(rules.isValid(allocation))
    }

    func testRemovingAFoundationPointIsRefused() {
        var allocation = SkillAllocation()
        let ironHide = skill("warrior.core.ironHide")
        for _ in 0..<3 { allocation.add(ironHide) }
        allocation.add(skill("warrior.knight.retribution"))
        XCTAssertFalse(rules.canRemove(ironHide, from: allocation, floor: SkillAllocation()))
        XCTAssertTrue(rules.canRemove(skill("warrior.knight.retribution"), from: allocation, floor: SkillAllocation()))
    }

    func testTitlesFollowInvestment() {
        var allocation = SkillAllocation()
        XCTAssertEqual(BuildTitle.title(for: allocation).name, "Adventurer")
        let wellspring = skill("sorcerer.core.wellspring")
        for _ in 0..<3 { allocation.add(wellspring) }
        XCTAssertEqual(BuildTitle.title(for: allocation).name, "Sorcerer")
    }
}

final class StatSheetTests: XCTestCase {
    func testIncreasesAddAndMoreMultiplies() {
        var sheet = StatSheet()
        sheet.add(StatModifier(.maxHealth, .flat, 20))
        sheet.add(StatModifier(.maxHealth, .increased, 0.1))
        sheet.add(StatModifier(.maxHealth, .increased, 0.2))
        sheet.add(StatModifier(.maxHealth, .more, 0.5))
        sheet.finalize()
        XCTAssertEqual(sheet[.maxHealth], 120 * 1.3 * 1.5, accuracy: 0.0001)
    }

    func testDamageIncreasesStackAdditively() {
        var sheet = StatSheet()
        sheet.add(StatModifier(.fireDamage, .increased, 0.2))
        sheet.add(StatModifier(.spellDamage, .increased, 0.2))
        sheet.add(StatModifier(.damage, .more, 0.5))
        sheet.finalize()
        XCTAssertEqual(sheet.damageMultiplier(for: .fire, tags: .spell), 1.4 * 1.5, accuracy: 0.0001)
        XCTAssertEqual(sheet.damageMultiplier(for: .cold, tags: .melee), 1.5, accuracy: 0.0001)
    }

    func testCapsHold() {
        var sheet = StatSheet()
        sheet.add(StatModifier(.dodgeChance, .flat, 5))
        sheet.add(StatModifier(.cooldownReduction, .flat, 5))
        sheet.finalize()
        XCTAssertEqual(sheet[.dodgeChance], 0.6)
        XCTAssertEqual(sheet[.cooldownReduction], 0.5)
    }
}

final class ProgressionTests: XCTestCase {
    private func makeSimulation() -> GameSimulation {
        GameSimulation(run: RunConfiguration(realmID: .ashenWilds, starterWeaponID: StarterWeapons.sword.id, seed: 7),
                       tuning: .standard)
    }

    func testRequirementsGrow() {
        let tuning = ProgressionTuning()
        var previous = 0
        for level in 1...60 {
            let requirement = tuning.requirement(toAdvanceFrom: level)
            XCTAssertGreaterThan(requirement, previous)
            previous = requirement
        }
    }

    func testLevellingGrantsAPointAndABurst() {
        var simulation = makeSimulation()
        simulation.spawnEnemies(20)
        simulation.grantLevels(1)
        XCTAssertEqual(simulation.progression.level, 2)
        XCTAssertEqual(simulation.progression.unspentPoints, 1)
        let events = simulation.drainEvents()
        XCTAssertTrue(events.contains { if case .levelUp(2, _) = $0 { return true } else { return false } })
        XCTAssertGreaterThan(simulation.player.maxHealth, 100)
    }

    func testCommitSpendsPointsAndRejectsOverspending() {
        var simulation = makeSimulation()
        simulation.grantLevels(2)
        guard let spin = SkillCatalog.skill("warrior.core.sunderingSpin") else { return XCTFail() }
        var draft = SkillAllocation()
        draft.add(spin)
        XCTAssertTrue(simulation.commit(draft, slots: []))
        XCTAssertEqual(simulation.progression.unspentPoints, 1)
        XCTAssertEqual(simulation.abilitySlots[0], spin.ability?.id)

        var greedy = draft
        for _ in 0..<3 { greedy.add(spin) }
        XCTAssertFalse(simulation.commit(greedy, slots: []))
    }

    func testCollectingEmbersGivesExperience() {
        var simulation = makeSimulation()
        simulation.spawnEnemies(30)
        simulation.defeatAllEnemies()
        let intent = PlayerIntent.idle
        for _ in 0..<180 {
            simulation.step(dt: 1.0 / 60.0, intent: intent)
        }
        // Enemies spawned off-screen, so their embers lie out of reach.
        XCTAssertEqual(simulation.stats.kills, 30)
        XCTAssertFalse(simulation.combat.orbs.isEmpty)
    }
}

final class StatusTests: XCTestCase {
    func testPoisonDealsDamageOverTime() {
        var combat = CombatState(world: ToroidalWorld(width: 64, height: 64), tuning: CombatTuning(),
                                 gridCellSize: 1.5, capacity: 8, seed: 3)
        let kind = combat.enemies.kindIndex(for: EnemyCatalog.brute)
        combat.enemies.append(id: combat.makeEntityID(), kind: kind, position: CGPoint(x: 10, y: 10), speedScale: 1)
        combat.applyStatus(StatusApplication(.poison, potency: 1, duration: 3), to: 0)
        XCTAssertTrue(combat.enemies.hasStatus(.poison, at: 0))
        var system = StatusSystem()
        for _ in 0..<60 {
            system.step(&combat, dt: 1.0 / 60.0)
        }
        XCTAssertLessThan(combat.enemies.health[0], EnemyCatalog.brute.maxHealth)
        for _ in 0..<180 {
            system.step(&combat, dt: 1.0 / 60.0)
        }
        XCTAssertFalse(combat.enemies.hasStatus(.poison, at: 0))
    }
}

/// Learns nearly every skill in the game at full rank, casts every ability
/// and lets a crowd fight it out: catches crashes and runaway effects that
/// only appear in combination.
final class SkillSmokeTests: XCTestCase {
    func testEverySkillAndAbilityRuns() {
        var simulation = GameSimulation(run: RunConfiguration(realmID: .ashenWilds,
                                                              starterWeaponID: StarterWeapons.bow.id, seed: 11),
                                        tuning: .standard)
        simulation.cheats.godMode = true
        simulation.grantLevels(760)

        var draft = SkillAllocation()
        for archetype in ArchetypeID.allCases {
            var capstoneTaken = false
            for tier in SkillTier.allCases {
                for skill in SkillCatalog.skills(for: archetype) where skill.tier == tier {
                    if tier == .capstone {
                        if capstoneTaken { continue }
                        capstoneTaken = true
                    }
                    for _ in 0..<skill.maxRank { draft.add(skill) }
                }
            }
        }
        XCTAssertTrue(SkillTreeRules.standard.isValid(draft))
        XCTAssertTrue(simulation.commit(draft, slots: []))
        simulation.spawnEnemies(150)

        let dt = 1.0 / 60.0
        let moving = PlayerIntent(move: CGPoint(x: 0.7, y: 0.3))
        let abilities = SkillCatalog.all.compactMap(\.ability)
        for (index, ability) in abilities.enumerated() {
            var slots: [AbilityID?] = Array(repeating: nil, count: AbilitySlots.count)
            slots[ability.isUltimate ? AbilitySlots.ultimate : 0] = ability.id
            simulation.equip(slots)
            simulation.step(dt: dt, intent: PlayerIntent(move: moving.move, abilityPresses: 0b1111))
            for _ in 0..<6 {
                simulation.step(dt: dt, intent: moving)
            }
            if index % 8 == 0 {
                simulation.spawnEnemies(40)
            }
            _ = simulation.drainEvents()
        }
        for _ in 0..<600 {
            simulation.step(dt: dt, intent: moving)
            _ = simulation.drainEvents()
        }
        XCTAssertGreaterThan(simulation.stats.kills, 0)
        XCTAssertFalse(simulation.isPlayerDefeated)
        XCTAssertLessThanOrEqual(simulation.combat.allies.filter { $0.companionKey == nil }.count,
                                 AllySystem.maximumTemporary)
    }
}
