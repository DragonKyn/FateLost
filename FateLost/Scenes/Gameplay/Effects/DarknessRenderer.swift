import SpriteKit

/// Draws the Encroaching Abyss: the arena floor gone dark around one lit
/// circle, and a bright ring marking that circle.
///
/// The dark sits just above the ground and below everything else — hazard
/// warnings, the player, every enemy — so it takes the floor away without
/// taking away anything the player has to read. It fades in over the
/// warning, so there is time to see it coming.
@MainActor
final class DarknessRenderer {
    /// Relative to the ground-decal layer (-500) it lives in: -250 puts the
    /// dark at -750, between the ground (-1000) and the hazard marks.
    static let darkZ: CGFloat = -250
    /// Above the hazard marks, still far below anything standing (0).
    static let ringZ: CGFloat = 100

    private let projection: IsometricProjection
    private let dark = SKShapeNode()
    private let ring = SKShapeNode()
    private let ringGlow = SKShapeNode()
    private var drawnRadius: CGSize = .zero
    private var time: CGFloat = 0

    init(projection: IsometricProjection, layer: SKNode) {
        self.projection = projection
        dark.fillColor = UIColor(red: 0.03, green: 0.01, blue: 0.06, alpha: 1)
        dark.strokeColor = .clear
        dark.zPosition = Self.darkZ
        dark.isHidden = true
        layer.addChild(dark)

        ringGlow.strokeColor = UIColor(red: 0.72, green: 0.66, blue: 1, alpha: 0.35)
        ringGlow.fillColor = UIColor(red: 0.72, green: 0.66, blue: 1, alpha: 0.08)
        ringGlow.lineWidth = 10
        ringGlow.zPosition = Self.ringZ
        ringGlow.isHidden = true
        layer.addChild(ringGlow)

        ring.strokeColor = UIColor(red: 0.92, green: 0.9, blue: 1, alpha: 1)
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.zPosition = Self.ringZ + 1
        ring.isHidden = true
        layer.addChild(ring)
    }

    func update(_ darkness: DarknessState?, frame: WrappedRenderFrame, dt: CGFloat) {
        guard let darkness else {
            dark.isHidden = true
            ring.isHidden = true
            ringGlow.isHidden = true
            return
        }
        time += dt
        let centre = projection.toScreen(frame.unwrapped(darkness.safeCenter))
        let radii = screenRadii(of: darkness.safeRadius)
        if radii != drawnRadius {
            drawnRadius = radii
            rebuildPaths(radii: radii)
        }
        for node in [dark, ring, ringGlow] {
            node.position = centre
            node.isHidden = false
        }
        if darkness.isWarning {
            // Gathering: the dark deepens over the warning, and the ring
            // pulses to draw the eye to where it is safe.
            let total = max(0.1, FateTuning.eclipseWarning)
            let gathered = 1 - CGFloat(max(0, min(1, darkness.warningRemaining / total)))
            dark.alpha = 0.15 + 0.5 * gathered
            let pulse = 0.55 + 0.45 * abs(sin(time * 6))
            ring.alpha = pulse
            ringGlow.alpha = pulse
        } else {
            // Hurting: the dark at its deepest, the ring held steady so the
            // edge of safety never flickers.
            dark.alpha = 0.72
            ring.alpha = 1
            ringGlow.alpha = 0.85 + 0.15 * sin(time * 2)
        }
    }

    /// A world circle's screen ellipse: the isometric squash turns a circle on
    /// the ground into an ellipse on the screen.
    private func screenRadii(of radius: CGFloat) -> CGSize {
        let diagonal = radius / 2.squareRoot()
        let horizontal = abs(projection.toScreen(CGPoint(x: diagonal, y: -diagonal)).x)
        let vertical = abs(projection.toScreen(CGPoint(x: diagonal, y: diagonal)).y)
        return CGSize(width: max(1, horizontal), height: max(1, vertical))
    }

    private func rebuildPaths(radii: CGSize) {
        let oval = CGRect(x: -radii.width, y: -radii.height, width: radii.width * 2, height: radii.height * 2)
        // A vast sheet with the circle cut out of it: the circle wound the
        // other way, so either fill rule leaves it empty.
        let sheet = UIBezierPath(rect: CGRect(x: -6000, y: -6000, width: 12000, height: 12000))
        sheet.append(UIBezierPath(ovalIn: oval).reversing())
        sheet.usesEvenOddFillRule = true
        dark.path = sheet.cgPath
        ring.path = UIBezierPath(ovalIn: oval).cgPath
        ringGlow.path = UIBezierPath(ovalIn: oval.insetBy(dx: -3, dy: -3)).cgPath
    }
}
