import Foundation

/// The Legacy board: ten strands, ten tiers deep, five nodes across.
///
/// Five hundred nodes are not hand-written — they are laid out from a short
/// table per strand, because five hundred hand-written nodes would be five
/// hundred chances to make one of them the correct first pick. Every node in
/// a tier costs the same and gives the same *size* of bonus; what differs is
/// which stat it touches. That is the anti-meta rule from the skill tree
/// carried into meta-progression: the board rewards hours, not an opening.
///
/// A tier opens once enough of the tier above it has been bought, in that
/// strand alone, so a player can pour everything into one strand or spread
/// across all ten without either being wrong.
enum LegacyTree {
    /// Tiers per strand.
    static let tierCount = 10
    /// Nodes per tier.
    static let nodesPerTier = 5
    /// Nodes that must be bought in a strand's tier before the next opens.
    static let nodesToAdvance = 3

    /// One stat a strand can improve, with the size of a tier-1 bonus.
    private struct Grain {
        let stat: StatID
        let kind: ModifierKind
        /// Bonus at tier 1; deeper tiers scale this up.
        let base: Double
        let title: String
    }

    /// What each strand is made of. Five grains per strand, one per column,
    /// so a tier row reads as five different small choices.
    private static func grains(of branch: LegacyBranch) -> [Grain] {
        switch branch {
        case .body:
            return [
                Grain(stat: .maxHealth, kind: .flat, base: 4, title: "Iron Marrow"),
                Grain(stat: .maxHealth, kind: .increased, base: 0.008, title: "Deep Lungs"),
                Grain(stat: .healthRegen, kind: .flat, base: 0.12, title: "Slow Mending"),
                Grain(stat: .armor, kind: .flat, base: 1.2, title: "Thick Hide"),
                Grain(stat: .healingReceived, kind: .increased, base: 0.01, title: "Willing Flesh"),
            ]
        case .blade:
            return [
                Grain(stat: .damage, kind: .increased, base: 0.006, title: "Honed Edge"),
                Grain(stat: .meleeDamage, kind: .increased, base: 0.01, title: "Close Work"),
                Grain(stat: .attackSpeed, kind: .increased, base: 0.006, title: "Loose Wrist"),
                Grain(stat: .physicalDamage, kind: .increased, base: 0.01, title: "Weight Behind It"),
                Grain(stat: .knockback, kind: .increased, base: 0.014, title: "Follow Through"),
            ]
        case .focus:
            return [
                Grain(stat: .spellDamage, kind: .increased, base: 0.01, title: "Clear Sight"),
                Grain(stat: .cooldownReduction, kind: .flat, base: 0.003, title: "Quick Recall"),
                Grain(stat: .areaSize, kind: .increased, base: 0.008, title: "Wider Reach"),
                Grain(stat: .effectDuration, kind: .increased, base: 0.01, title: "Held Longer"),
                Grain(stat: .magicDamage, kind: .increased, base: 0.008, title: "Deeper Well"),
            ]
        case .fortune:
            return [
                Grain(stat: .experienceGain, kind: .increased, base: 0.01, title: "Hard Lessons"),
                Grain(stat: .pickupRadius, kind: .flat, base: 0.06, title: "Long Arms"),
                Grain(stat: .critChance, kind: .flat, base: 0.003, title: "Lucky Angle"),
                Grain(stat: .critDamage, kind: .flat, base: 0.012, title: "Found the Seam"),
                Grain(stat: .spellEcho, kind: .flat, base: 0.002, title: "Said Twice"),
            ]
        case .ward:
            return [
                Grain(stat: .dodgeChance, kind: .flat, base: 0.003, title: "Read the Swing"),
                Grain(stat: .armor, kind: .increased, base: 0.012, title: "Set Your Feet"),
                Grain(stat: .overhealBarrier, kind: .flat, base: 0.006, title: "Nothing Wasted"),
                Grain(stat: .moveSpeed, kind: .increased, base: 0.004, title: "Light Step"),
                Grain(stat: .maxHealth, kind: .flat, base: 3, title: "One More Scar"),
            ]
        case .flame:
            return [
                Grain(stat: .fireDamage, kind: .increased, base: 0.012, title: "Fed the Fire"),
                Grain(stat: .dotDamage, kind: .increased, base: 0.01, title: "Slow Burn"),
                Grain(stat: .areaDamage, kind: .increased, base: 0.01, title: "Everything Near"),
                Grain(stat: .statusChance, kind: .increased, base: 0.008, title: "Catches Easily"),
                Grain(stat: .lightningDamage, kind: .increased, base: 0.012, title: "Storm-Fed"),
            ]
        case .frost:
            return [
                Grain(stat: .coldDamage, kind: .increased, base: 0.012, title: "Bitter Air"),
                Grain(stat: .statusChance, kind: .increased, base: 0.008, title: "Takes Hold"),
                Grain(stat: .effectDuration, kind: .increased, base: 0.008, title: "Does Not Thaw"),
                Grain(stat: .projectileSpeed, kind: .increased, base: 0.012, title: "Thrown Harder"),
                Grain(stat: .pierce, kind: .flat, base: 0.06, title: "Straight Through"),
            ]
        case .shadow:
            return [
                Grain(stat: .shadowDamage, kind: .increased, base: 0.012, title: "From Behind"),
                Grain(stat: .critChance, kind: .flat, base: 0.003, title: "Where It Counts"),
                Grain(stat: .lifeSteal, kind: .flat, base: 0.002, title: "Taken Back"),
                Grain(stat: .poisonDamage, kind: .increased, base: 0.012, title: "Something on the Blade"),
                Grain(stat: .projectileDamage, kind: .increased, base: 0.01, title: "At a Distance"),
            ]
        case .bond:
            return [
                Grain(stat: .summonDamage, kind: .increased, base: 0.012, title: "Well Taught"),
                Grain(stat: .summonLifeSteal, kind: .flat, base: 0.002, title: "Shared Breath"),
                Grain(stat: .effectDuration, kind: .increased, base: 0.008, title: "Stays Longer"),
                Grain(stat: .healingReceived, kind: .increased, base: 0.008, title: "Tended To"),
                Grain(stat: .summonCount, kind: .flat, base: 0.05, title: "One More Voice"),
            ]
        case .fate:
            return [
                Grain(stat: .damage, kind: .increased, base: 0.005, title: "Owed a Death"),
                Grain(stat: .maxHealth, kind: .increased, base: 0.006, title: "Not Yet"),
                Grain(stat: .experienceGain, kind: .increased, base: 0.008, title: "It Adds Up"),
                Grain(stat: .cooldownReduction, kind: .flat, base: 0.002, title: "Sooner Than That"),
                Grain(stat: .holyDamage, kind: .increased, base: 0.012, title: "Witnessed"),
            ]
        }
    }

