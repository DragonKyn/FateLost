import Foundation

/// Where a run's skill points have gone.
///
/// A plain value: the skill tree screen edits a copy as a draft (so choices
/// can be reconsidered before confirming) and the simulation compiles the
/// committed one into gameplay effects.
struct SkillAllocation: Equatable {
    private(set) var ranks: [SkillID: Int] = [:]
    private(set) var archetypePoints: [ArchetypeID: Int] = [:]
    private(set) var pathPoints: [PathID: Int] = [:]
    /// Points spent per archetype and tier, for tier requirements.
    private(set) var tierPoints: [ArchetypeID: [Int]] = [:]
    private(set) var spent = 0

    func rank(of id: SkillID) -> Int {
        ranks[id] ?? 0
    }

    func points(in archetype: ArchetypeID) -> Int {
        archetypePoints[archetype] ?? 0
    }

    func points(inPath path: PathID) -> Int {
        pathPoints[path] ?? 0
    }

    /// Points in `archetype` spent on tiers below `tier`.
    func points(in archetype: ArchetypeID, below tier: SkillTier) -> Int {
        guard let tiers = tierPoints[archetype] else { return 0 }
        var total = 0
        for index in 0..<(tier.rawValue - 1) where index < tiers.count {
            total += tiers[index]
        }
        return total
    }

    mutating func add(_ skill: SkillDefinition) {
        adjust(skill, by: 1)
    }

    mutating func remove(_ skill: SkillDefinition) {
        guard rank(of: skill.id) > 0 else { return }
        adjust(skill, by: -1)
    }

    private mutating func adjust(_ skill: SkillDefinition, by delta: Int) {
        let newRank = rank(of: skill.id) + delta
        ranks[skill.id] = newRank > 0 ? newRank : nil
        archetypePoints[skill.archetype, default: 0] += delta
        if let path = skill.path {
            pathPoints[path, default: 0] += delta
        }
        var tiers = tierPoints[skill.archetype] ?? Array(repeating: 0, count: SkillTier.allCases.count)
        tiers[skill.tier.rawValue - 1] += delta
        tierPoints[skill.archetype] = tiers
        spent += delta
    }

    /// Learned skills with their ranks, in catalogue order.
    var learned: [(skill: SkillDefinition, rank: Int)] {
        SkillCatalog.all.compactMap { skill in
            let rank = self.rank(of: skill.id)
            return rank > 0 ? (skill, rank) : nil
        }
    }
}

/// The rules of the skill tree. Thresholds are configuration, not code.
struct SkillTreeRules {
    /// Points needed in an archetype's lower tiers before a tier opens.
    var tierThresholds: [SkillTier: Int] = [.one: 0, .two: 3, .three: 7, .four: 12, .capstone: 20]
    /// Points needed in an order node's *second* archetype. Deliberately
    /// close to the primary thresholds: an order should cost about as much
    /// again as the tree it hangs off, which is what makes going wide a
    /// real decision rather than a free extra.
    var synergyThresholds: [SkillTier: Int] = [.one: 0, .two: 4, .three: 8, .four: 12, .capstone: 14]
    /// Capstones one archetype allows: committing to one subclass's peak
    /// closes the others, so a build has to choose who it becomes.
    var capstonesPerArchetype = 1
    /// Order capstones allowed across the whole build. One: you become one
    /// thing, not a collector of endings.
    var orderCapstones = 1

    static let standard = SkillTreeRules()

    func threshold(for tier: SkillTier) -> Int {
        tierThresholds[tier] ?? 0
    }

    func synergyThreshold(for tier: SkillTier) -> Int {
        synergyThresholds[tier] ?? 0
    }

    /// Why a skill can't take another point right now.
    enum Denial: Equatable {
        case noPoints
        case maxRank
        /// This many more points are needed in the archetype's lower tiers.
        case needsPoints(Int)
        /// One of these must be learned first.
        case needsPrerequisite([SkillID])
        /// Another capstone of this archetype is already taken.
        case capstoneTaken(SkillID)
        /// This many more points are needed in the order's second archetype.
        case needsSynergy(ArchetypeID, Int)
        /// An order capstone is already taken.
        case orderCapstoneTaken(SkillID)
    }

    func denial(for skill: SkillDefinition, in allocation: SkillAllocation, availablePoints: Int) -> Denial? {
        if allocation.rank(of: skill.id) >= skill.maxRank {
            return .maxRank
        }
        // Reported before anything else: having finished an order is a
        // permanent answer, and no amount of further spending changes it.
        if skill.order != nil, skill.tier == .capstone, allocation.rank(of: skill.id) == 0 {
            let taken = SkillCatalog.orderSkills.filter {
                $0.tier == .capstone && $0.id != skill.id && allocation.rank(of: $0.id) > 0
            }
            if taken.count >= orderCapstones, let first = taken.first {
                return .orderCapstoneTaken(first.id)
            }
        }
        let have = allocation.points(in: skill.archetype, below: skill.tier)
        let need = threshold(for: skill.tier)
        if have < need {
            return .needsPoints(need - have)
        }
        if let synergy = skill.synergy {
            let held = allocation.points(in: synergy)
            let wanted = synergyThreshold(for: skill.tier)
            if held < wanted {
                return .needsSynergy(synergy, wanted - held)
            }
        }
        if !skill.prerequisites.isEmpty,
           !skill.prerequisites.contains(where: { allocation.rank(of: $0) > 0 }) {
            return .needsPrerequisite(skill.prerequisites)
        }
        if skill.order == nil, skill.tier == .capstone, allocation.rank(of: skill.id) == 0 {
            let taken = SkillCatalog.skills(for: skill.archetype).filter {
                $0.tier == .capstone && $0.id != skill.id && allocation.rank(of: $0.id) > 0
            }
            if taken.count >= capstonesPerArchetype, let first = taken.first {
                return .capstoneTaken(first.id)
            }
        }
        if availablePoints <= 0 {
            return .noPoints
        }
        return nil
    }

