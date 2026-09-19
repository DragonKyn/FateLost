import Foundation

enum RealmID: String, Codable, CaseIterable {
    case ashenWilds
    case drownedFen
    case hollowForest
    case frozenWastes
    case blightedKingdom
    case burningDepths
    case shatteredRealm
    case fallenCitadel
    case gateOfRuin
    case abyss
}

/// Static definition of a realm.
///
/// Spawn tables, milestone encounters, bosses and hazards will be added as
/// further fields here in Phases 2 and 5, keeping every realm fully described
/// by configuration.
struct RealmDefinition: Identifiable, Equatable {
    let id: RealmID
    /// 1-based position in the campaign.
    let order: Int
    let name: String
    let tagline: String
    /// Mechanics this realm introduces, shown on the selection screen.
    let introduces: [String]
    /// Wave whose boss conquers the realm. `nil` means endless.
    let conquestWave: Int?
    let legacyMultiplier: Double
    let arena: ArenaDefinition

    var isEndless: Bool { conquestWave == nil }
}
