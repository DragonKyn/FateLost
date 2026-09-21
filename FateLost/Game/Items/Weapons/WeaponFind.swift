import Foundation

/// One rolled property on a weapon found in a run.
///
/// An affix is a single stat modifier with a name on each side of the
/// weapon's: a Keen Katana, a Katana of Precision. It applies while the
/// weapon is in the hand and goes with it.
struct WeaponAffix: Equatable, Identifiable {
    let id: String
    let prefix: String
    let suffix: String
    /// How it reads on the card.
    let text: String
    let modifier: StatModifier
    /// Melee weapons only, ranged only, or nil for either.
    let melee: Bool?

    func fits(_ weapon: WeaponDefinition) -> Bool {
        guard let melee else { return true }
        if case .meleeArc = weapon.delivery { return melee }
        return !melee
    }
}

enum WeaponAffixCatalog {
    static let keen = WeaponAffix(id: "keen", prefix: "Keen", suffix: "of Precision",
                                  text: "+5% critical chance", modifier: StatModifier(.critChance, .flat, 0.05),
                                  melee: nil)
    static let swift = WeaponAffix(id: "swift", prefix: "Swift", suffix: "of Haste",
                                   text: "+10% attack speed", modifier: StatModifier(.attackSpeed, .increased, 0.1),
                                   melee: nil)
    static let heavy = WeaponAffix(id: "heavy", prefix: "Heavy", suffix: "of Might",
                                   text: "+12% damage", modifier: StatModifier(.damage, .increased, 0.12),
                                   melee: nil)
    static let vicious = WeaponAffix(id: "vicious", prefix: "Vicious", suffix: "of Cruelty",
                                     text: "+30% critical damage", modifier: StatModifier(.critDamage, .flat, 0.3),
                                     melee: nil)
    static let vampiric = WeaponAffix(id: "vampiric", prefix: "Vampiric", suffix: "of the Leech",
                                      text: "Heal for 1.2% of damage dealt",
                                      modifier: StatModifier(.lifeSteal, .flat, 0.012), melee: nil)
    static let flaming = WeaponAffix(id: "flaming", prefix: "Flaming", suffix: "of Embers",
                                     text: "+15% fire damage", modifier: StatModifier(.fireDamage, .increased, 0.15),
                                     melee: nil)
    static let frozen = WeaponAffix(id: "frozen", prefix: "Frozen", suffix: "of Frost",
                                    text: "+15% cold damage", modifier: StatModifier(.coldDamage, .increased, 0.15),
                                    melee: nil)
    static let charged = WeaponAffix(id: "charged", prefix: "Charged", suffix: "of Storms",
                                     text: "+15% lightning damage",
                                     modifier: StatModifier(.lightningDamage, .increased, 0.15), melee: nil)
    static let sturdy = WeaponAffix(id: "sturdy", prefix: "Sturdy", suffix: "of the Bulwark",
                                    text: "+8 armour", modifier: StatModifier(.armor, .flat, 8), melee: nil)
    static let fleet = WeaponAffix(id: "fleet", prefix: "Fleet", suffix: "of Wind",
                                   text: "+6% movement speed", modifier: StatModifier(.moveSpeed, .increased, 0.06),
                                   melee: nil)
    static let mending = WeaponAffix(id: "mending", prefix: "Mending", suffix: "of Mending",
                                     text: "+1.5 health per second",
                                     modifier: StatModifier(.healthRegen, .flat, 1.5), melee: nil)
    static let piercing = WeaponAffix(id: "piercing", prefix: "Piercing", suffix: "of Piercing",
                                      text: "Shots pass through 1 more enemy",
                                      modifier: StatModifier(.pierce, .flat, 1), melee: false)
    static let sweeping = WeaponAffix(id: "sweeping", prefix: "Sweeping", suffix: "of Sweeps",
                                      text: "+10% area size", modifier: StatModifier(.areaSize, .increased, 0.1),
                                      melee: true)
    static let thumping = WeaponAffix(id: "thumping", prefix: "Thumping", suffix: "of the Ram",
                                      text: "+25% knockback", modifier: StatModifier(.knockback, .increased, 0.25),
                                      melee: true)

