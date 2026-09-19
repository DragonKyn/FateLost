import CoreGraphics

/// A generated arena: ground tiles, set dressing and the spawn point.
///
/// Pure data with no SpriteKit dependency. The same definition and seed always
/// produce the same layout.
struct ArenaLayout {
    let world: ToroidalWorld
    let columns: Int
    let rows: Int
    /// Row-major ground style indices into the theme's `groundStyles`.
    let groundStyles: [UInt8]
    /// Row-major flags marking road tiles.
    let roadMask: [Bool]
    let decorations: [DecorationPlacement]
    let playerSpawn: CGPoint

    /// Ground style of any tile coordinate; coordinates outside the arena
    /// wrap, so callers can pass unwrapped tile indices directly.
    func groundStyle(column: Int, row: Int) -> Int {
        Int(groundStyles[index(column: column, row: row)])
    }

    func isRoad(column: Int, row: Int) -> Bool {
        roadMask[index(column: column, row: row)]
    }

    func isRoad(at position: CGPoint) -> Bool {
        let wrapped = world.wrap(position)
        return isRoad(column: Int(wrapped.x), row: Int(wrapped.y))
    }

    private func index(column: Int, row: Int) -> Int {
        positiveModulo(row, rows) * columns + positiveModulo(column, columns)
    }
}
