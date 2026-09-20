import Foundation

/// Turns a find into a choice of relics.
///
/// Pure and seeded: give it the same random stream and inventory and it deals
/// the same three cards, which is what lets a test look at an offer without
/// running a fight.
enum RelicRoller {
    static let choiceCount = 3
    /// Rerolls each offer starts with.
    static let rerolls = 1

    /// Deals a fresh offer.
    static func offer(tier: LootTier, wave: Int, inventory: RelicInventory, wielding: WeaponID? = nil,
                      random: inout SeededRandom) -> RelicOffer {
        var offer = RelicOffer(tier: tier, wave: wave,
                               choices: deal(tier: tier, wave: wave, inventory: inventory, random: &random),
                               rerollsLeft: rerolls, weapon: nil, wielding: wielding)
        offer.weapon = weaponCard(tier: tier, wielding: wielding, random: &random)
        return offer
    }

    /// Now and then a find holds a weapon among its cards.
    private static func weaponCard(tier: LootTier, wielding: WeaponID?, random: inout SeededRandom) -> WeaponFind? {
        guard random.chance(WeaponRoller.chance(of: tier)) else { return nil }
        return WeaponRoller.roll(tier: tier, wielding: wielding, random: &random)
    }

    /// Throws the cards back and deals again. Spends one reroll.
    ///
    /// - Returns: false, changing nothing, if none are left.
    @discardableResult
    static func reroll(_ offer: inout RelicOffer, inventory: RelicInventory, random: inout SeededRandom) -> Bool {
        guard offer.rerollsLeft > 0 else { return false }
        offer.rerollsLeft -= 1
        offer.choices = deal(tier: offer.tier, wave: offer.wave, inventory: inventory, random: &random)
        offer.weapon = weaponCard(tier: offer.tier, wielding: offer.wielding, random: &random)
        return true
    }

    // MARK: Dealing

    /// Chance a relic arrives already at rank two, or three.
    ///
    /// Rank two is how a run finds the same relic "fine" or "exquisite": the
    /// power roll. It grows with the wave, and rank three stays out of reach
    /// until a run is well along.
    static func rankChances(atWave wave: Int) -> (second: Double, third: Double) {
        let second = min(0.30, 0.06 + 0.012 * Double(max(0, wave - 1)))
        let third = wave >= 10 ? min(0.08, 0.01 * Double(wave - 8)) : 0
        return (second, third)
    }

    private static func deal(tier: LootTier, wave: Int, inventory: RelicInventory,
                             random: inout SeededRandom) -> [RelicChoice] {
        var chosen: [RelicChoice] = []
        var taken = Set<RelicID>()
        while chosen.count < choiceCount {
            guard let relic = pick(tier: tier, inventory: inventory, excluding: taken, random: &random) else {
                break
            }
            taken.insert(relic.id)
            chosen.append(RelicChoice(relic: relic.id, rank: rolledRank(for: relic, wave: wave, random: &random)))
        }
        return chosen
    }

    /// One relic: a rarity by the tier's weights, then a relic of that rarity.
    private static func pick(tier: LootTier, inventory: RelicInventory, excluding taken: Set<RelicID>,
                             random: inout SeededRandom) -> RelicDefinition? {
        // Only relics that can still do something for the run.
        let pool = RelicCatalog.all.filter { !taken.contains($0.id) && inventory.canImprove($0) }
        guard !pool.isEmpty else { return nil }

        var byRarity: [ItemRarity: [RelicDefinition]] = [:]
        for relic in pool {
            byRarity[relic.rarity, default: []].append(relic)
        }

        // Rarities the pool can actually supply, weighted by the tier.
        var rarities: [(ItemRarity, Double)] = []
        for rarity in ItemRarity.allCases where byRarity[rarity] != nil {
            let weight = Double(tier.weight(of: rarity))
            if weight > 0 { rarities.append((rarity, weight)) }
        }
        // A tier that has run out of what it likes falls back to anything.
        if rarities.isEmpty {
            rarities = ItemRarity.allCases.compactMap { rarity in
                byRarity[rarity] == nil ? nil : (rarity, 1)
            }
        }
        guard let rarity = weighted(rarities, random: &random), let candidates = byRarity[rarity] else {
            return nil
        }

        // Something new is better news than a second copy, so a relic
        // already carried turns up half as often.
        let weights = candidates.map { (relic: RelicDefinition) -> (RelicDefinition, Double) in
            (relic, inventory.contains(relic.id) ? 0.5 : 1)
        }
        return weighted(weights, random: &random)
    }

    private static func rolledRank(for relic: RelicDefinition, wave: Int, random: inout SeededRandom) -> Int {
        let chances = rankChances(atWave: wave)
        var rank = 1
        if relic.maxRank >= 3, random.chance(chances.third) {
            rank = 3
        } else if relic.maxRank >= 2, random.chance(chances.second) {
            rank = 2
        }
        return rank
    }

    private static func weighted<T>(_ items: [(T, Double)], random: inout SeededRandom) -> T? {
        let total = items.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return items.first?.0 }
        var roll = random.unit() * total
        for (item, weight) in items {
            roll -= weight
            if roll <= 0 { return item }
        }
        return items.last?.0
    }
}
