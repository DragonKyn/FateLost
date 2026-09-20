import XCTest
@testable import FateLost

/// Orders are the reward for spreading points across two archetypes. These
/// tests hold that bargain in place: an order must never be reachable on one
/// tree alone, and must never be a better single-tree pick than the tree it
/// hangs off.
final class OrderTests: XCTestCase {
    private let rules = SkillTreeRules.standard

    private func skill(_ id: SkillID) -> SkillDefinition {
        guard let found = SkillCatalog.skill(id) else {
            XCTFail("missing skill \(id)")
            return SkillCatalog.all[0]
        }
        return found
    }

    /// Fills an archetype's tier-one nodes until it holds `points`.
    private func invest(_ allocation: inout SkillAllocation, _ archetype: ArchetypeID, _ points: Int) {
        let core = SkillCatalog.skills(for: archetype).filter { $0.tier == .one }
        var added = 0
        while added < points {
            var moved = false
            for node in core where added < points && allocation.rank(of: node.id) < node.maxRank {
                allocation.add(node)
                added += 1
                moved = true
            }
            if !moved { break }
        }
        XCTAssertEqual(added, points, "could not put \(points) points into \(archetype.rawValue)")
    }

    // MARK: Shape

    func testEveryOrderHasABoardAndNamesTwoDifferentArchetypes() {
        XCTAssertEqual(HybridOrders.all.count, HybridID.allCases.count)
        for order in HybridOrders.all {
            XCTAssertNotEqual(order.primary, order.synergy, "\(order.name) synergises with itself")
            let nodes = SkillCatalog.skills(inOrder: order.id)
            XCTAssertEqual(nodes.count, 5, "\(order.name) does not have five nodes")
            XCTAssertEqual(nodes.filter { $0.tier == .capstone }.count, 1, "\(order.name) has no single capstone")
            for node in nodes {
                XCTAssertEqual(node.archetype, order.primary)
                XCTAssertEqual(node.synergy, order.synergy)
                XCTAssertEqual(node.order, order.id)
                XCTAssertNil(node.path, "\(node.id) would show up inside an archetype path")
                XCTAssertNotEqual(node.tier, .one, "\(node.id) is reachable before anything is invested")
            }
        }
    }

    func testOrderNodesAreNotInAnyArchetypeTree() {
        let orderIDs = Set(SkillCatalog.orderSkills.map(\.id))
        for archetype in ArchetypeID.allCases {
            for node in SkillCatalog.skills(for: archetype) {
                XCTAssertFalse(orderIDs.contains(node.id), "\(node.id) is in the \(archetype.rawValue) tree")
                XCTAssertNil(node.order, "\(node.id) claims an order but sits in a tree")
            }
        }
    }

    func testEveryPrerequisiteAndAbilityIsRealAndUnique() {
        var abilityIDs: Set<AbilityID> = []
        for node in SkillCatalog.orderSkills {
            for required in node.prerequisites {
                XCTAssertNotNil(SkillCatalog.skill(required), "\(node.id) requires \(required), which is missing")
            }
            guard let ability = node.ability else { continue }
            XCTAssertFalse(abilityIDs.contains(ability.id), "two skills grant ability \(ability.id)")
            abilityIDs.insert(ability.id)
        }
        // Order abilities must not collide with an archetype's either.
        for node in SkillCatalog.all where node.order == nil {
            if let ability = node.ability {
                XCTAssertFalse(abilityIDs.contains(ability.id), "\(ability.id) is granted twice")
            }
        }
    }

    // MARK: The bargain

    func testAnOrderNodeIsRefusedWithoutTheSecondArchetype() {
        let order = HybridOrders.all[0]
        let entry = SkillCatalog.skills(inOrder: order.id).first { $0.tier == .two }!
        var allocation = SkillAllocation()
        invest(&allocation, order.primary, 12)

        let denial = rules.denial(for: entry, in: allocation, availablePoints: 10)
        guard case .needsSynergy(let wanted, let short)? = denial else {
            return XCTFail("expected a synergy denial, got \(String(describing: denial))")
        }
        XCTAssertEqual(wanted, order.synergy)
        XCTAssertEqual(short, rules.synergyThreshold(for: .two))
    }

    func testAnOrderNodeOpensOnceBothTreesAreInvestedIn() {
        let order = HybridOrders.all[0]
        let entry = SkillCatalog.skills(inOrder: order.id).first { $0.tier == .two }!
        var allocation = SkillAllocation()
        invest(&allocation, order.primary, 3)
        invest(&allocation, order.synergy, rules.synergyThreshold(for: .two))

        XCTAssertNil(rules.denial(for: entry, in: allocation, availablePoints: 5))
        allocation.add(entry)
        XCTAssertTrue(rules.isValid(allocation))
    }

    func testAnAllocationThatLosesItsSecondArchetypeIsNotValid() {
        let order = HybridOrders.all[0]
        let entry = SkillCatalog.skills(inOrder: order.id).first { $0.tier == .two }!
        var allocation = SkillAllocation()
        invest(&allocation, order.primary, 3)
        invest(&allocation, order.synergy, rules.synergyThreshold(for: .two))
        allocation.add(entry)

        let synergyCore = SkillCatalog.skills(for: order.synergy).first { allocation.rank(of: $0.id) > 0 }!
        XCTAssertFalse(rules.canRemove(synergyCore, from: allocation, floor: SkillAllocation()),
                       "the order node should hold its second archetype in place")
    }

    func testOnlyOneOrderCapstoneMayBeTaken() {
        var allocation = SkillAllocation()
        let capstones = SkillCatalog.orderSkills.filter { $0.tier == .capstone }
        XCTAssertGreaterThan(capstones.count, 1)
        allocation.add(capstones[0])
        let denial = rules.denial(for: capstones[1], in: allocation, availablePoints: 10)
        XCTAssertEqual(denial, .orderCapstoneTaken(capstones[0].id))
    }

    // MARK: Naming

    func testAnOrderNamesTheBuild() {
        let order = HybridOrders.all[0]
        var allocation = SkillAllocation()
        invest(&allocation, order.primary, 3)
        invest(&allocation, order.synergy, rules.synergyThreshold(for: .two))
        XCTAssertNil(BuildTitle.title(for: allocation).order, "an order should not name a build it has no points in")

        let entry = SkillCatalog.skills(inOrder: order.id).first { $0.tier == .two }!
        for _ in 0..<BuildTitle.orderThreshold where allocation.rank(of: entry.id) < entry.maxRank {
            allocation.add(entry)
        }
        let second = SkillCatalog.skills(inOrder: order.id).last { $0.tier == .two }!
        while BuildTitle.points(in: order.id, of: allocation) < BuildTitle.orderThreshold,
              allocation.rank(of: second.id) < second.maxRank {
            allocation.add(second)
        }

        let title = BuildTitle.title(for: allocation)
        XCTAssertEqual(title.order, order.id)
        XCTAssertEqual(title.name, order.name)
    }
}
