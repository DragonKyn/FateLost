import SpriteKit

/// Numbers shown by the developer performance overlay.
struct PerformanceSnapshot {
    var framesPerSecond: Double = 0
    var nodeCount: Int = 0
    var enemyCount: Int = 0
    var projectileCount: Int = 0
    var pickupCount: Int = 0
    var wave: Int = 1
    var playerLevel: Int = 1
    var playerPosition: CGPoint = .zero
    var activeDecorations: Int = 0
    var activeEffects: Int = 0
    /// Average milliseconds per frame spent advancing the simulation.
    var simulationMilliseconds: Double = 0
    var spawnRate: Double = 0
    /// Aggregate movement-stream figures in a party run (see `MovementStats`).
    var network: String?
}

/// Averages frame times over a short window so the FPS readout is stable.
struct FrameRateMeter {
    private var frames = 0
    private var elapsed: TimeInterval = 0
    private(set) var framesPerSecond: Double = 0
    let window: TimeInterval

    init(window: TimeInterval = 0.5) {
        self.window = window
    }

    /// Returns true when a new average is available.
    mutating func record(frameDelta: TimeInterval) -> Bool {
        frames += 1
        elapsed += frameDelta
        guard elapsed >= window else { return false }
        framesPerSecond = Double(frames) / elapsed
        frames = 0
        elapsed = 0
        return true
    }
}

/// Top-left developer readout. Only instantiated in developer builds.
@MainActor
final class PerformanceOverlayNode: SKNode {
    private let background = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "Menlo")

    override init() {
        super.init()
        zPosition = DepthSorting.Band.hud + 10
        background.fillColor = SKColor(white: 0, alpha: 0.55)
        background.strokeColor = .clear
        addChild(background)

        label.fontSize = 11
        label.fontColor = SKColor(red: 0.55, green: 1, blue: 0.6, alpha: 1)
        label.numberOfLines = 0
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: 8, y: -6)
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("PerformanceOverlayNode is created in code")
    }

    func show(_ snapshot: PerformanceSnapshot) {
        label.text = """
        FPS \(Int(snapshot.framesPerSecond.rounded()))   nodes \(snapshot.nodeCount)
        enemies \(snapshot.enemyCount)   proj \(snapshot.projectileCount)   pickups \(snapshot.pickupCount)
        wave \(snapshot.wave)   level \(snapshot.playerLevel)   decor \(snapshot.activeDecorations)   fx \(snapshot.activeEffects)
        sim \(String(format: "%.2f", snapshot.simulationMilliseconds)) ms   spawn \(String(format: "%.1f", snapshot.spawnRate))/s
        pos \(String(format: "%.1f, %.1f", snapshot.playerPosition.x, snapshot.playerPosition.y))
        \(snapshot.network ?? "")
        """
        let frame = label.calculateAccumulatedFrame()
        background.path = CGPath(roundedRect: CGRect(x: 0, y: -frame.height - 12,
                                                     width: frame.width + 16, height: frame.height + 12),
                                 cornerWidth: 6, cornerHeight: 6, transform: nil)
    }

    /// Counts every node beneath `root`. Walks the tree, so call sparingly.
    static func countNodes(in root: SKNode) -> Int {
        var count = 1
        for child in root.children {
            count += countNodes(in: child)
        }
        return count
    }
}

/// Draws the arena's wrap boundaries near the player, to confirm the seam is
/// invisible everywhere except in this overlay.
@MainActor
final class WrapSeamOverlayNode: SKShapeNode {
    /// Half-length, in world units, of each drawn boundary segment.
    private let reach: CGFloat = 30

    override init() {
        super.init()
        strokeColor = SKColor(red: 1, green: 0.2, blue: 0.3, alpha: 0.85)
        lineWidth = 2
        zPosition = DepthSorting.Band.overlays - 10
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("WrapSeamOverlayNode is created in code")
    }

    func update(frame: WrappedRenderFrame, projection: IsometricProjection) {
        let world = frame.world
        let focus = frame.focusUnwrapped
        // Nearest multiples of the arena size are where the seams lie.
        let seamX = (focus.x / world.width).rounded() * world.width
        let seamY = (focus.y / world.height).rounded() * world.height

        let path = CGMutablePath()
        path.move(to: projection.toScreen(CGPoint(x: seamX, y: focus.y - reach)))
        path.addLine(to: projection.toScreen(CGPoint(x: seamX, y: focus.y + reach)))
        path.move(to: projection.toScreen(CGPoint(x: focus.x - reach, y: seamY)))
        path.addLine(to: projection.toScreen(CGPoint(x: focus.x + reach, y: seamY)))
        self.path = path
    }
}