    /// Echoes one node in a tier costs. Deeper is dearer, but never so dear
    /// that the first strand a player picks becomes the only one they finish.
    static func cost(atTier tier: Int) -> Int {
        40 + (tier - 1) * (tier - 1) * 22 + (tier - 1) * 60
    }

    /// How much a tier-1 bonus is multiplied by at this depth.
    static func scale(atTier tier: Int) -> Double {
        1 + Double(tier - 1) * 0.35
    }

    /// Every node on the board, in strand then tier then column order.
    static let all: [LegacyNode] = LegacyBranch.allCases.flatMap { branch -> [LegacyNode] in
        let grains = grains(of: branch)
        return (1...tierCount).flatMap { tier -> [LegacyNode] in
            (0..<nodesPerTier).map { column in
                let grain = grains[column % grains.count]
                let value = (grain.base * scale(atTier: tier) * 1000).rounded() / 1000
                return LegacyNode(
                    id: "legacy.\(branch.rawValue).\(tier).\(column)",
                    branch: branch,
                    tier: tier,
                    name: "\(grain.title) \(numeral(tier))",
                    modifier: StatModifier(grain.stat, grain.kind, value),
                    cost: cost(atTier: tier)
                )
            }
        }
    }

    private static let byID: [String: LegacyNode] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func node(_ id: String) -> LegacyNode? { byID[id] }

    static func nodes(in branch: LegacyBranch) -> [LegacyNode] {
        all.filter { $0.branch == branch }
    }

    static func nodes(in branch: LegacyBranch, tier: Int) -> [LegacyNode] {
        all.filter { $0.branch == branch && $0.tier == tier }
    }

    private static func numeral(_ number: Int) -> String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
        return number >= 1 && number <= numerals.count ? numerals[number - 1] : "\(number)"
    }
}
