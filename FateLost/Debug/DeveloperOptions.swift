import Foundation
import Observation

/// Developer toggles read by the game each frame.
///
/// The type exists in every build so gameplay code needs no conditional
/// compilation, but the UI that changes it is only compiled into developer
/// builds (`FATELOST_DEVTOOLS`). In a shipping build these stay at their
/// defaults and have no effect.
@Observable
final class DeveloperOptions {
    var showPerformanceOverlay = false
    var showWrapSeams = false
    /// Multiplies simulated time. 1 is normal speed.
    var gameSpeed: Double = 1
    var unlockAllRealms = false
    /// Incremented to request a camera shake test; the scene watches for changes.
    var shakeTestCounter = 0

    static let gameSpeedPresets: [Double] = [0.25, 0.5, 1, 2, 4]

    static var isAvailable: Bool {
        #if FATELOST_DEVTOOLS
        return true
        #else
        return false
        #endif
    }
}
