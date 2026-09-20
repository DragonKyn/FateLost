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

    /// Everything kept between runs: echoes, the Legacy board, conquered
    /// realms and the lifetime record. Saved whenever it changes.
    private(set) var profile: LegacyProfile

    var realmProgress: RealmProgress {
        get { profile.realms }
        set {
            profile.realms = newValue
            saveProfile()
        }
    }

    @ObservationIgnored let haptics: HapticsProviding
    @ObservationIgnored let audio: AudioManager
    @ObservationIgnored private let legacyStore: LegacyStore

    init(settings: SettingsStore = SettingsStore(), developer: DeveloperOptions = DeveloperOptions(),
         legacyStore: LegacyStore = LegacyStore()) {
        self.settings = settings
        self.developer = developer
        self.legacyStore = legacyStore
        profile = legacyStore.load()
        haptics = HapticsService(isEnabled: { [weak settings] in settings?.settings.hapticsEnabled ?? false })
        audio = AudioManager(volumes: { [weak settings] in settings?.settings ?? .defaults })
    }

    func isRealmUnlocked(_ realm: RealmDefinition) -> Bool {
        if developer.unlockAllRealms { return true }
        return RealmUnlockRules.isUnlocked(realm, progress: profile.realms, catalog: RealmCatalog.all)
    }

    /// The bonuses the Legacy board grants a new run.
    var legacyModifiers: [StatModifier] {
        developer.disableLegacyBonuses ? [] : profile.modifiers
    }

    /// Everything a run starts with: the board, plus whatever mastery the
    /// weapon it is being started with has earned.
    func modifiers(startingWith weapon: WeaponDefinition) -> [StatModifier] {
        guard !developer.disableLegacyBonuses else { return [] }
        return profile.modifiers + profile.modifiers(startingWith: weapon)
    }

    /// Rerolls the codex adds to every find in a new run.
    var bonusRerolls: Int {
        developer.disableLegacyBonuses ? 0 : profile.bonusRerolls
    }

    func isUnlocked(_ weapon: WeaponDefinition) -> Bool {
        profile.isUnlocked(weapon)
    }

    /// Buys a Legacy node and keeps it.
    @discardableResult
    func buyLegacy(_ node: LegacyNode) -> Bool {
        guard profile.buy(node) else { return false }
        saveProfile()
        return true
    }

    /// Adds a weapon to the rack.
    @discardableResult
    func buyWeapon(_ weapon: WeaponDefinition) -> Bool {
        guard profile.buy(weapon: weapon) else { return false }
        saveProfile()
        return true
    }

    /// Buys the next rank of mastery for a weapon.
    @discardableResult
    func masterWeapon(_ weapon: WeaponDefinition) -> Bool {
        guard profile.master(weapon: weapon) else { return false }
        saveProfile()
        return true
    }

    /// Folds a finished run into the record and pays out its echoes.
    /// Returns what the run was worth, for the summary screen.
    @discardableResult
    func record(_ summary: RunSummary) -> Int {
        let before = profile.echoes
        profile.record(summary, realm: RealmCatalog.realm(summary.realm))
        saveProfile()
        return profile.echoes - before
    }

    private func saveProfile() {
        legacyStore.save(profile)
    }
}
