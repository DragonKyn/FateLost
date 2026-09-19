import Foundation

/// Stable, art-agnostic name for a visual.
///
/// Gameplay and content data refer to sprites only through these ids.
/// `SpriteCatalog` resolves an id to a texture: a bundled asset of the same
/// name when one exists, otherwise generated placeholder art. Swapping in
/// final artwork is therefore an asset-catalog change, never a code change.
struct SpriteID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

extension SpriteID {
    // Player
    static let playerAdventurer: SpriteID = "player.adventurer"
    static let shadow: SpriteID = "fx.shadow"

    // Weapons (held and icon)
    static let weaponSword: SpriteID = "weapon.sword"
    static let weaponBow: SpriteID = "weapon.bow"
    static let weaponStaff: SpriteID = "weapon.staff"

    // Projectiles
    static let projectileArrow: SpriteID = "projectile.arrow"
    static let projectileArcaneBolt: SpriteID = "projectile.arcaneBolt"

    // Decorations
    static let decorDeadTree: SpriteID = "decor.deadTree"
    static let decorDeadTreeSmall: SpriteID = "decor.deadTreeSmall"
    static let decorGravestone: SpriteID = "decor.gravestone"
    static let decorGraveCross: SpriteID = "decor.graveCross"
    static let decorRuinedPillar: SpriteID = "decor.ruinedPillar"
    static let decorRuinedWall: SpriteID = "decor.ruinedWall"
    static let decorBrokenCart: SpriteID = "decor.brokenCart"
    static let decorCampfire: SpriteID = "decor.campfire"
    static let decorOldShrine: SpriteID = "decor.oldShrine"
    static let decorRock: SpriteID = "decor.rock"
    static let decorGrassTuft: SpriteID = "decor.grassTuft"
    static let decorBones: SpriteID = "decor.bones"

    // Effects
    static let fxGlow: SpriteID = "fx.glow"
    static let fxFlame: SpriteID = "fx.flame"
    static let fxAshFlake: SpriteID = "fx.ashFlake"
    static let fxVignette: SpriteID = "fx.vignette"
}
