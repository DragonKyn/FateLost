import CoreGraphics
import Foundation

/// Builds an `ArenaLayout` from an `ArenaDefinition` and a seed.
///
/// Every source of variation — terrain noise, road meanders, landmark
/// placement — is periodic over the arena, so the generated world has no seam
/// at its wrapping edges.
struct ArenaGenerator {
    struct Tuning {
        /// Approximate size, in tiles, of base-terrain noise blobs.
        var terrainNoiseCellSize: Double = 9
        /// Approximate size, in tiles, of accent-patch noise blobs.
        var accentNoiseCellSize: Double = 6
        /// Placement attempts per requested decoration before giving up.
        var attemptsPerDecoration: Int = 12
        /// Minimum spacing between landmark centres, in tiles.
        var landmarkSpacing: CGFloat = 14
        /// Spatial grid cell size used for overlap checks, in tiles.
        var occupancyCellSize: CGFloat = 4
    }

    let definition: ArenaDefinition
    let seed: UInt64
    var tuning = Tuning()

    init(definition: ArenaDefinition, seed: UInt64) {
        self.definition = definition
        self.seed = seed
    }

    func generate() -> ArenaLayout {
        let world = definition.world
        let theme = definition.theme
        let columns = definition.columns
        let rows = definition.rows

        let roadMask = makeRoadMask(theme: theme, columns: columns, rows: rows)
        let ground = makeGround(theme: theme, columns: columns, rows: rows, roadMask: roadMask)
        let spawn = world.center

        var placer = DecorationPlacer(
            world: world,
            roadMask: roadMask,
            columns: columns,
            spawn: spawn,
            spawnClearRadius: theme.spawnClearRadius,
            cellSize: tuning.occupancyCellSize
        )
        var random = SeededRandom(seed: seed ^ 0xDEC0_DEC0)

        for rule in theme.decorations {
            switch rule {
            case .cluster(let cluster):
                placeLandmarks(cluster, placer: &placer, random: &random)
            case .scatter(let kind, let count, let avoidRoads):
                for _ in 0..<count {
                    for _ in 0..<tuning.attemptsPerDecoration {
                        let position = CGPoint(x: random.range(0, Double(world.width)),
                                               y: random.range(0, Double(world.height)))
                        if placer.place(kind, at: position, avoidRoads: avoidRoads, random: &random) {
                            break
                        }
                    }
                }
            }
        }

        return ArenaLayout(
            world: world,
            columns: columns,
            rows: rows,
            groundStyles: ground,
            roadMask: roadMask,
            decorations: placer.placements,
            playerSpawn: spawn
        )
    }

    // MARK: - Ground