    static let all: [WeaponAffix] = [
        keen, swift, heavy, vicious, vampiric, flaming, frozen, charged, sturdy, fleet, mending,
        piercing, sweeping, thumping,
    ]
}

/// A weapon found in a run: one from the rack, rolled with affixes.
///
/// Any weapon on the rack can turn up, including ones the player has never
/// bought — a find is how a run gets to try something it does not own. What
/// a find brings is the weapon and its affixes; it does not bring mastery,
/// which stays with the weapon the run was started with.
struct WeaponFind: Equatable {
    let weapon: WeaponID
    let rarity: ItemRarity
    let affixes: [WeaponAffix]
    /// Multiplies the weapon's base damage: a good roll hits harder.
    let damageScale: Double

    /// "Keen Katana", or "Keen Katana of Haste" with a second affix.
    var title: String {
        let name = StarterWeapons.definition(for: weapon)?.name ?? "Weapon"
        guard let first = affixes.first else { return name }
        var result = "\(first.prefix) \(name)"
        if affixes.count >= 2 {
            result += " \(affixes[1].suffix)"
        }
        return result
    }

    /// The base weapon with this roll's damage applied.
    var definition: WeaponDefinition? {
        guard let base = StarterWeapons.definition(for: weapon) else { return nil }
        return WeaponDefinition(
            id: base.id, name: title, summary: base.summary, baseDamage: base.baseDamage * damageScale,
            attackSpeed: base.attackSpeed, range: base.range, damageType: base.damageType, tags: base.tags,
            delivery: base.delivery, targeting: base.targeting, rarity: rarity, spriteID: base.spriteID
        )
    }

    /// What holding it does to the hero's stats.
    var modifiers: [StatModifier] { affixes.map(\.modifier) }
}

/// Rolls a find.
enum WeaponRoller {
    /// Chance a find of each tier carries a weapon among its cards.
    static func chance(of tier: LootTier) -> Double {
        switch tier {
        case .cache: return 0.10
        case .chest: return 0.30
        case .hoard: return 0.45
        case .rift: return 0.6
        }
    }

    /// Affixes carried at each rarity. Common finds do not exist.
    static func affixCount(for rarity: ItemRarity) -> Int {
        switch rarity {
        case .common: return 0
        case .uncommon: return 1
        case .rare, .epic: return 2
        case .legendary: return 3
        }
    }

    /// Rolls a weapon other than the one already in the hand, or nil if
    /// there is none to offer.
    static func roll(tier: LootTier, wielding: WeaponID?, random: inout SeededRandom) -> WeaponFind? {
        let candidates = StarterWeapons.all.filter { $0.id != wielding }
        guard !candidates.isEmpty else { return nil }
        let base = candidates[min(candidates.count - 1, Int(random.unit() * Double(candidates.count)))]

        let rarities: [(ItemRarity, Double)] = ItemRarity.allCases.compactMap { rarity in
            let weight = Double(tier.weight(of: rarity))
            return rarity == .common || weight <= 0 ? nil : (rarity, weight)
        }
        let total = rarities.reduce(0) { $0 + $1.1 }
        var roll = random.unit() * total
        var rarity = rarities.last?.0 ?? .uncommon
        for (candidate, weight) in rarities {
            roll -= weight
            if roll <= 0 {
                rarity = candidate
                break
            }
        }

        var pool = WeaponAffixCatalog.all.filter { $0.fits(base) }
        var affixes: [WeaponAffix] = []
        for _ in 0..<affixCount(for: rarity) where !pool.isEmpty {
            let index = min(pool.count - 1, Int(random.unit() * Double(pool.count)))
            affixes.append(pool.remove(at: index))
        }

        let scale = 1 + 0.05 * Double(rarity.rawValue) + random.range(-0.02, 0.04)
        return WeaponFind(weapon: base.id, rarity: rarity, affixes: affixes, damageScale: scale)
    }
}
