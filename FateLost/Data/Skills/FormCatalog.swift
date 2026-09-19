import CoreGraphics
import Foundation

/// Forms that replace the weapon attack: the druid's beasts and the monk's
/// empty hand. Each swaps in its own attack, so a form plays differently,
/// not just with bigger numbers.
enum FormCatalog {
    static let bear = FormDefinition(
        id: "form.bear",
        name: "Ursine Form",
        weapon: WeaponDefinition(
            id: "form.bear.maul", name: "Ursine Maul", summary: "Wide, crushing swipes.",
            baseDamage: 15, attackSpeed: 0.95, range: 1.9, damageType: .physical,
            tags: [.melee, .physical], delivery: .meleeArc(arcDegrees: 170), targeting: .nearest,
            rarity: .common, spriteID: .weaponSword
        ),
        modifiers: [
            ModifierSpec(.maxHealth, .more, RankValue(0.35, 0.05)),
            ModifierSpec(.armor, .flat, RankValue(20, 6)),
            ModifierSpec(.moveSpeed, .increased, RankValue(-0.12)),
            ModifierSpec(.knockback, .increased, RankValue(0.5)),
        ],
        sprite: .allyBear,
        tint: RGBA(hex: 0x8A6A4A),
        scale: 1.15,
        hidesWeapon: true
    )

    static let wolf = FormDefinition(
        id: "form.wolf",
        name: "Lupine Form",
        weapon: WeaponDefinition(
            id: "form.wolf.fangs", name: "Lupine Fangs", summary: "Fast, snapping bites.",
            baseDamage: 6.5, attackSpeed: 2.4, range: 1.5, damageType: .physical,
            tags: [.melee, .physical], delivery: .meleeArc(arcDegrees: 100), targeting: .nearest,
            rarity: .common, spriteID: .weaponSword
        ),
        modifiers: [
            ModifierSpec(.moveSpeed, .increased, RankValue(0.25, 0.04)),
            ModifierSpec(.critChance, .flat, RankValue(0.08, 0.02)),
            ModifierSpec(.dodgeChance, .flat, RankValue(0.05)),
        ],
        sprite: .allyWolf,
        tint: nil,
        scale: 1.1,
        hidesWeapon: true
    )

    static let ironFist = FormDefinition(
        id: "form.ironFist",
        name: "Iron Fist",
        weapon: WeaponDefinition(
            id: "form.ironFist.fists", name: "Iron Fists", summary: "A storm of blows.",
            baseDamage: 7.5, attackSpeed: 2.7, range: 1.45, damageType: .physical,
            tags: [.melee, .physical], delivery: .meleeArc(arcDegrees: 110), targeting: .nearest,
            rarity: .common, spriteID: .weaponSword
        ),
        modifiers: [
            ModifierSpec(.attackSpeed, .increased, RankValue(0.1)),
            ModifierSpec(.dodgeChance, .flat, RankValue(0.05)),
        ],
        sprite: .playerAdventurer,
        tint: nil,
        scale: 1,
        hidesWeapon: true
    )

    static let all: [FormDefinition] = [bear, wolf, ironFist]

    static func form(_ id: FormID) -> FormDefinition? {
        all.first { $0.id == id }
    }
}