    private func makeGround(theme: ArenaTheme, columns: Int, rows: Int, roadMask: [Bool]) -> [UInt8] {
        let terrain = PeriodicValueNoise(seed: seed, width: Double(columns), height: Double(rows),
                                         approximateCellSize: tuning.terrainNoiseCellSize)
        let accent = PeriodicValueNoise(seed: seed ^ 0xACCE_27, width: Double(columns), height: Double(rows),
                                        approximateCellSize: tuning.accentNoiseCellSize)
        let bases = theme.baseStyleIndices
        precondition(!bases.isEmpty, "A theme needs at least one base ground style")

        var styles = [UInt8](repeating: 0, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                let x = Double(column) + 0.5
                let y = Double(row) + 0.5

                if roadMask[index], let road = theme.roadStyleIndex {
                    let broken = CoordinateHash.unit(column, row, seed: seed ^ 0xB20C) < (theme.roads?.brokenChance ?? 0)
                    styles[index] = UInt8(broken ? (theme.brokenRoadStyleIndex ?? road) : road)
                    continue
                }

                if let accentStyle = theme.accentStyleIndex,
                   accent.sample(x: x, y: y) > theme.accentThreshold {
                    styles[index] = UInt8(accentStyle)
                    continue
                }

                // Per-tile jitter breaks up the blobs' smooth edges.
                let jitter = (CoordinateHash.unit(column, row, seed: seed) - 0.5) * 0.25
                let n = (terrain.sample(x: x, y: y) + jitter).clamped(0, 0.9999)
                styles[index] = UInt8(bases[Int(n * Double(bases.count))])
            }
        }
        return styles
    }

    // MARK: - Roads

    private func makeRoadMask(theme: ArenaTheme, columns: Int, rows: Int) -> [Bool] {
        var mask = [Bool](repeating: false, count: columns * rows)
        guard let roads = theme.roads else { return mask }
        var random = SeededRandom(seed: seed ^ 0x20AD)
        let halfWidth = roads.width / 2

        // Roads along x: for each column, the road centre drifts in y on a
        // sine whose period divides the arena width, so it closes on itself.
        for roadIndex in 0..<roads.alongX {
            let baseline = (Double(roadIndex) + 0.5) * Double(rows) / Double(roads.alongX) + random.range(-3, 3)
            let phase = random.range(0, 2 * .pi)
            for column in 0..<columns {
                let t = Double(column) + 0.5
                let center = baseline + roads.meanderAmplitude
                    * sin(2 * .pi * Double(roads.meanderCycles) * t / Double(columns) + phase)
                markBand(center: center, halfWidth: halfWidth, length: rows) { row in
                    mask[row * columns + column] = true
                }
            }
        }

        for roadIndex in 0..<roads.alongY {
            let baseline = (Double(roadIndex) + 0.5) * Double(columns) / Double(roads.alongY) + random.range(-3, 3)
            let phase = random.range(0, 2 * .pi)
            for row in 0..<rows {
                let t = Double(row) + 0.5
                let center = baseline + roads.meanderAmplitude
                    * sin(2 * .pi * Double(roads.meanderCycles) * t / Double(rows) + phase)
                markBand(center: center, halfWidth: halfWidth, length: columns) { column in
                    mask[row * columns + column] = true
                }
            }
        }
        return mask
    }

    /// Calls `mark` for every wrapped cell whose centre lies within the band.
    private func markBand(center: Double, halfWidth: Double, length: Int, mark: (Int) -> Void) {
        let first = Int(floor(center - halfWidth))
        let last = Int(ceil(center + halfWidth))
        for cell in first...last {
            let cellCenter = Double(cell) + 0.5
            if abs(cellCenter - center) <= halfWidth {
                mark(positiveModulo(cell, length))
            }
        }
    }

    // MARK: - Landmarks

    private func placeLandmarks(_ rule: ClusterRule, placer: inout DecorationPlacer, random: inout SeededRandom) {
        let world = definition.world
        for _ in 0..<rule.instances {
            var center: CGPoint?
            for _ in 0..<tuning.attemptsPerDecoration * 4 {
                let candidate = CGPoint(x: random.range(0, Double(world.width)),
                                        y: random.range(0, Double(world.height)))
                if placer.canHostLandmark(at: candidate, radius: rule.radius, spacing: tuning.landmarkSpacing) {
                    center = candidate
                    break
                }
            }
            guard let landmarkCenter = center else { continue }
            placer.reserveLandmark(at: landmarkCenter)

            for member in rule.members {
                let offsets = Self.offsets(for: member, radius: rule.radius, random: &random)
                for offset in offsets {
                    _ = placer.place(member.kind, at: landmarkCenter + offset, avoidRoads: false, random: &random)
                }
            }
        }
    }

    /// Positions of a cluster's members relative to its centre.
    static func offsets(for member: ClusterMember, radius: CGFloat, random: inout SeededRandom) -> [CGPoint] {
        guard member.count > 0 else { return [] }
        switch member.arrangement {
        case .center:
            return Array(repeating: .zero, count: 1)
        case .ring:
            let start = random.range(0, 2 * .pi)
            return (0..<member.count).map { i in
                let angle = start + 2 * .pi * Double(i) / Double(member.count) + random.range(-0.15, 0.15)
                let distance = Double(radius) * random.range(0.65, 0.85)
                return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            }
        case .rows:
            // Neat rows with a little disorder: an old graveyard, not a grid.
            let perRow = max(1, Int(Double(member.count).squareRoot().rounded(.up)))
            let spacing = Double(radius) * 1.6 / Double(perRow)
            let origin = -spacing * Double(perRow - 1) / 2
            return (0..<member.count).map { i in
                let column = i % perRow
                let row = i / perRow
                return CGPoint(
                    x: origin + spacing * Double(column) + random.range(-0.2, 0.2),
                    y: origin + spacing * Double(row) + random.range(-0.2, 0.2)
                )
            }
        case .scattered:
            return (0..<member.count).map { _ in
                let angle = random.range(0, 2 * .pi)
                let distance = Double(radius) * random.range(0.2, 1.0).squareRoot()
                return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            }
        }
    }
}

