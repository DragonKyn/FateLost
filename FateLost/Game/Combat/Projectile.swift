import CoreGraphics

/// A projectile in flight. Few enough exist at once that a plain array of
/// structs is simpler than parallel arrays and just as fast.
struct Projectile {
    let id: Int
    var position: CGPoint
    /// World units per second.
    var velocity: CGPoint
    /// Seconds before it fizzles out.
    var remainingLife: Double
    /// Further enemies it may pass through after the next hit.
    var pierceRemaining: Int
    /// The damage it carries; direction is filled in on impact.
    var hit: Hit
    /// Body radius for hits, in world units.
    let radius: CGFloat
    /// Radius of the burst on impact; zero for none.
    let splashRadius: CGFloat
    let spriteID: SpriteID
    let visual: VisualStyle
    /// Enemies already struck, so a piercing shot hits each only once.
    var struckEnemyIDs: [Int] = []
    /// Loosed by an enemy: it looks for the player and their summons rather
    /// than for the horde.
    var isHostile = false

    var direction: CGPoint { velocity.normalized }
}
