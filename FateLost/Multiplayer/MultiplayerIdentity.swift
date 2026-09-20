import CryptoKit
import Foundation
import Security

/// Somewhere to keep small secrets. The real one is the Keychain; tests use
/// memory.
protocol SecretStore: AnyObject {
    func read(_ key: String) -> Data?
    @discardableResult func write(_ key: String, _ value: Data) -> Bool
    func delete(_ key: String)
}

final class MemorySecretStore: SecretStore {
    private var values: [String: Data] = [:]

    func read(_ key: String) -> Data? { values[key] }

    @discardableResult
    func write(_ key: String, _ value: Data) -> Bool {
        values[key] = value
        return true
    }

    func delete(_ key: String) { values[key] = nil }
}

/// The iOS Keychain. Items stay on this device (they are not synced or
/// included in backups) and are readable once the phone has been unlocked
/// after starting.
final class KeychainSecretStore: SecretStore {
    private let service: String

    init(service: String = "app.fatelost.multiplayer") {
        self.service = service
    }

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    func read(_ key: String) -> Data? {
        var request = query(key)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    func write(_ key: String, _ value: Data) -> Bool {
        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var add = query(key)
        add.merge(attributes) { _, new in new }
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}

/// Who this installation is, to the party service.
///
/// Two layers. The *installation secret* is 256 random bits made on this
/// phone and kept in the Keychain; it never leaves the phone and is not
/// derived from anything about the device or the player. The *Fate ID*
/// (FL-8K4P-72QM) is a meaningless public label made from a one-way hash of
/// the secret, for troubleshooting and, one day, friends. It is not a
/// credential: knowing someone's Fate ID lets you do nothing as them. What
/// authenticates a player in a party is the room credential the service
/// issues when they join, which is a separate thing again.
struct MultiplayerIdentity: Equatable {
    static let secretKey = "installation.secret"

    let fateID: String

    /// The installation's identity, made on first use.
    static func load(from store: SecretStore, randomBytes: () -> Data = MultiplayerIdentity.secureRandom) -> MultiplayerIdentity {
        var secret = store.read(secretKey)
        if secret == nil || secret?.count != 32 {
            let fresh = randomBytes()
            store.write(secretKey, fresh)
            secret = fresh
        }
        return MultiplayerIdentity(fateID: fateID(for: secret ?? Data()))
    }

    /// Forgets this installation, so the next use starts a new identity.
    static func erase(from store: SecretStore) {
        store.delete(secretKey)
    }

    static func secureRandom() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // Never happens in practice; fall back to the system generator
            // rather than an identity of zeros.
            var generator = SystemRandomNumberGenerator()
            bytes = bytes.map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        }
        return Data(bytes)
    }

    /// FL-XXXX-XXXX from the secret, using the alphabet with no look-alikes.
    static func fateID(for secret: Data) -> String {
        let digest = SHA256.hash(data: secret + Data("fatelost.fateid.v1".utf8))
        let alphabet = PartyProtocol.roomCodeAlphabet
        let symbols = digest.prefix(8).map { alphabet[Int($0) % alphabet.count] }
        let text = String(symbols)
        return "FL-\(text.prefix(4))-\(text.suffix(4))"
    }

    static func isFateID(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "FL", parts[1].count == 4, parts[2].count == 4 else { return false }
        return (parts[1] + parts[2]).allSatisfy { PartyProtocol.roomCodeAlphabet.contains($0) }
    }
}

/// The name a player has chosen to be called in parties. Kept on this phone,
/// asked for the first time multiplayer is used, and changeable any time.
struct MultiplayerPreferences: Codable, Equatable {
    var displayName: String?

    init(displayName: String? = nil) {
        self.displayName = displayName
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
    }
}

final class MultiplayerPreferencesStore {
    static let schemaVersion = 1
    private let store: VersionedFileStore<MultiplayerPreferences>
    private(set) var preferences: MultiplayerPreferences

    init(directory: URL = SaveLocations.directory()) {
        let fileStore = VersionedFileStore<MultiplayerPreferences>(
            fileURL: directory.appendingPathComponent("multiplayer.json"), currentVersion: Self.schemaVersion)
        store = fileStore
        preferences = fileStore.load().payload ?? MultiplayerPreferences()
        // Whatever was saved must still pass the rules.
        if let saved = preferences.displayName, DisplayName.clean(saved) == nil {
            preferences.displayName = nil
        }
    }

    var displayName: String? { preferences.displayName }

    /// Saves a name. Returns the cleaned name, or nil if it cannot be used.
    @discardableResult
    func setDisplayName(_ name: String) -> String? {
        guard let cleaned = DisplayName.clean(name) else { return nil }
        preferences.displayName = cleaned
        try? store.save(preferences)
        return cleaned
    }

    func erase() {
        store.erase()
        preferences = MultiplayerPreferences()
    }
}

/// The credential for the party a player is in, kept so that killing the
/// app or losing signal does not lose their seat. It lives in the Keychain,
/// because it is what authenticates them to the party.
struct SavedPartySession: Codable, Equatable {
    let code: String
    let playerId: String
    let token: String
    let name: String
}

final class PartySessionVault {
    private static let key = "party.session"
    private let store: SecretStore

    init(store: SecretStore) {
        self.store = store
    }

    func load() -> SavedPartySession? {
        guard let data = store.read(Self.key) else { return nil }
        return try? JSONDecoder().decode(SavedPartySession.self, from: data)
    }

    func save(_ session: SavedPartySession) {
        if let data = try? JSONEncoder().encode(session) {
            store.write(Self.key, data)
        }
    }

    func clear() {
        store.delete(Self.key)
    }
}
