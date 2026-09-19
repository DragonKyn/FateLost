import CoreGraphics
import Foundation

/// Central home for feel-and-presentation tuning that is not realm content.
///
/// Values are grouped per system and injected, so tests can build systems
/// with their own numbers and balance passes never touch gameplay logic.
/// Every group is a plain value type, ready to load from JSON later.
struct GameTuning {
    var simulation = SimulationTuning()
    var player = PlayerTuning()
    var camera = CameraTuning()
    var projection = ProjectionTuning()
    var controls = ControlsTuning()
    var rendering = RenderingTuning()

    static let standard = GameTuning()
}

struct SimulationTuning {
    /// Fixed simulation step.
    var timestep: TimeInterval = 1.0 / 60.0
    /// Upper bound on catch-up steps after a hitch.
    var maxStepsPerFrame: Int = 5
}

struct PlayerTuning {
    /// World units (tiles) per second before any modifiers.
    var baseMoveSpeed: CGFloat = 4.2
    /// Tiles per second squared when speeding up.
    var acceleration: CGFloat = 38
    /// Tiles per second squared when releasing the stick. Higher than
    /// acceleration so stopping feels crisp and dodges are precise.
    var deceleration: CGFloat = 55
    var baseMaxHealth: Double = 100
}

struct CameraTuning {
    /// How quickly the camera closes on its target; higher is tighter.
    var followSharpness: CGFloat = 7.5
    /// World units the camera leads ahead of the player at full speed.
    var lookAhead: CGFloat = 1.1
    /// How quickly the lead responds to direction changes.
    var lookAheadSharpness: CGFloat = 3
    /// Screen height, in scene points, the camera aims to show. The scale is
    /// derived from the device so an iPhone and an iPad frame similar space.
    var targetVisibleHeight: CGFloat = 470
    var minimumScale: CGFloat = 0.72
    var maximumScale: CGFloat = 1.45
    /// Trauma lost per second; shake intensity is trauma squared.
    var shakeDecay: CGFloat = 1.6
    /// Offset in scene points at full trauma.
    var shakeMaxOffset: CGFloat = 16
    var shakeFrequency: CGFloat = 28
}

struct ProjectionTuning {
    /// On-screen size of one ground tile diamond, in scene points.
    var tileWidth: CGFloat = 80
    var tileHeight: CGFloat = 40
}

struct ControlsTuning {
    /// Knob travel from base centre, in points, before scaling for device.
    var joystickRadius: CGFloat = 58
    /// Fraction of travel ignored around the centre.
    var joystickDeadZone: CGFloat = 0.12
    /// Fraction of the screen width, from the left, that summons the stick.
    var joystickZoneWidthFraction: CGFloat = 0.5
    /// When the thumb drags past the rim, the base follows it this far behind,
    /// so reversing direction never needs a long drag back.
    var joystickFollowsThumb: Bool = true
    var abilityButtonSize: CGFloat = 62
    var ultimateButtonSize: CGFloat = 82
    /// Controls are designed on a 390pt-tall phone and scaled up to this
    /// factor on larger screens.
    var referenceScreenHeight: CGFloat = 390
    var maximumControlScale: CGFloat = 1.45
    /// Minimum distance from any screen edge after safe-area insets.
    var edgeMargin: CGFloat = 22
}

struct RenderingTuning {
    /// Extra world units around the visible area in which decorations are
    /// kept live, so they are in place before they scroll into view.
    var decorationMargin: CGFloat = 3
    /// Once the unwrapped camera focus drifts this many arena sizes from the
    /// origin, it is shifted back to preserve floating-point precision.
    var rebaseThresholdPeriods: CGFloat = 4
    var preferredFramesPerSecond: Int = 60
}
