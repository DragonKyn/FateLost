import CoreGraphics
import Foundation

/// The eleven archetypes. None excludes another: a build is simply where
/// its skill points went.
enum ArchetypeID: String, CaseIterable, Codable, Identifiable {
    case warrior
    case rogue
    case ranger
    case wizard
    case sorcerer
    case warlock
    case cleric
    case paladin
    case druid
    case monk
    case bard

    var id: String { rawValue }
}

/// A subclass direction within an archetype (Knight, Assassin, Frostweaver…).
struct PathDefinition: Equatable, Identifiable {
    let id: PathID
    let name: String
    let summary: String
}

/// Presentation and passive identity of an archetype.
struct ArchetypeDefinition: Equatable, Identifiable {
    let id: ArchetypeID
    let name: String
    let tagline: String
    /// SF Symbol used as its sigil.
    let symbol: String
    let color: RGBA
    let paths: [PathDefinition]
    /// Granted for every point spent in the archetype, so no point is ever
    /// "filler": each one nudges you toward the archetype's identity.
    let resonance: [StatModifier]
    let resonanceText: String
}

/// A shapeshifted or transcendent form that replaces the weapon attack and
/// changes the player's stats: forms change how combat plays, not just the
/// numbers.
struct FormDefinition: Equatable, Identifiable {
    let id: FormID
    let name: String
    let weapon: WeaponDefinition
    /// Scaled by the rank of the skill granting the form.
    let modifiers: [ModifierSpec]
    let sprite: SpriteID
    let tint: RGBA?
    let scale: CGFloat
    /// Whether the player's own weapon is hidden in this form.
    let hidesWeapon: Bool
}
