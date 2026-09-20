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

    /// How the player chose to look. Cosmetic, and kept apart from the
    /// profile so nothing that happens to one can cost the other.
    private(set) var hero: HeroAppearance

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
    @ObservationIgnored private let heroStore: HeroStore

    init(settings: SettingsStore = SettingsStore(), developer: DeveloperOptions = DeveloperOptions(),
         legacyStore: LegacyStore = LegacyStore(), heroStore: HeroStore = HeroStore()) {
        self.settings = settings
        self.developer = developer
        self.legacyStore = legacyStore
        self.heroStore = heroStore
        let loaded = legacyStore.load()
        profile = loaded
        // Whatever the saved look, it may only wear what has been paid for.
        hero = heroStore.load().restricted(to: { loaded.owns($0) })
        haptics = HapticsService(isEnabled: { [weak settings] in settings?.settings.hapticsEnabled ?? false })
        audio = AudioManager(volumes: { [weak settings] in settings?.settings ?? .defaults })
    }

    // MARK: Developer mode

    /// Developer tools are shown only in a build that has them and only once
    /// the code has been entered in Settings.
    var isDeveloperModeOn: Bool {
        DeveloperOptions.isAvailable && settings.settings.developerUnlocked
    }

    /// Opens developer mode if the code is right.
    @discardableResult
    func unlockDeveloperMode(code: String) -> Bool {
        guard DeveloperOptions.isAvailable, DeveloperOptions.accepts(code) else { return false }
        settings.update { $0.developerUnlocked = true }
        return true
    }

    func lockDeveloperMode() {
        settings.update { $0.developerUnlocked = false }
        developer.reset()
    }

    // MARK: Sealing fate

    /// Erases every save: the profile and everything on it, the hero, and the
    /// settings, developer mode included. What follows is a fresh install.
    func sealFate() {
        legacyStore.erase()
        heroStore.erase()
        settings.reset()
        profile = LegacyProfile()
        hero = .standard
        developer.reset()
        audio.refreshVolumes()
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

    /// Keeps the look the player has chosen, minus anything not yet bought.
    func setHero(_ look: HeroAppearance) {
        let allowed = look.restricted(to: { profile.owns($0) })
        guard allowed != hero else { return }
        hero = allowed
        heroStore.save(allowed)
    }

    func owns(_ option: HeroOption) -> Bool {
        profile.owns(option)
    }

    /// Buys a look from the character screen.
    @discardableResult
    func buyLook(_ option: HeroOption) -> Bool {
        guard profile.buy(option) else { return false }
        saveProfile()
        return true
    }

    private func saveProfile() {
        legacyStore.save(profile)
    }
}
