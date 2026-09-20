import Foundation
import Observation

/// Everything multiplayer that the rest of the app talks to.
///
/// The hub owns the party connection, this installation's identity, the
/// player's chosen name and what they bring to a party. It is the one place
/// where the party's lifecycle (lobby, run, back to the lobby) meets the app's
/// own screens, so no screen and no rendering code needs to know about
/// networking.
@MainActor
@Observable
final class MultiplayerHub {
    let client: PartyClient
    private(set) var identity: MultiplayerIdentity
    private(set) var displayName: String?

    /// The weapon this player starts multiplayer runs with.
    var partyWeaponID: WeaponID = StarterWeapons.sword.id {
        didSet { if oldValue != partyWeaponID { pushLoadout() } }
    }

    /// The run in progress, if this phone is playing one.
    private(set) var run: PartyRunController?

    @ObservationIgnored private let prefs: MultiplayerPreferencesStore
    @ObservationIgnored private weak var services: AppServices?
    @ObservationIgnored private weak var router: AppRouter?
    @ObservationIgnored private let secrets: SecretStore

    init(services: AppServices, secrets: SecretStore = KeychainSecretStore(),
         directory: URL = SaveLocations.directory(), environment: ((MultiplayerIdentity, PartySessionVault) -> PartyClient.Environment)? = nil) {
        self.services = services
        self.secrets = secrets
        let identity = MultiplayerIdentity.load(from: secrets)
        self.identity = identity
        let vault = PartySessionVault(store: secrets)
        prefs = MultiplayerPreferencesStore(directory: directory)
        displayName = prefs.displayName
        let built = environment?(identity, vault) ?? PartyClient.Environment.live(identity: identity, vault: vault)
        client = PartyClient(environment: built)
        wire()
    }

    /// Lets the hub move the player between screens.
    func attach(router: AppRouter) {
        self.router = router
    }

    // MARK: - The player

    /// Saves the name shown in parties. Returns false if it cannot be used.
    @discardableResult
    func setDisplayName(_ name: String) -> Bool {
        guard let saved = prefs.setDisplayName(name) else { return false }
        displayName = saved
        if client.isInParty { client.rename(saved) }
        return true
    }

    /// A name to fill a text field with: theirs, or nothing yet.
    var suggestedName: String { displayName ?? "" }

    /// What this player brings to a party right now.
    func makeLoadout() -> PartyLoadout? {
        guard let services else { return nil }
        let weapon = StarterWeapons.definition(for: partyWeaponID) ?? StarterWeapons.sword
        return PartyLoadout.make(weapon: weapon, hero: services.hero, profile: services.profile)
    }

    /// Tells the party what this player brings (their weapon, their look).
    func pushLoadout() {
        guard client.isInParty, let loadout = makeLoadout() else { return }
        client.setLoadout(loadout)
    }

    /// The weapons this player may start a party run with.
    var availableWeapons: [WeaponDefinition] {
        guard let services else { return [StarterWeapons.sword] }
        return StarterWeapons.all.filter { services.isUnlocked($0) }
    }

    // MARK: - Entering and leaving

    /// Creates a party and puts this player in it as host.
    func host(password: String?) async throws {
        guard let name = displayName else { throw PartyError.invalidName }
        try await client.host(name: name, password: password)
        pushLoadout()
        // A fresh party starts in the first realm this player has open.
        if let services, let first = RealmCatalog.all.first(where: { services.isRealmUnlocked($0) }) {
            client.setRealm(first.id.rawValue)
        }
        router?.show(.lobby)
    }

    func join(code: String, password: String?) async throws {
        guard let name = displayName else { throw PartyError.invalidName }
        try await client.join(code: code, name: name, password: password)
        pushLoadout()
        router?.show(.lobby)
    }

    /// If this phone was in a party when the app last ran, try to go back.
    func resumeIfPossible() {
        guard !client.isInParty, client.hasSavedSession else { return }
        client.resumeSavedSession()
    }

    /// Leaves the party and returns to the multiplayer menu. The host can
    /// close it for everyone instead.
    func leaveParty(closing: Bool = false) {
        run?.stop()
        run = nil
        if closing {
            client.closeParty()
        } else {
            client.leave()
        }
        router?.show(.multiplayer)
    }

    /// Forgets everything multiplayer knows about this phone: the name, the
    /// identity and any party. Part of sealing one's fate.
    func eraseEverything() {
        run?.stop()
        run = nil
        client.leave()
        prefs.erase()
        displayName = nil
        MultiplayerIdentity.erase(from: secrets)
        PartySessionVault(store: secrets).clear()
        // What follows is a fresh install: a new identity, made on the spot.
        identity = MultiplayerIdentity.load(from: secrets)
    }

    // MARK: - Runs

    private func wire() {
        client.onRunStart = { [weak self] info in self?.runStarted(info) }
        client.onRunEnd = { [weak self] info in self?.runEnded(info) }
        client.onLeftParty = { [weak self] _ in self?.partyLost() }
    }

    private func runStarted(_ info: RunStartInfo) {
        guard let services else { return }
        // A reconnecting player for a run this phone is already in changes nothing.
        if let run, run.runID == info.runId {
            run.resumed(info)
            return
        }
        run?.stop()
        let controller = PartyRunController(info: info, hub: self, services: services)
        run = controller
        router?.showPartyRun(controller, services: services)
    }

    private func runEnded(_ info: RunEndInfo) {
        run?.serviceEndedRun(info)
    }

    /// The run's own screens have finished with it: back to the lobby.
    func returnToLobby() {
        run?.stop()
        run = nil
        if client.isInParty {
            router?.show(.lobby)
        } else {
            router?.show(.multiplayer)
        }
    }

    private func partyLost() {
        run?.stop()
        run = nil
        router?.show(.multiplayer)
    }
}