    /// Whether a point can be taken back out of a draft without breaking
    /// anything learned on top of it.
    func canRemove(_ skill: SkillDefinition, from allocation: SkillAllocation, floor: SkillAllocation) -> Bool {
        guard allocation.rank(of: skill.id) > floor.rank(of: skill.id) else { return false }
        var reduced = allocation
        reduced.remove(skill)
        return isValid(reduced)
    }

    /// Whether an allocation could have been reached one legal point at a
    /// time. Order-independent: every tier with points must have enough
    /// points below it, prerequisites must be present, ranks within limits
    /// and capstones within the allowance.
    func isValid(_ allocation: SkillAllocation) -> Bool {
        for (id, rank) in allocation.ranks {
            guard let skill = SkillCatalog.skill(id) else { return false }
            if rank > skill.maxRank { return false }
            if allocation.points(in: skill.archetype, below: skill.tier) < threshold(for: skill.tier) {
                return false
            }
            if !skill.prerequisites.isEmpty,
               !skill.prerequisites.contains(where: { allocation.rank(of: $0) > 0 }) {
                return false
            }
            if let synergy = skill.synergy,
               allocation.points(in: synergy) < synergyThreshold(for: skill.tier) {
                return false
            }
        }
        for archetype in ArchetypeID.allCases {
            let capstones = SkillCatalog.skills(for: archetype).filter {
                $0.tier == .capstone && allocation.rank(of: $0.id) > 0
            }
            if capstones.count > capstonesPerArchetype { return false }
        }
        let orderCapstonesTaken = SkillCatalog.orderSkills.filter {
            $0.tier == .capstone && allocation.rank(of: $0.id) > 0
        }
        if orderCapstonesTaken.count > orderCapstones { return false }
        return true
    }
}

/// What a build is called, from where its points went.
///
/// Everyone starts as an Adventurer. Three points in an archetype earn its
/// name; a clear lean toward one subclass path earns that path's name
/// instead ("Frostweaver", "Beastmaster"). An order outranks both: once
/// enough of one is taken, that is simply what you are, because reaching it
/// cost points in two archetypes and nothing else in the build says as much.
enum BuildTitle {
    struct Title: Equatable {
        let name: String
        let subtitle: String?
        let archetype: ArchetypeID?
        let order: HybridID?

        init(name: String, subtitle: String?, archetype: ArchetypeID?, order: HybridID? = nil) {
            self.name = name
            self.subtitle = subtitle
            self.archetype = archetype
            self.order = order
        }
    }

    static let archetypeThreshold = 3
    static let pathThreshold = 6
    /// Points in one order before it names the build.
    static let orderThreshold = 4

    static func title(for allocation: SkillAllocation) -> Title {
        if let order = leadingOrder(in: allocation), let definition = HybridOrders.order(order) {
            let second = SkillCatalog.archetype(definition.synergy)?.name ?? ""
            let first = SkillCatalog.archetype(definition.primary)?.name ?? ""
            return Title(name: definition.name, subtitle: "\(first) and \(second) both, and neither",
                         archetype: definition.primary, order: order)
        }
        let ranked = ArchetypeID.allCases
            .map { ($0, allocation.points(in: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        guard let top = ranked.first, top.1 >= archetypeThreshold,
              let definition = SkillCatalog.archetype(top.0) else {
            return Title(name: "Adventurer", subtitle: nil, archetype: nil)
        }

        var name = definition.name
        let paths = definition.paths
            .map { ($0, allocation.points(inPath: $0.id)) }
            .sorted { $0.1 > $1.1 }
        if let leading = paths.first, leading.1 >= pathThreshold {
            let runnerUp = paths.count > 1 ? paths[1].1 : 0
            if leading.1 > runnerUp {
                name = leading.0.name
            }
        }

        var subtitle: String?
        if ranked.count > 1, ranked[1].1 >= archetypeThreshold,
           let secondary = SkillCatalog.archetype(ranked[1].0) {
            subtitle = "with the ways of the \(secondary.name)"
        }
        return Title(name: name, subtitle: subtitle, archetype: top.0)
    }

    /// The order with the most points in it, if any has enough to speak for
    /// the build. Ties go to the earlier order so the name does not flicker.
    static func leadingOrder(in allocation: SkillAllocation) -> HybridID? {
        var best: (HybridID, Int)?
        for order in HybridID.allCases {
            let points = points(in: order, of: allocation)
            guard points >= orderThreshold else { continue }
            if best == nil || points > best!.1 {
                best = (order, points)
            }
        }
        return best?.0
    }

    static func points(in order: HybridID, of allocation: SkillAllocation) -> Int {
        SkillCatalog.skills(inOrder: order).reduce(0) { $0 + allocation.rank(of: $1.id) }
    }
}
