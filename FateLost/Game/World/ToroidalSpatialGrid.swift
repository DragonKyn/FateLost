import CoreGraphics

/// Uniform bucket grid over the wrapping arena.
///
/// Broad-phase lookup for "what is near this point?" without scanning every
/// object. Decorations use it statically today; enemies, projectiles and
/// pickups will rebuild it each tick (`removeAll` keeps bucket capacity, so a
/// rebuild allocates nothing in steady state). Queries wrap across the seam.
///
/// A query returns *candidates*: everything in the overlapped cells. Callers
/// apply their own exact distance test.
struct ToroidalSpatialGrid {
    let world: ToroidalWorld
    let cellSize: CGFloat
    let columns: Int
    let rows: Int

    private var buckets: [[Int]]

    init(world: ToroidalWorld, cellSize: CGFloat) {
        precondition(cellSize > 0, "Cell size must be positive")
        self.world = world
        self.cellSize = cellSize
        columns = max(1, Int((world.width / cellSize).rounded(.up)))
        rows = max(1, Int((world.height / cellSize).rounded(.up)))
        buckets = Array(repeating: [], count: columns * rows)
    }

    var count: Int { buckets.reduce(0) { $0 + $1.count } }

    mutating func insert(_ id: Int, at position: CGPoint) {
        buckets[bucketIndex(for: world.wrap(position))].append(id)
    }

    mutating func removeAll() {
        for index in buckets.indices {
            buckets[index].removeAll(keepingCapacity: true)
        }
    }

    /// Appends every id whose bucket overlaps the square of `radius` around
    /// `center`. Each bucket is visited at most once, even when the radius is
    /// wider than the world.
    func query(around center: CGPoint, radius: CGFloat, into results: inout [Int]) {
        let wrapped = world.wrap(center)
        let centerColumn = Int(wrapped.x / cellSize)
        let centerRow = Int(wrapped.y / cellSize)
        let span = Int((radius / cellSize).rounded(.up))

        let columnOffsets = offsets(span: span, count: columns)
        let rowOffsets = offsets(span: span, count: rows)

        for rowOffset in rowOffsets {
            let row = positiveModulo(centerRow + rowOffset, rows)
            for columnOffset in columnOffsets {
                let column = positiveModulo(centerColumn + columnOffset, columns)
                results.append(contentsOf: buckets[row * columns + column])
            }
        }
    }

    func cellCoordinate(for position: CGPoint) -> (column: Int, row: Int) {
        let wrapped = world.wrap(position)
        return (
            min(columns - 1, Int(wrapped.x / cellSize)),
            min(rows - 1, Int(wrapped.y / cellSize))
        )
    }

    private func bucketIndex(for wrapped: CGPoint) -> Int {
        let cell = cellCoordinate(for: wrapped)
        return cell.row * columns + cell.column
    }

    /// Offsets `-span...span`, trimmed so no bucket appears twice.
    private func offsets(span: Int, count: Int) -> ClosedRange<Int> {
        if span * 2 + 1 >= count {
            return 0...(count - 1)
        }
        return -span...span
    }
}
