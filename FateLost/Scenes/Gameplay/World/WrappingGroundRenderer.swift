import SpriteKit

/// Draws the arena floor so it wraps without seams.
///
/// The whole arena is one isometric `SKTileMapNode` — a single node that
/// SpriteKit culls and batches itself, far cheaper than hundreds of tile
/// sprites. Because the camera never sees more than half the arena at once,
/// four copies of the map, laid out 2×2 around the camera, are enough to
/// cover every view. As the player walks, copies leapfrog to stay around
/// them; since tiles are defined per wrapped coordinate, every copy is
/// identical and the jump is invisible.
@MainActor
final class WrappingGroundRenderer {
    let node = SKNode()

    private let projection: IsometricProjection
    private let arenaWidth: CGFloat
    private let arenaHeight: CGFloat
    private var copies: [SKTileMapNode] = []
    /// World-space minimum corner of the region one map copy covers.
    private var regionOrigin: CGPoint = .zero
    /// Map-local centre of cell (0, 0), measured from SpriteKit.
    private var cellZeroCenter: CGPoint = .zero
    private var lastPlacementKey: [Int] = []

    /// Texture variants generated per ground style to break up repetition.
    private static let variantsPerStyle = 3
    /// Points each tile texture extends past its diamond to hide seams.
    private static let tileBleed: CGFloat = 1

    init(layout: ArenaLayout, theme: ArenaTheme, projection: IsometricProjection) {
        self.projection = projection
        arenaWidth = CGFloat(layout.columns)
        arenaHeight = CGFloat(layout.rows)

        let tileSize = CGSize(width: projection.tileWidth, height: projection.tileHeight)
        let groups = Self.makeTileGroups(theme: theme, tileSize: tileSize)
        let tileSet = SKTileSet(tileGroups: groups.flatMap { $0 }, tileSetType: .isometric)

        // SpriteKit's isometric column/row directions are an implementation
        // detail, so measure them rather than assume them.
        let probe = SKTileMapNode(tileSet: tileSet, columns: 2, rows: 2, tileSize: tileSize)
        let columnAxis = worldAxis(probe.centerOfTile(atColumn: 1, row: 0) - probe.centerOfTile(atColumn: 0, row: 0))
        let rowAxis = worldAxis(probe.centerOfTile(atColumn: 0, row: 1) - probe.centerOfTile(atColumn: 0, row: 0))

        let columnsRunAlongX = columnAxis.dx != 0
        let mapColumns = columnsRunAlongX ? layout.columns : layout.rows
        let mapRows = columnsRunAlongX ? layout.rows : layout.columns

        // World tile each map cell represents, before wrapping.
        func worldTile(column: Int, row: Int) -> (x: Int, y: Int) {
            (column * columnAxis.dx + row * rowAxis.dx, column * columnAxis.dy + row * rowAxis.dy)
        }

        let corners = [worldTile(column: 0, row: 0), worldTile(column: mapColumns - 1, row: 0),
                       worldTile(column: 0, row: mapRows - 1), worldTile(column: mapColumns - 1, row: mapRows - 1)]
        regionOrigin = CGPoint(x: corners.map { $0.x }.min() ?? 0, y: corners.map { $0.y }.min() ?? 0)

        // Resolve every cell's tile group once, then stamp it into each copy.
        var cellGroups: [SKTileGroup] = []
        cellGroups.reserveCapacity(mapColumns * mapRows)
        for row in 0..<mapRows {
            for column in 0..<mapColumns {
                let tile = worldTile(column: column, row: row)
                let style = layout.groundStyle(column: tile.x, row: tile.y)
                let variant = Int(CoordinateHash.unit(positiveModulo(tile.x, layout.columns),
                                                      positiveModulo(tile.y, layout.rows), seed: 0x6120_0D)
                                  * Double(Self.variantsPerStyle))
                let styleGroups = groups[min(style, groups.count - 1)]
                cellGroups.append(styleGroups[min(variant, styleGroups.count - 1)])
            }
        }

        for _ in 0..<4 {
            let map = SKTileMapNode(tileSet: tileSet, columns: mapColumns, rows: mapRows, tileSize: tileSize)
            map.enableAutomapping = false
            for row in 0..<mapRows {
                for column in 0..<mapColumns {
                    map.setTileGroup(cellGroups[row * mapColumns + column], forColumn: column, row: row)
                }
            }
            copies.append(map)
            node.addChild(map)
        }
        cellZeroCenter = copies[0].centerOfTile(atColumn: 0, row: 0)
    }

    /// Keeps the four copies arranged around the camera focus.
    ///
    /// - Parameter force: Re-place even if the arrangement is unchanged
    ///   (after a render-frame rebase).
    func update(focusUnwrapped focus: CGPoint, force: Bool = false) {
        let local = focus - regionOrigin
        let blockX = Int(floor(local.x / arenaWidth))
        let blockY = Int(floor(local.y / arenaHeight))
        let neighbourX = local.x - CGFloat(blockX) * arenaWidth < arenaWidth / 2 ? -1 : 1
        let neighbourY = local.y - CGFloat(blockY) * arenaHeight < arenaHeight / 2 ? -1 : 1

        let key = [blockX, blockY, neighbourX, neighbourY]
        guard force || key != lastPlacementKey else { return }
        lastPlacementKey = key

        let blocks = [(blockX, blockY), (blockX + neighbourX, blockY),
                      (blockX, blockY + neighbourY), (blockX + neighbourX, blockY + neighbourY)]
        for (map, block) in zip(copies, blocks) {
            let offset = CGPoint(x: CGFloat(block.0) * arenaWidth, y: CGFloat(block.1) * arenaHeight)
            // Cell (0,0) of every copy represents world tile (0,0), whose
            // centre is at (0.5, 0.5) plus the copy's offset.
            map.position = projection.toScreen(CGPoint(x: 0.5, y: 0.5) + offset) - cellZeroCenter
        }
    }

    private func worldAxis(_ screenStep: CGPoint) -> (dx: Int, dy: Int) {
        let step = projection.toWorld(screenStep)
        if abs(step.x) >= abs(step.y) {
            return (step.x >= 0 ? 1 : -1, 0)
        }
        return (0, step.y >= 0 ? 1 : -1)
    }

    private static func makeTileGroups(theme: ArenaTheme, tileSize: CGSize) -> [[SKTileGroup]] {
        theme.groundStyles.map { style in
            (0..<variantsPerStyle).map { variant in
                let image = PlaceholderArt.groundTile(style: style, tileSize: tileSize,
                                                      bleed: tileBleed, variant: variant)
                let texture = SKTexture(image: image)
                let definition = SKTileDefinition(texture: texture, size: image.size)
                return SKTileGroup(tileDefinition: definition)
            }
        }
    }
}
