import CoreGraphics

/// Maps flat world coordinates (tiles) to 2:1 isometric screen space (points).
///
/// World +x runs toward the lower right of the screen and world +y toward the
/// lower left, so a unit square of world becomes a `tileWidth` × `tileHeight`
/// diamond. Screen space here is SpriteKit's: y increases upward.
///
/// The mapping is linear, so it converts both positions and directions.
struct IsometricProjection: Equatable {
    let tileWidth: CGFloat
    let tileHeight: CGFloat

    private var halfWidth: CGFloat { tileWidth / 2 }
    private var halfHeight: CGFloat { tileHeight / 2 }

    func toScreen(_ world: CGPoint) -> CGPoint {
        CGPoint(
            x: (world.x - world.y) * halfWidth,
            y: -(world.x + world.y) * halfHeight
        )
    }

    func toWorld(_ screen: CGPoint) -> CGPoint {
        let a = screen.x / halfWidth      // x - y
        let b = -screen.y / halfHeight    // x + y
        return CGPoint(x: (a + b) / 2, y: (b - a) / 2)
    }

    /// Converts a screen-space input direction (e.g. from the joystick) into a
    /// world-space direction with the same magnitude.
    ///
    /// Pushing the stick straight right moves the character straight right on
    /// screen. Magnitude is preserved in *world* space, so vertical on-screen
    /// motion is visually slower than horizontal — the foreshortening that
    /// sells the isometric depth.
    func worldDirection(fromScreen direction: CGPoint) -> CGPoint {
        let magnitude = min(direction.length, 1)
        guard magnitude > 0 else { return .zero }
        return toWorld(direction).normalized * magnitude
    }
}
