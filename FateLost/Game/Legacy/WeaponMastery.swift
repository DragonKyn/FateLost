import Foundation

/// The Armoury: which starters can be bought, what mastering one costs, and
/// what mastery is worth.
///
/// Mastery follows the same rule as the rest of Legacy — small, uniform,
/// never the reason a run was won. Five ranks, each worth a few per cent, and
/// the bonuses only apply to runs actually started with that weapon. What
/// changes between weapons is the third bonus, the *affinity*, which leans
/// into whatever the weapon already does: the hammer throws them further, the
/// daggers find more openings, the wands burn hotter.
enum WeaponMastery {
    static let maxRank = 5

    /// Echoes to add a weapon to the rack.
    static func unlockCost(_ weapon: WeaponDefinition) -> Int {
        switch weapon.rarity {
        case .common: return 0
        case .uncommon: return 288
        case .rare: return 504
        case .epic: return 840
        case .legendary: return 1_320
        }
    }

    /// Echoes for the `rank`th rank of mastery, counting from one.
    static func rankCost(_ rank: Int) -> Int {
        max(1, rank) * 72 + 72
    }

    /// Everything mastery costs from nothing to fully mastered.
    static func totalCost(_ weapon: WeaponDefinition) -> Int {
        (1...maxRank).reduce(unlockCost(weapon)) { $0 + rankCost($1) }
    }

    // MARK: Bonuses

    /// The stat a weapon's mastery leans into, and how much of it per rank.
    static func affinity(of weapon: WeaponDefinition) -> StatModifier {
        switch weapon.id {
        case StarterWeapons.sword.id: return StatModifier(.critChance, .flat, 0.01)
        case StarterWeapons.bow.id: return StatModifier(.projectileSpeed, .increased, 0.04)
        case StarterWeapons.staff.id: return StatModifier(.areaSize, .increased, 0.04)
        case StarterWeapons.sai.id: return StatModifier(.attackSpeed, .increased, 0.02)
        case StarterWeapons.katana.id: return StatModifier(.critDamage, .flat, 0.06)
        case StarterWeapons.dualDaggers.id: return StatModifier(.critChance, .flat, 0.015)
        case StarterWeapons.boStaff.id: return StatModifier(.knockback, .increased, 0.06)
        case StarterWeapons.flail.id: return StatModifier(.areaSize, .increased, 0.04)
        case StarterWeapons.warHammer.id: return StatModifier(.knockback, .increased, 0.08)
        case StarterWeapons.claymore.id: return StatModifier(.meleeDamage, .increased, 0.03)
        case StarterWeapons.boomerang.id: return StatModifier(.projectileDamage, .increased, 0.04)
        case StarterWeapons.emberWand.id: return StatModifier(.fireDamage, .increased, 0.04)
        case StarterWeapons.rimeWand.id: return StatModifier(.coldDamage, .increased, 0.04)
        case StarterWeapons.stormWand.id: return StatModifier(.lightningDamage, .increased, 0.04)
        case StarterWeapons.spear.id: return StatModifier(.knockback, .increased, 0.06)
        case StarterWeapons.lance.id: return StatModifier(.knockback, .increased, 0.08)
        case StarterWeapons.halberd.id: return StatModifier(.areaSize, .increased, 0.05)
        case StarterWeapons.scythe.id: return StatModifier(.lifeSteal, .flat, 0.006)
        case StarterWeapons.heavyAxe.id: return StatModifier(.critDamage, .flat, 0.08)
        case StarterWeapons.whip.id: return StatModifier(.effectDuration, .increased, 0.05)
        case StarterWeapons.nunchaku.id: return StatModifier(.attackSpeed, .increased, 0.03)
        case StarterWeapons.handClaws.id: return StatModifier(.critChance, .flat, 0.015)
        case StarterWeapons.crossbow.id: return StatModifier(.projectileDamage, .increased, 0.04)
        case StarterWeapons.shuriken.id: return StatModifier(.critChance, .flat, 0.02)
        default: return StatModifier(.damage, .increased, 0.02)
        }
    }

    /// What `rank` ranks of mastery are worth on a run using this weapon.
    static func modifiers(for weapon: WeaponDefinition, rank: Int) -> [StatModifier] {
        let ranks = min(max(rank, 0), maxRank)
        guard ranks > 0 else { return [] }
        let step = Double(ranks)
        let lean = affinity(of: weapon)
        return [
            StatModifier(.damage, .increased, 0.04 * step),
            StatModifier(.attackSpeed, .increased, 0.02 * step),
            StatModifier(lean.stat, lean.kind, lean.value * step),
        ]
    }

    /// How one rank reads on the card.
    static func rankText(for weapon: WeaponDefinition) -> String {
        let lean = affinity(of: weapon)
        return "+4% damage, +2% attack speed, \(lean.displayText) per rank"
    }
}
