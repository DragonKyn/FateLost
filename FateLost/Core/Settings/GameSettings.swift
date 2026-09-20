import Foundation
import Observation

/// Player-facing preferences.
///
/// Decoding tolerates missing keys, so adding a setting never invalidates an
/// existing settings file — new fields simply take their defaults.
struct GameSettings: Codable, Equatable {
    var masterVolume: Double = 0.9
    var musicVolume: Double = 0.7
    var effectsVolume: Double = 0.9
    var hapticsEnabled: Bool = true
    var cameraShakeEnabled: Bool = true
    /// Whether the developer code has been entered. Only ever set in a build
    /// that has developer tools at all.
    var developerUnlocked: Bool = false

    static let defaults = GameSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = GameSettings.defaults
        masterVolume = try container.decodeIfPresent(Double.self, forKey: .masterVolume) ?? fallback.masterVolume
        musicVolume = try container.decodeIfPresent(Double.self, forKey: .musicVolume) ?? fallback.musicVolume
        effectsVolume = try container.decodeIfPresent(Double.self, forKey: .effectsVolume) ?? fallback.effectsVolume
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? fallback.hapticsEnabled
        cameraShakeEnabled = try container.decodeIfPresent(Bool.self, forKey: .cameraShakeEnabled)
            ?? fallback.cameraShakeEnabled
        developerUnlocked = try container.decodeIfPresent(Bool.self, forKey: .developerUnlocked)
            ?? fallback.developerUnlocked
    }

    /// Effective 0…1 gain for a channel after the master volume.
    var effectiveMusicVolume: Double { (masterVolume * musicVolume).clamped(0, 1) }
    var effectiveEffectsVolume: Double { (masterVolume * effectsVolume).clamped(0, 1) }
}

/// Owns the live settings and persists every change.
@Observable
final class SettingsStore {
    static let schemaVersion = 1

    private(set) var settings: GameSettings

    @ObservationIgnored private let store: VersionedFileStore<GameSettings>

    init(directory: URL = SaveLocations.directory()) {
        let fileStore = VersionedFileStore<GameSettings>(
            fileURL: directory.appendingPathComponent("settings.json"),
            currentVersion: Self.schemaVersion
        )
        store = fileStore
        settings = fileStore.load().payload ?? .defaults
    }

    /// Back to how a fresh install starts, with no file left behind.
    func reset() {
        store.erase()
        settings = .defaults
    }

    /// Applies a change and saves it if anything actually changed.
    func update(_ change: (inout GameSettings) -> Void) {
        var updated = settings
        change(&updated)
        guard updated != settings else { return }
        settings = updated
        persist()
    }

    private func persist() {
        do {
            try store.save(settings)
        } catch {
            // Losing a settings write is not worth interrupting play for;
            // the next change will try again.
            print("[Settings] Save failed: \(error)")
        }
    }
}
