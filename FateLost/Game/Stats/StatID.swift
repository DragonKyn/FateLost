import Foundation

/// Every character statistic the game tracks.
///
/// Stats are indexed by `rawValue`, so a `StatSheet` can hold them in flat
/// arrays. Damage stats (`damage`, the damage types and the attack-kind
/// bonuses) are multipliers that combine additively when a hit is resolved;
/// see `StatSheet.damageMultiplier(for:tags:)`.
enum StatID: Int, CaseIterable, Codable {
    case maxHealth
    case healthRegen
    case armor
    case dodgeChance
    case moveSpeed
    case pickupRadius

    // Damage bonuses, all multipliers starting at 1.
    case damage
    case physicalDamage
    /// Applies to every non-physical damage type.
    case magicDamage
    case fireDamage
    case coldDamage
    case lightningDamage
    case arcaneDamage
    case holyDamage
    case shadowDamage
    case poisonDamage
    case meleeDamage
    case projectileDamage
    case spellDamage
    case areaDamage
    case summonDamage
    case dotDamage

    case attackSpeed
    /// Added to the base critical chance in `CombatTuning`.
    case critChance
    /// Added to the base critical multiplier in `CombatTuning`.
    case critDamage
    /// Fraction removed from ability cooldowns.
    case cooldownReduction

    case projectileSpeed
    /// Extra projectiles on attacks and volleys.
    case projectileCount
    /// Extra enemies projectiles pass through.
    case pierce
    /// Extra jumps on chaining effects.
    case chainJumps
    case areaSize
    case effectDuration

    case lifeSteal
    case healingReceived
    case knockback
    case experienceGain
    /// Multiplier on the chance to inflict statuses.
    case statusChance
    /// Extra minions each summon creates.
    case summonCount
    /// Fraction of summon damage returned to you as health.
    case summonLifeSteal
    /// Chance an ability is cast a second time for free.
    case spellEcho
    /// Fraction of healing beyond full health kept as a barrier.
    case overhealBarrier

    /// Starting value before any modifier.
    var baseValue: Double {
        switch self {
        case .maxHealth: return 100
        case .pickupRadius: return 1.7
        case .moveSpeed, .attackSpeed, .projectileSpeed, .areaSize, .effectDuration, .healingReceived,
             .knockback, .experienceGain, .statusChance:
            return 1
        case .damage, .physicalDamage, .magicDamage, .fireDamage, .coldDamage, .lightningDamage, .arcaneDamage,
             .holyDamage, .shadowDamage, .poisonDamage, .meleeDamage, .projectileDamage, .spellDamage,
             .areaDamage, .summonDamage, .dotDamage:
            return 1
        default:
            return 0
        }
    }

    /// Hard bounds on the final value. Caps keep stacked utility from
    /// breaking the game (no permanent dodge, no zero cooldowns), which in
    /// turn keeps any single stat from being the one "correct" pick.
    var bounds: ClosedRange<Double> {
        switch self {
        case .maxHealth: return 1...100_000
        case .dodgeChance: return 0...0.6
        case .cooldownReduction: return 0...0.5
        case .critChance: return 0...1
        case .lifeSteal: return 0...0.25
        case .summonLifeSteal: return 0...0.25
        case .spellEcho: return 0...0.5
        case .moveSpeed: return 0.3...3
        case .attackSpeed: return 0.25...6
        case .areaSize: return 0.3...4
        case .pickupRadius: return 0.5...12
        case .healthRegen: return -50...500
        default: return 0...100_000
        }
    }

    /// Stats that are a share of one (a chance, a fraction removed), which
    /// read as percentages whether they are added flat or increased: a flat
    /// 0.003 of cooldown reduction is 0.3%, not "0".
    var isFraction: Bool {
        switch self {
        case .dodgeChance, .critChance, .critDamage, .cooldownReduction, .lifeSteal, .summonLifeSteal,
             .spellEcho, .overhealBarrier:
            return true
        default:
            return false
        }
    }