/// Tracks placed decorations and rejects overlaps.
private struct DecorationPlacer {
    let world: ToroidalWorld
    let roadMask: [Bool]
    let columns: Int
    let spawn: CGPoint
    let spawnClearRadius: CGFloat

    private(set) var placements: [DecorationPlacement] = []
    private var standingGrid: ToroidalSpatialGrid
    private var landmarkCenters: [CGPoint] = []
    private var queryBuffer: [Int] = []
    /// Largest standing footprint, bounding the neighbour search radius.
    private let maxFootprint: CGFloat

    init(world: ToroidalWorld, roadMask: [Bool], columns: Int, spawn: CGPoint,
         spawnClearRadius: CGFloat, cellSize: CGFloat) {
        self.world = world
        self.roadMask = roadMask
        self.columns = columns
        self.spawn = spawn
        self.spawnClearRadius = spawnClearRadius
        standingGrid = ToroidalSpatialGrid(world: world, cellSize: cellSize)
        maxFootprint = DecorationKind.allCases
            .map { DecorationCatalog.spec(for: $0).footprintRadius }
            .max() ?? 1
    }

    func canHostLandmark(at center: CGPoint, radius: CGFloat, spacing: CGFloat) -> Bool {
        if world.distance(center, spawn) < spawnClearRadius + radius { return false }
        return landmarkCenters.allSatisfy { world.distance($0, center) >= spacing }
    }

    mutating func reserveLandmark(at center: CGPoint) {
        landmarkCenters.append(center)
    }

    mutating func place(_ kind: DecorationKind, at rawPosition: CGPoint, avoidRoads: Bool,
                        random: inout SeededRandom) -> Bool {
        let spec = DecorationCatalog.spec(for: kind)
        let position = world.wrap(rawPosition)

        if world.distance(position, spawn) < spawnClearRadius + spec.footprintRadius { return false }
        if avoidRoads && isRoad(position) { return false }

        // Ground decals may sit under anything; standing objects may not overlap.
        if spec.layer == .standing {
            queryBuffer.removeAll(keepingCapacity: true)
            standingGrid.query(around: position, radius: spec.footprintRadius + maxFootprint, into: &queryBuffer)
            for index in queryBuffer {
                let other = placements[index]
                let otherRadius = DecorationCatalog.spec(for: other.kind).footprintRadius
                if world.distance(other.position, position) < spec.footprintRadius + otherRadius {
                    return false
                }
            }
            standingGrid.insert(placements.count, at: position)
        }

        let scale = CGFloat(random.range(Double(spec.scaleRange.lowerBound), Double(spec.scaleRange.upperBound)))
        placements.append(DecorationPlacement(kind: kind, position: position, scale: scale,
                                              mirrored: random.chance(0.5)))
        return true
    }

    private func isRoad(_ position: CGPoint) -> Bool {
        let column = min(columns - 1, Int(position.x))
        let row = Int(position.y)
        let index = row * columns + column
        return index >= 0 && index < roadMask.count && roadMask[index]
    }
}
