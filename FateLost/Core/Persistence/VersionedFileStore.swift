import Foundation

/// On-disk wrapper that records which schema version wrote a payload.
struct SaveEnvelope<Payload: Codable>: Codable {
    let schemaVersion: Int
    let savedAt: Date
    let payload: Payload
}

/// Reads just the version, so migration can decide how to decode the rest.
private struct SaveVersionHeader: Decodable {
    let schemaVersion: Int
}

/// Outcome of loading, so callers (and tests) can tell *why* they got what
/// they got. Only `.loaded` and `.migrated` carry saved data.
enum SaveLoadResult<Payload> {
    case loaded(Payload)
    case migrated(Payload, fromVersion: Int)
    case missing
    /// The file was unreadable or from an unknown future version. It has been
    /// moved aside (never deleted) so a player's data can still be recovered.
    case recovered(reason: String, backupURL: URL?)

    var payload: Payload? {
        switch self {
        case .loaded(let payload), .migrated(let payload, _): return payload
        case .missing, .recovered: return nil
        }
    }
}

/// Versioned, atomic, corruption-tolerant JSON persistence for one payload.
///
/// - Writes are atomic, so a crash mid-save leaves the previous file intact.
/// - Older versions are passed to `migrate` to be upgraded.
/// - Corrupt or newer-than-known files are renamed aside, not overwritten, and
///   the game carries on with defaults instead of crashing.
final class VersionedFileStore<Payload: Codable> {
    typealias Migration = (_ fromVersion: Int, _ data: Data) throws -> Payload?

    let fileURL: URL
    let currentVersion: Int
    private let migrate: Migration
    private let fileManager: FileManager

    init(fileURL: URL, currentVersion: Int, fileManager: FileManager = .default,
         migrate: @escaping Migration = { _, _ in nil }) {
        self.fileURL = fileURL
        self.currentVersion = currentVersion
        self.fileManager = fileManager
        self.migrate = migrate
    }

    func load() -> SaveLoadResult<Payload> {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .missing }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            return quarantine(reason: "Unreadable: \(error.localizedDescription)")
        }

        let decoder = Self.makeDecoder()
        guard let header = try? decoder.decode(SaveVersionHeader.self, from: data) else {
            return quarantine(reason: "Missing or invalid version header")
        }

        if header.schemaVersion == currentVersion {
            do {
                return .loaded(try decoder.decode(SaveEnvelope<Payload>.self, from: data).payload)
            } catch {
                return quarantine(reason: "Corrupt payload: \(error.localizedDescription)")
            }
        }

        if header.schemaVersion > currentVersion {
            return quarantine(reason: "Saved by newer version \(header.schemaVersion)")
        }

        do {
            guard let upgraded = try migrate(header.schemaVersion, data) else {
                return quarantine(reason: "No migration from version \(header.schemaVersion)")
            }
            return .migrated(upgraded, fromVersion: header.schemaVersion)
        } catch {
            return quarantine(reason: "Migration failed: \(error.localizedDescription)")
        }
    }

    func save(_ payload: Payload, now: Date = Date()) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let envelope = SaveEnvelope(schemaVersion: currentVersion, savedAt: now, payload: payload)
        let data = try Self.makeEncoder().encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Deletes the save, and any copies of it that were moved aside as
    /// corrupt. What is left is what a fresh install has: nothing.
    func erase() {
        let directory = fileURL.deletingLastPathComponent()
        let base = fileURL.deletingPathExtension().lastPathComponent
        let suffix = fileURL.pathExtension
        let siblings = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in siblings + [fileURL] {
            let name = url.lastPathComponent
            let isBackup = name.hasPrefix(base + ".corrupt-") && url.pathExtension == suffix
            if url == fileURL || isBackup {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func quarantine(reason: String) -> SaveLoadResult<Payload> {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt-\(stamp).\(fileURL.pathExtension)")
        do {
            if fileManager.fileExists(atPath: backup.path) {
                try fileManager.removeItem(at: backup)
            }
            try fileManager.moveItem(at: fileURL, to: backup)
            return .recovered(reason: reason, backupURL: backup)
        } catch {
            return .recovered(reason: reason, backupURL: nil)
        }
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum SaveLocations {
    /// Application Support/FateLost, created on demand.
    static func directory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("FateLost", isDirectory: true)
    }
}
