import CoreGraphics

/// Safe-area insets without a UIKit dependency.
struct ScreenInsets: Equatable {
    var top: CGFloat = 0
    var left: CGFloat = 0
    var bottom: CGFloat = 0
    var right: CGFloat = 0

    static let zero = ScreenInsets()
}

/// Positions of on-screen controls for a given screen.
///
/// Coordinates are relative to the screen centre with y up, matching nodes
/// parented to the scene camera. Controls scale with screen height so they
/// keep a comfortable physical size from small iPhones to large iPads.
struct HUDLayout: Equatable {
    let screenSize: CGSize
    let controlScale: CGFloat

    let joystickRadius: CGFloat
    /// Where the stick rests as a hint when no thumb is down.
    let joystickRest: CGPoint
    /// Touches left of this x summon the joystick.
    let joystickZoneMaxX: CGFloat

    let abilityButtonSize: CGFloat
    let ultimateButtonSize: CGFloat
    /// Centres of ability slots 1–3.
    let abilitySlots: [CGPoint]
    let ultimateSlot: CGPoint

    /// Top-left corner available for developer overlays.
    let overlayOrigin: CGPoint

    init(screenSize: CGSize, insets: ScreenInsets, tuning: ControlsTuning) {
        self.screenSize = screenSize
        let scale = (screenSize.height / tuning.referenceScreenHeight).clamped(1, tuning.maximumControlScale)
        controlScale = scale

        let margin = tuning.edgeMargin * scale
        let left = -screenSize.width / 2 + insets.left + margin
        let right = screenSize.width / 2 - insets.right - margin
        let bottom = -screenSize.height / 2 + insets.bottom + margin
        let top = screenSize.height / 2 - insets.top - margin

        joystickRadius = tuning.joystickRadius * scale
        joystickRest = CGPoint(x: left + joystickRadius * 1.25, y: bottom + joystickRadius * 1.25)
        joystickZoneMaxX = -screenSize.width / 2 + screenSize.width * tuning.joystickZoneWidthFraction

        abilityButtonSize = tuning.abilityButtonSize * scale
        ultimateButtonSize = tuning.ultimateButtonSize * scale
        let ultimate = CGPoint(x: right - ultimateButtonSize / 2, y: bottom + ultimateButtonSize / 2)
        ultimateSlot = ultimate

        // Abilities fan around the ultimate: left, diagonal, above — all
        // reachable by a right thumb resting near the corner.
        let orbit = ultimateButtonSize / 2 + abilityButtonSize / 2 + 12 * scale
        let angles: [CGFloat] = [.pi, .pi * 0.75, .pi * 0.5]
        abilitySlots = angles.map { angle in
            CGPoint(x: ultimate.x + cos(angle) * orbit, y: ultimate.y + sin(angle) * orbit)
        }

        overlayOrigin = CGPoint(x: left, y: top)
    }

    /// Index of the ability slot under `point` (0–2), 3 for the ultimate.
    func abilitySlot(at point: CGPoint) -> Int? {
        let ultimateReach = ultimateButtonSize / 2 * 1.1
        if (point - ultimateSlot).length <= ultimateReach { return 3 }
        let abilityReach = abilityButtonSize / 2 * 1.15
        return abilitySlots.firstIndex { (point - $0).length <= abilityReach }
    }
}
