import Foundation
import Observation

/// Long-lived services shared by the app, created once at launch and handed
/// down explicitly (SwiftUI environment, scene initialisers) instead of being
/// reached through global singletons.
@MainActor
@Observable
final class AppServices {
    let settings: SettingsStore
    let developer: DeveloperOptions
    /// In-memory until the Legacy save arrives in Phase 6.
    var realmProgress = RealmProgress()

    @ObservationIgnored let haptics: HapticsProviding
    @ObservationIgnored let audio: AudioManager

    init(settings: SettingsStore = SettingsStore(), developer: DeveloperOptions = DeveloperOptions()) {
        self.settings = settings
        self.developer = developer
        haptics = HapticsService(isEnabled: { [weak settings] in settings?.settings.hapticsEnabled ?? false })
        audio = AudioManager(volumes: { [weak settings] in settings?.settings ?? .defaults })
    }

    func isRealmUnlocked(_ realm: RealmDefinition) -> Bool {
        if developer.unlockAllRealms { return true }
        return RealmUnlockRules.isUnlocked(realm, progress: realmProgress, catalog: RealmCatalog.all)
    }
}
