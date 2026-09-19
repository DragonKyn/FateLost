import CoreGraphics

/// Surface texture drawn on a ground tile.
enum GroundPattern: String, Codable {
    case speckled
    case patchy
    case cracked
    case cobbled
    case smooth
}

struct GroundTileStyle: Equatable {
    let base: RGBA
    let detail: RGBA
    let pattern: GroundPattern
}

/// Meandering roads that wrap cleanly around the arena.
struct RoadNetwork: Equatable {
    /// Roads running along world x (east–west).
    let alongX: Int
    /// Roads running along world y (north–south).
    let alongY: Int
    /// Road width in tiles.
    let width: Double
    /// Peak sideways drift, in tiles.
    let meanderAmplitude: Double
    /// Full sine cycles per arena length. Must be a whole number so the road
    /// meets itself exactly at the seam.
    let meanderCycles: Int
    /// Fraction of road tiles drawn as broken paving.
    let brokenChance: Double
}

/// How members of a cluster are arranged around its centre.
enum ClusterArrangement: String, Codable {
    case ring
    case rows
    case scattered
    case center
}

struct ClusterMember: Equatable {
    let kind: DecorationKind
    let count: Int
    let arrangement: ClusterArrangement
}

/// A themed landmark (graveyard, ruin, camp) stamped several times per arena.
/// Landmarks give the player places to navigate toward and remember.
struct ClusterRule: Equatable {
    let name: String
    let instances: Int
    /// World-unit radius of the landmark.
    let radius: CGFloat
    let members: [ClusterMember]
}

enum DecorationRule: Equatable {
    case cluster(ClusterRule)
    case scatter(kind: DecorationKind, count: Int, avoidRoads: Bool)
}

enum AmbientParticles: String, Codable {
    case none
    case ash
    case embers
    case spores
    case snow
    case motes
}

struct Atmosphere: Equatable {
    /// Clear colour beyond the ground (only visible during loading).
    let background: RGBA
    /// Screen-edge darkening.
    let vignette: RGBA
    let particles: AmbientParticles
    let particleColor: RGBA
    /// Particles emitted per second across the visible area.
    let particleRate: CGFloat
}

/// Everything that makes a realm's arena look the way it does.
struct ArenaTheme: Equatable {
    /// Palette of ground tile styles. Other fields index into this.
    let groundStyles: [GroundTileStyle]
    /// Styles blended by low-frequency noise to form the base terrain.
    let baseStyleIndices: [Int]
    /// Style for scattered patches (bare earth, ice, blood-soaked soil…).
    let accentStyleIndex: Int?
    /// Noise level above which the accent style replaces the base, 0…1.
    let accentThreshold: Double
    let roadStyleIndex: Int?
    let brokenRoadStyleIndex: Int?
    let roads: RoadNetwork?
    /// Applied in order; landmarks should come before free scatter.
    let decorations: [DecorationRule]
    /// World-unit radius around the player spawn kept free of decorations.
    let spawnClearRadius: CGFloat
    let atmosphere: Atmosphere
}

/// Size and look of a realm's arena.
struct ArenaDefinition: Equatable {
    /// Width in tiles. Must comfortably exceed twice the visible area so the
    /// player never sees the same object twice at once.
    let columns: Int
    let rows: Int
    let theme: ArenaTheme

    var world: ToroidalWorld {
        ToroidalWorld(width: CGFloat(columns), height: CGFloat(rows))
    }
}
