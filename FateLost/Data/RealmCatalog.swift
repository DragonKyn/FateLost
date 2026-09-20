import CoreGraphics

/// The campaign. Every realm-specific number lives here.
enum RealmCatalog {
    /// Arena dimensions in tiles. Large enough that the visible area is a
    /// small fraction of the map, so wrapping is felt but never seen.
    private static let standardArenaSize = 128

    static let all: [RealmDefinition] = [
        RealmDefinition(
            id: .ashenWilds, order: 1, name: "The Ashen Wilds",
            tagline: "Where every fate is first lost.",
            introduces: ["The core of survival"],
            conquestWave: 10, legacyMultiplier: 0.50,
            arena: arena(ArenaThemes.ashenWilds),
            waves: WavePlan(waveSeconds: 50, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .ashenWilds))
        ),
        RealmDefinition(
            id: .drownedFen, order: 2, name: "The Drowned Fen",
            tagline: "The marsh remembers the dead it swallowed.",
            introduces: ["Poison", "Slowing terrain", "Swamp undead"],
            conquestWave: 15, legacyMultiplier: 0.70,
            arena: arena(ArenaThemes.drownedFen),
            waves: WavePlan(waveSeconds: 48, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .drownedFen))
        ),
        RealmDefinition(
            id: .hollowForest, order: 3, name: "The Hollow Forest",
            tagline: "Something watches from between the trunks.",
            introduces: ["Ranged enemies", "Ambushes", "Corrupted beasts"],
            conquestWave: 15, legacyMultiplier: 0.90,
            arena: arena(ArenaThemes.hollowForest),
            waves: WavePlan(waveSeconds: 46, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .hollowForest))
        ),
        RealmDefinition(
            id: .frozenWastes, order: 4, name: "The Frozen Wastes",
            tagline: "Cold enough to stop a heart mid-beat.",
            introduces: ["Freezing", "Movement slows", "Durable foes"],
            conquestWave: 20, legacyMultiplier: 1.15,
            arena: arena(ArenaThemes.frozenWastes),
            waves: WavePlan(waveSeconds: 45, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .frozenWastes))
        ),
        RealmDefinition(
            id: .blightedKingdom, order: 5, name: "The Blighted Kingdom",
            tagline: "Its king still rules. He simply stopped breathing.",
            introduces: ["Necromancers", "Resurrection", "Enemy support"],
            conquestWave: 20, legacyMultiplier: 1.45,
            arena: arena(ArenaThemes.blightedKingdom),
            waves: WavePlan(waveSeconds: 44, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .blightedKingdom))
        ),
        RealmDefinition(
            id: .burningDepths, order: 6, name: "The Burning Depths",
            tagline: "The ground itself wants you dead.",
            introduces: ["Demons", "Fire hazards", "Summoners"],
            conquestWave: 25, legacyMultiplier: 1.80,
            arena: arena(ArenaThemes.burningDepths),
            waves: WavePlan(waveSeconds: 43, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .burningDepths))
        ),
        RealmDefinition(
            id: .shatteredRealm, order: 7, name: "The Shattered Realm",
            tagline: "Reality broke here, and never healed.",
            introduces: ["Teleporters", "Anomalies", "Mixed factions"],
            conquestWave: 25, legacyMultiplier: 2.20,
            arena: arena(ArenaThemes.shatteredRealm),
            waves: WavePlan(waveSeconds: 42, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .shatteredRealm))
        ),
        RealmDefinition(
            id: .fallenCitadel, order: 8, name: "The Fallen Citadel",
            tagline: "Its knights swore to hold the walls forever.",
            introduces: ["Armoured foes", "Corrupted knights", "Siege attacks"],
            conquestWave: 30, legacyMultiplier: 2.65,
            arena: arena(ArenaThemes.fallenCitadel),
            waves: WavePlan(waveSeconds: 41, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .fallenCitadel))
        ),
        RealmDefinition(
            id: .gateOfRuin, order: 9, name: "The Gate of Ruin",
            tagline: "Everything you have faced, waiting at once.",
            introduces: ["The culmination of the campaign"],
            conquestWave: 30, legacyMultiplier: 3.15,
            arena: arena(ArenaThemes.gateOfRuin),
            waves: WavePlan(waveSeconds: 40, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .gateOfRuin))
        ),
        RealmDefinition(
            id: .abyss, order: 10, name: "The Abyss",
            tagline: "How far can you survive?",
            introduces: ["No end", "Abyssal corruption"],
            conquestWave: nil, legacyMultiplier: 3.75,
            arena: arena(ArenaThemes.abyss),
            waves: WavePlan(waveSeconds: 40, bossEvery: 5,
                            bosses: EnemyCatalog.bosses(for: .abyss))
        ),
    ]

    static func realm(_ id: RealmID) -> RealmDefinition {
        guard let realm = all.first(where: { $0.id == id }) else {
            preconditionFailure("Realm \(id) missing from catalog")
        }
        return realm
    }

    private static func arena(_ theme: ArenaTheme) -> ArenaDefinition {
        ArenaDefinition(columns: standardArenaSize, rows: standardArenaSize, theme: theme)
    }
}
