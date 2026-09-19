import CoreGraphics

/// Visual themes for each realm's arena.
///
/// The Ashen Wilds is fully dressed. Later realms currently share its set
/// dressing under their own palettes; each gains bespoke decorations and
/// hazards as its realm is built out.
enum ArenaThemes {
    /// Colours for one realm's ground, in the order `makeTheme` expects.
    struct GroundPalette {
        let bases: [(base: UInt32, detail: UInt32, pattern: GroundPattern)]
        let accent: (base: UInt32, detail: UInt32, pattern: GroundPattern)
        let road: (base: UInt32, detail: UInt32)
        let brokenRoad: (base: UInt32, detail: UInt32)
    }

    static let ashenWilds = makeTheme(
        palette: GroundPalette(
            bases: [
                (0x46432F, 0x5A5539, .speckled),
                (0x3F3C2B, 0x524C35, .patchy),
                (0x4C4631, 0x625A3D, .speckled),
            ],
            accent: (0x3A342F, 0x2A2522, .cracked),
            road: (0x57534C, 0x3F3B36),
            brokenRoad: (0x4A4540, 0x302C28)
        ),
        roads: RoadNetwork(alongX: 2, alongY: 2, width: 2.2, meanderAmplitude: 6,
                           meanderCycles: 2, brokenChance: 0.22),
        decorations: [
            .cluster(ClusterRule(name: "Graveyard", instances: 6, radius: 5.5, members: [
                ClusterMember(kind: .gravestone, count: 10, arrangement: .rows),
                ClusterMember(kind: .graveCross, count: 5, arrangement: .rows),
                ClusterMember(kind: .deadTreeSmall, count: 2, arrangement: .ring),
                ClusterMember(kind: .bones, count: 4, arrangement: .scattered),
            ])),
            .cluster(ClusterRule(name: "Ruin", instances: 7, radius: 4.5, members: [
                ClusterMember(kind: .ruinedPillar, count: 6, arrangement: .ring),
                ClusterMember(kind: .ruinedWall, count: 2, arrangement: .ring),
                ClusterMember(kind: .campfire, count: 1, arrangement: .center),
                ClusterMember(kind: .rock, count: 3, arrangement: .scattered),
            ])),
            .cluster(ClusterRule(name: "Wayside Shrine", instances: 4, radius: 3, members: [
                ClusterMember(kind: .oldShrine, count: 1, arrangement: .center),
                ClusterMember(kind: .rock, count: 5, arrangement: .ring),
            ])),
            .cluster(ClusterRule(name: "Abandoned Camp", instances: 6, radius: 3, members: [
                ClusterMember(kind: .brokenCart, count: 1, arrangement: .scattered),
                ClusterMember(kind: .campfire, count: 1, arrangement: .center),
                ClusterMember(kind: .bones, count: 2, arrangement: .scattered),
                ClusterMember(kind: .rock, count: 2, arrangement: .scattered),
            ])),
            .scatter(kind: .deadTree, count: 150, avoidRoads: true),
            .scatter(kind: .deadTreeSmall, count: 130, avoidRoads: true),
            .scatter(kind: .rock, count: 170, avoidRoads: true),
            .scatter(kind: .brokenCart, count: 8, avoidRoads: false),
            .scatter(kind: .bones, count: 70, avoidRoads: false),
            .scatter(kind: .grassTuft, count: 650, avoidRoads: true),
        ],
        atmosphere: Atmosphere(
            background: RGBA(hex: 0x121013),
            vignette: RGBA(hex: 0x000000, alpha: 0.78),
            particles: .ash,
            particleColor: RGBA(hex: 0xB9B2A6, alpha: 0.55),
            particleRate: 14
        )
    )

