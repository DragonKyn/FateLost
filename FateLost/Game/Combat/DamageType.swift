import Foundation

/// Elemental/physical category of a hit. Resistances, skills and on-hit
/// reactions key off this, so every damage source must declare one.
enum DamageType: String, Codable, CaseIterable {
    case physical
    case fire
    case cold
    case lightning
    case arcane
    case holy
    case shadow
    case poison

    var displayName: String { rawValue.capitalized }
}

/// Descriptive tags carried by damage events and content definitions.
///
/// Skills react to tags ("your melee attacks…", "when a poisoned enemy
/// dies…") rather than to concrete classes, which keeps new content from
/// requiring changes to existing skills.
enum CombatTag: String, Codable, CaseIterable {
    case melee
    case projectile
    case spell
    case critical
    case area
    case summon
    case poison
    case burn
    case holy
    case weapon
    case twoHanded
    case ranged
    case magic
    case physical
}
