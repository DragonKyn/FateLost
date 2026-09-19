import Foundation
import Observation

/// One-off actions requested from the developer panel. The scene carries
/// them out on its next frame.
enum DeveloperCommand: Equatable {
    case spawnEnemies(Int)
    case defeatAllEnemies
    case restoreHealth
    case shakeCamera
    case grantLevels(Int)
    case resetSkills
}

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
    var showHitboxes = false
    /// Multiplies simulated time. 1 is normal speed.
    var gameSpeed: Double = 1
    var unlockAllRealms = false
    /// The player takes no damage.
    var godMode = false
    /// Natural enemy spawning; developer spawns work either way.
    var spawningEnabled = true

    private(set) var pendingCommands: [DeveloperCommand] = []

    static let gameSpeedPresets: [Double] = [0.25, 0.5, 1, 2, 4]

    static var isAvailable: Bool {
        #if FATELOST_DEVTOOLS
        return true
        #else
        return false
        #endif
    }

    func send(_ command: DeveloperCommand) {
        pendingCommands.append(command)
    }

    /// Hands over queued commands. Leaves the queue untouched when empty so
    /// the per-frame check doesn't trigger observation updates.
    func takeCommands() -> [DeveloperCommand] {
        guard !pendingCommands.isEmpty else { return [] }
        let commands = pendingCommands
        pendingCommands.removeAll()
        return commands
    }
}