    static let drownedFen = makeTheme(
        palette: GroundPalette(
            bases: [(0x2E3A2C, 0x3C4A36, .patchy), (0x283326, 0x35432F, .speckled), (0x33402D, 0x42503A, .patchy)],
            accent: (0x1E2A2A, 0x2A3A3A, .smooth),
            road: (0x4A4A3C, 0x35352A),
            brokenRoad: (0x3A3A2E, 0x2A2A20)
        ),
        roads: RoadNetwork(alongX: 1, alongY: 1, width: 1.8, meanderAmplitude: 9,
                           meanderCycles: 3, brokenChance: 0.45),
        decorations: sharedDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x0D1210), vignette: RGBA(hex: 0x020806, alpha: 0.8),
                               particles: .spores, particleColor: RGBA(hex: 0x9CC48A, alpha: 0.45), particleRate: 10)
    )

    static let hollowForest = makeTheme(
        palette: GroundPalette(
            bases: [(0x2B2A1E, 0x3A3826, .speckled), (0x25241A, 0x333122, .patchy), (0x302E20, 0x403D2A, .speckled)],
            accent: (0x3A2A1E, 0x4A3526, .cracked),
            road: (0x4A4234, 0x352F25),
            brokenRoad: (0x3C352A, 0x2A251D)
        ),
        roads: RoadNetwork(alongX: 1, alongY: 2, width: 1.6, meanderAmplitude: 7,
                           meanderCycles: 2, brokenChance: 0.3),
        decorations: denseForestDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x0C0B08), vignette: RGBA(hex: 0x000000, alpha: 0.85),
                               particles: .motes, particleColor: RGBA(hex: 0xD8C27A, alpha: 0.4), particleRate: 8)
    )

    static let frozenWastes = makeTheme(
        palette: GroundPalette(
            bases: [(0xA9B4BE, 0xC3CCD4, .speckled), (0x9AA6B1, 0xB5C0CA, .patchy), (0xB2BCC5, 0xCCD4DB, .smooth)],
            accent: (0x7F95A8, 0x9FB3C4, .cracked),
            road: (0x6E6E72, 0x55555A),
            brokenRoad: (0x5E5E63, 0x48484C)
        ),
        roads: RoadNetwork(alongX: 2, alongY: 1, width: 2, meanderAmplitude: 5,
                           meanderCycles: 2, brokenChance: 0.35),
        decorations: sharedDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x1A1F26), vignette: RGBA(hex: 0x05080C, alpha: 0.7),
                               particles: .snow, particleColor: RGBA(hex: 0xF2F6FA, alpha: 0.8), particleRate: 30)
    )

    static let blightedKingdom = makeTheme(
        palette: GroundPalette(
            bases: [(0x3A3334, 0x4A4142, .speckled), (0x332D2E, 0x443B3C, .patchy), (0x3F3738, 0x514748, .speckled)],
            accent: (0x3B2E22, 0x4F3E2C, .cracked),
            road: (0x5C5657, 0x444040),
            brokenRoad: (0x4C4647, 0x353132)
        ),
        roads: RoadNetwork(alongX: 3, alongY: 3, width: 2.4, meanderAmplitude: 3,
                           meanderCycles: 1, brokenChance: 0.28),
        decorations: sharedDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x100D0E), vignette: RGBA(hex: 0x060203, alpha: 0.8),
                               particles: .ash, particleColor: RGBA(hex: 0x8F8A7A, alpha: 0.5), particleRate: 16)
    )

    static let burningDepths = makeTheme(
        palette: GroundPalette(
            bases: [(0x3A2320, 0x4E2E28, .cracked), (0x33201D, 0x472A24, .speckled), (0x402622, 0x55332B, .cracked)],
            accent: (0x5A2410, 0xA4461A, .cracked),
            road: (0x4A3A36, 0x352A27),
            brokenRoad: (0x3A2D2A, 0x2A201E)
        ),
        roads: RoadNetwork(alongX: 1, alongY: 1, width: 2, meanderAmplitude: 8,
                           meanderCycles: 2, brokenChance: 0.5),
        decorations: sharedDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x140806), vignette: RGBA(hex: 0x100200, alpha: 0.8),
                               particles: .embers, particleColor: RGBA(hex: 0xFF8A3A, alpha: 0.85), particleRate: 22)
    )

    static let shatteredRealm = makeTheme(
        palette: GroundPalette(
            bases: [(0x2A2638, 0x3A3450, .speckled), (0x241F33, 0x332C48, .patchy), (0x302A40, 0x423A58, .smooth)],
            accent: (0x3C2A5A, 0x6A4AA0, .cracked),
            road: (0x4A4658, 0x363244),
            brokenRoad: (0x3A3648, 0x282434)
        ),
        roads: RoadNetwork(alongX: 2, alongY: 2, width: 1.8, meanderAmplitude: 10,
                           meanderCycles: 3, brokenChance: 0.55),
        decorations: sharedDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x0B0914), vignette: RGBA(hex: 0x05020E, alpha: 0.82),
                               particles: .motes, particleColor: RGBA(hex: 0xB08CFF, alpha: 0.6), particleRate: 18)
    )

    static let fallenCitadel = makeTheme(
        palette: GroundPalette(
            bases: [(0x44403C, 0x55504A, .cobbled), (0x3C3834, 0x4C4742, .cobbled), (0x4A4541, 0x5C5650, .speckled)],
            accent: (0x3A2A26, 0x4E3530, .cracked),
            road: (0x625D57, 0x4A4641),
            brokenRoad: (0x514C47, 0x3A3632)
        ),
        roads: RoadNetwork(alongX: 3, alongY: 3, width: 3, meanderAmplitude: 1,
                           meanderCycles: 1, brokenChance: 0.3),
        decorations: sharedDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x0E0D0C), vignette: RGBA(hex: 0x000000, alpha: 0.8),
                               particles: .ash, particleColor: RGBA(hex: 0x9A948C, alpha: 0.5), particleRate: 12)
    )

    static let gateOfRuin = makeTheme(
        palette: GroundPalette(
            bases: [(0x2E2626, 0x3E3232, .cracked), (0x282121, 0x372C2C, .speckled), (0x332A2A, 0x453838, .cracked)],
            accent: (0x4A1A1A, 0x7A2A22, .cracked),
            road: (0x4E4646, 0x3A3434),
            brokenRoad: (0x3E3838, 0x2C2828)
        ),
        roads: RoadNetwork(alongX: 2, alongY: 2, width: 2.5, meanderAmplitude: 4,
                           meanderCycles: 1, brokenChance: 0.6),
        decorations: sharedDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x0D0606), vignette: RGBA(hex: 0x0A0000, alpha: 0.85),
                               particles: .embers, particleColor: RGBA(hex: 0xE0442A, alpha: 0.7), particleRate: 20)
    )

    static let abyss = makeTheme(
        palette: GroundPalette(
            bases: [(0x16141C, 0x221F2C, .speckled), (0x121018, 0x1C1A26, .smooth), (0x1A1722, 0x282432, .patchy)],
            accent: (0x2A0E22, 0x541C44, .cracked),
            road: (0x2A2632, 0x1E1B24),
            brokenRoad: (0x201D28, 0x16141C)
        ),
        roads: nil,
        decorations: sharedDecorations,
        atmosphere: Atmosphere(background: RGBA(hex: 0x050408), vignette: RGBA(hex: 0x000000, alpha: 0.9),
                               particles: .motes, particleColor: RGBA(hex: 0xD04AA0, alpha: 0.5), particleRate: 12)
    )

    // MARK: - Shared set dressing

    private static let sharedDecorations: [DecorationRule] = [
        .cluster(ClusterRule(name: "Ruin", instances: 8, radius: 4.5, members: [
            ClusterMember(kind: .ruinedPillar, count: 6, arrangement: .ring),
            ClusterMember(kind: .ruinedWall, count: 2, arrangement: .ring),
            ClusterMember(kind: .rock, count: 3, arrangement: .scattered),
        ])),
        .cluster(ClusterRule(name: "Shrine", instances: 4, radius: 3, members: [
            ClusterMember(kind: .oldShrine, count: 1, arrangement: .center),
            ClusterMember(kind: .rock, count: 5, arrangement: .ring),
        ])),
        .scatter(kind: .deadTree, count: 120, avoidRoads: true),
        .scatter(kind: .rock, count: 180, avoidRoads: true),
        .scatter(kind: .bones, count: 60, avoidRoads: false),
        .scatter(kind: .grassTuft, count: 400, avoidRoads: true),
    ]

    private static let denseForestDecorations: [DecorationRule] = [
        .scatter(kind: .deadTree, count: 420, avoidRoads: true),
        .scatter(kind: .deadTreeSmall, count: 300, avoidRoads: true),
        .scatter(kind: .rock, count: 120, avoidRoads: true),
        .scatter(kind: .grassTuft, count: 700, avoidRoads: true),
    ]

    // MARK: - Builder

    private static func makeTheme(
        palette: GroundPalette,
        roads: RoadNetwork?,
        decorations: [DecorationRule],
        atmosphere: Atmosphere,
        accentThreshold: Double = 0.68,
        spawnClearRadius: CGFloat = 4
    ) -> ArenaTheme {
        var styles = palette.bases.map {
            GroundTileStyle(base: RGBA(hex: $0.base), detail: RGBA(hex: $0.detail), pattern: $0.pattern)
        }
        let baseIndices = Array(styles.indices)

        let accentIndex = styles.count
        styles.append(GroundTileStyle(base: RGBA(hex: palette.accent.base),
                                      detail: RGBA(hex: palette.accent.detail),
                                      pattern: palette.accent.pattern))
        let roadIndex = styles.count
        styles.append(GroundTileStyle(base: RGBA(hex: palette.road.base),
                                      detail: RGBA(hex: palette.road.detail),
                                      pattern: .cobbled))
        let brokenRoadIndex = styles.count
        styles.append(GroundTileStyle(base: RGBA(hex: palette.brokenRoad.base),
                                      detail: RGBA(hex: palette.brokenRoad.detail),
                                      pattern: .cracked))

        return ArenaTheme(
            groundStyles: styles,
            baseStyleIndices: baseIndices,
            accentStyleIndex: accentIndex,
            accentThreshold: accentThreshold,
            roadStyleIndex: roads == nil ? nil : roadIndex,
            brokenRoadStyleIndex: roads == nil ? nil : brokenRoadIndex,
            roads: roads,
            decorations: decorations,
            spawnClearRadius: spawnClearRadius,
            atmosphere: atmosphere
        )
    }
}
