import XCTest
@testable import FateLost

final class VersionedFileStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FateLostTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private struct Sample: Codable, Equatable {
        var name: String
        var level: Int
    }

    private func store(version: Int = 2,
                       migrate: @escaping VersionedFileStore<Sample>.Migration = { _, _ in nil })
        -> VersionedFileStore<Sample> {
        VersionedFileStore(fileURL: directory.appendingPathComponent("sample.json"),
                           currentVersion: version, migrate: migrate)
    }

    func testMissingFileReportsMissing() {
        guard case .missing = store().load() else {
            return XCTFail("Expected .missing")
        }
    }

    func testRoundTrip() throws {
        let sample = Sample(name: "Adventurer", level: 12)
        try store().save(sample)
        XCTAssertEqual(store().load().payload, sample)
    }

    func testCorruptFileIsQuarantinedNotDeleted() throws {
        let url = directory.appendingPathComponent("sample.json")
        try Data("{ not json".utf8).write(to: url)

        guard case .recovered(_, let backup) = store().load() else {
            return XCTFail("Expected .recovered")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let backupURL = try XCTUnwrap(backup)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testFutureVersionIsNotOverwrittenOrMisread() throws {
        try store(version: 9).save(Sample(name: "Future", level: 99))
        guard case .recovered = store(version: 2).load() else {
            return XCTFail("A newer save must not be decoded by an older build")
        }
    }

    func testOlderVersionIsMigrated() throws {
        struct LegacySample: Codable { var name: String }
        try VersionedFileStore<LegacySample>(fileURL: directory.appendingPathComponent("sample.json"),
                                             currentVersion: 1).save(LegacySample(name: "Old"))

        let migrating = store(version: 2) { version, data in
            XCTAssertEqual(version, 1)
            let old = try VersionedFileStore<LegacySample>.makeDecoder()
                .decode(SaveEnvelope<LegacySample>.self, from: data)
            return Sample(name: old.payload.name, level: 1)
        }
        guard case .migrated(let upgraded, let fromVersion) = migrating.load() else {
            return XCTFail("Expected .migrated")
        }
        XCTAssertEqual(fromVersion, 1)
        XCTAssertEqual(upgraded, Sample(name: "Old", level: 1))
    }
}

final class GameSettingsTests: XCTestCase {
    func testMissingKeysFallBackToDefaults() throws {
        let partial = Data(#"{ "musicVolume": 0.25 }"#.utf8)
        let settings = try JSONDecoder().decode(GameSettings.self, from: partial)
        XCTAssertEqual(settings.musicVolume, 0.25)
        XCTAssertEqual(settings.hapticsEnabled, GameSettings.defaults.hapticsEnabled)
        XCTAssertEqual(settings.cameraShakeEnabled, GameSettings.defaults.cameraShakeEnabled)
    }

    func testEffectiveVolumeAppliesMaster() {
        var settings = GameSettings()
        settings.masterVolume = 0.5
        settings.musicVolume = 0.5
        XCTAssertEqual(settings.effectiveMusicVolume, 0.25, accuracy: 1e-9)
    }
}