    /// Stats the game reads as whole numbers: a fraction of one does nothing
    /// until enough of them have been added together, so no single upgrade
    /// may add a fraction of one to these.
    var isWholeNumber: Bool {
        switch self {
        case .projectileCount, .pierce, .chainJumps, .summonCount:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .maxHealth: return "Max Health"
        case .healthRegen: return "Health Regeneration"
        case .armor: return "Armour"
        case .dodgeChance: return "Dodge Chance"
        case .moveSpeed: return "Movement Speed"
        case .pickupRadius: return "Pickup Radius"
        case .damage: return "Damage"
        case .physicalDamage: return "Physical Damage"
        case .magicDamage: return "Magic Damage"
        case .fireDamage: return "Fire Damage"
        case .coldDamage: return "Cold Damage"
        case .lightningDamage: return "Lightning Damage"
        case .arcaneDamage: return "Arcane Damage"
        case .holyDamage: return "Holy Damage"
        case .shadowDamage: return "Shadow Damage"
        case .poisonDamage: return "Poison Damage"
        case .meleeDamage: return "Melee Damage"
        case .projectileDamage: return "Projectile Damage"
        case .spellDamage: return "Spell Damage"
        case .areaDamage: return "Area Damage"
        case .summonDamage: return "Summon Damage"
        case .dotDamage: return "Damage over Time"
        case .attackSpeed: return "Attack Speed"
        case .critChance: return "Critical Chance"
        case .critDamage: return "Critical Damage"
        case .cooldownReduction: return "Cooldown Reduction"
        case .projectileSpeed: return "Projectile Speed"
        case .projectileCount: return "Extra Projectiles"
        case .pierce: return "Pierce"
        case .chainJumps: return "Chain Jumps"
        case .areaSize: return "Area Size"
        case .effectDuration: return "Effect Duration"
        case .lifeSteal: return "Life Steal"
        case .healingReceived: return "Healing Received"
        case .knockback: return "Knockback"
        case .experienceGain: return "Experience Gain"
        case .statusChance: return "Status Chance"
        case .summonCount: return "Extra Summons"
        case .summonLifeSteal: return "Summon Life Steal"
        case .spellEcho: return "Spell Echo"
        case .overhealBarrier: return "Overheal to Barrier"
        }
    }
}

/// How a modifier combines with others on the same stat.
enum ModifierKind: String, Codable {
    /// Added to the base value.
    case flat
    /// Summed with other increases, then applied once: +10% and +20% make +30%.
    case increased
    /// Applied on its own: 10% more and 20% more make 32% more.
    case more
}

/// One change to one stat. Skills, items, shrines, buffs, forms and Legacy
/// upgrades all speak in these.
struct StatModifier: Equatable, Codable {
    var stat: StatID
    var kind: ModifierKind
    var value: Double

    init(_ stat: StatID, _ kind: ModifierKind, _ value: Double) {
        self.stat = stat
        self.kind = kind
        self.value = value
    }

    func scaled(by factor: Double) -> StatModifier {
        StatModifier(stat, kind, value * factor)
    }

    /// How the bonus reads to a player, in the units the stat is really in.
    /// Percentages and flat amounts alike keep enough precision that a small
    /// but real bonus never rounds away to nothing.
    var displayText: String {
        let name = stat.displayName
        if kind != .flat || stat.isFraction {
            return "+\(Self.number(value * 100))% \(name)"
        }
        let perSecond = stat == .healthRegen ? " per second" : ""
        return "+\(Self.number(value)) \(name)\(perSecond)"
    }

    /// A number with just the decimals it needs: 12, 4.98, 0.3, 0.027.
    static func number(_ value: Double) -> String {
        let size = abs(value)
        guard size > 0 else { return "0" }
        let decimals = size < 0.1 ? 3 : 2
        var text = String(format: "%.\(decimals)f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        // A value too small even for that keeps two significant figures.
        if text == "0" || text == "-0" { return String(format: "%.2g", value) }
        return text
    }
}
