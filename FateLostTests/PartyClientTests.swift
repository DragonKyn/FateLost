import Foundation
import XCTest
@testable import FateLost

// MARK: - Test doubles

final class MockPartySocket: PartySocket {
    var onText: ((String) -> Void)?
    var onBinary: ((Data) -> Void)?
    var onClose: ((Int, Int?) -> Void)?

    private(set) var connectedURL: URL?
    private(set) var connectedToken: String?
    private(set) var sentTexts: [String] = []
    private(set) var sentFrames: [Data] = []
    private(set) var closeCodes: [Int] = []

    func connect(url: URL, token: String) {
        connectedURL = url
        connectedToken = token
    }

    func send(text: String) { sentTexts.append(text) }
    func send(data: Data) { sentFrames.append(data) }
    func close(code: Int) { closeCodes.append(code) }

    // Scripting.
    func deliver(_ value: JSONValue) {
        let data = try! JSONEncoder().encode(value)
        onText?(String(decoding: data, as: UTF8.self))
    }

    func deliverText(_ text: String) { onText?(text) }
    func drop(code: Int = 1006, status: Int? = nil) { onClose?(code, status) }

    /// The messages the client sent, by their `t` field.
    var sentTypes: [String] {
        sentTexts.compactMap { text in
            guard let value = try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)) else { return nil }
            return value["t"]?.stringValue
        }
    }
}

final class SocketFactory {
    private(set) var sockets: [MockPartySocket] = []
    var latest: MockPartySocket { sockets[sockets.count - 1] }

    func make() -> PartySocket {
        let socket = MockPartySocket()
        sockets.append(socket)
        return socket
    }
}

struct ScriptedAPI: PartyAPI {
    var onCreate: (String, String, String?) async throws -> JoinResult = { _, _, _ in throw PartyError.network }
    var onJoin: (String, String, String, String?) async throws -> JoinResult = { _, _, _, _ in throw PartyError.network }

    func create(name: String, fateID: String, password: String?) async throws -> JoinResult {
        try await onCreate(name, fateID, password)
    }

    func join(code: String, name: String, fateID: String, password: String?) async throws -> JoinResult {
        try await onJoin(code, name, fateID, password)
    }
}

/// A clock the test winds by hand: `sleep` waits until `fire` is called.
@MainActor
final class ManualClock {
    private(set) var requested: [Double] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(_ seconds: Double) async {
        requested.append(seconds)
        await withCheckedContinuation { waiters.append($0) }
    }

    func fire() {
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }
}

enum Lobby {
    static func member(_ id: String, _ name: String, slot: Int, host: Bool = false, ready: Bool = false,
                       connected: Bool = true) -> LobbyMember {
        LobbyMember(id: id, name: name, fateId: "FL-AAAA-BBBB", slot: slot, host: host, ready: ready,
                    connected: connected, weapon: "sword", hero: nil)
    }

    static func room(code: String = "F7K2Q9", hostId: String = "host1", members: [LobbyMember],
                     phase: LobbyPhase = .lobby, runNumber: Int = 0, hasPassword: Bool = false) -> LobbyRoom {
        LobbyRoom(code: code, protocolVersion: 1, hostId: hostId, phase: phase, runNumber: runNumber,
                  hasPassword: hasPassword, maxPlayers: 4, realm: "ashenWilds", members: members, run: nil,
                  lastRun: nil, hostGraceEndsAt: nil)
    }

    static func message(_ type: String, _ fields: [String: JSONValue] = [:]) -> JSONValue {
        var body = fields
        body["t"] = .string(type)
        return .object(body)
    }

    static func welcome(you: String, room: LobbyRoom) -> JSONValue {
        message("welcome", ["you": .string(you), "room": JSONValue.from(room)!])
    }

    static func roomUpdate(_ room: LobbyRoom) -> JSONValue {
        message("room", ["room": JSONValue.from(room)!])
    }
}

@MainActor
final class PartyClientHarness {
    let sockets = SocketFactory()
    let clock = ManualClock()
    let secrets = MemorySecretStore()
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    var api = ScriptedAPI()
    lazy var vault = PartySessionVault(store: secrets)
    var client: PartyClient!

    init(policy: ReconnectPolicy = ReconnectPolicy()) {
        rewire(policy: policy)
    }

    /// Rebuilds the client with the current scripted API.
    func rewire(policy: ReconnectPolicy = ReconnectPolicy()) {
        let environment = PartyClient.Environment(
            api: api, makeSocket: { [sockets] in sockets.make() },
            baseURL: URL(string: "https://party.example")!, fateID: "FL-8K4P-72QM", vault: vault,
            sleep: { [clock] seconds in await clock.sleep(seconds) }, randomUnit: { 0.5 }, now: { [unowned self] in self.now },
            policy: policy)
        client = PartyClient(environment: environment)
    }

    func settle() async {
        for _ in 0..<30 { await Task.yield() }
    }

    /// A harness whose host has created `ABCDEF` and been welcomed.
    static func hosting(members: [LobbyMember]? = nil) async throws -> PartyClientHarness {
        let harness = PartyClientHarness()
        let lobby = members ?? [Lobby.member("host1", "Jesse", slot: 0, host: true)]
        let room = Lobby.room(members: lobby)
        harness.api.onCreate = { _, _, _ in
            JoinResult(code: "F7K2Q9", playerId: "host1", token: "secret-token-value", room: room)
        }
        harness.rewire()
        try await harness.client.host(name: "Jesse", password: nil)
        harness.sockets.latest.deliver(Lobby.welcome(you: "host1", room: room))
        await harness.settle()
        return harness
    }

    static func joined(as id: String = "guest1") async throws -> PartyClientHarness {
        let harness = PartyClientHarness()
        let room = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true),
                                        Lobby.member(id, "Whitney", slot: 1)])
        harness.api.onJoin = { _, _, _, _ in
            JoinResult(code: "F7K2Q9", playerId: id, token: "guest-token-value", room: room)
        }
        harness.rewire()
        try await harness.client.join(code: "F7K2Q9", name: "Whitney", password: nil)
        harness.sockets.latest.deliver(Lobby.welcome(you: id, room: room))
        await harness.settle()
        return harness
    }
}

// MARK: - Names, codes, identity

final class DisplayNameTests: XCTestCase {
    func testAcceptsOrdinaryNamesAndTidiesThem() {
        XCTAssertEqual(DisplayName.clean("Jesse"), "Jesse")
        XCTAssertEqual(DisplayName.clean("  Jesse    Lee "), "Jesse Lee")
        XCTAssertEqual(DisplayName.clean("Renée"), "Renée")
        XCTAssertEqual(DisplayName.clean("e\u{0301}"), "\u{00E9}", "composed characters are normalised")
        XCTAssertEqual(DisplayName.clean(String(repeating: "A", count: 16)), String(repeating: "A", count: 16))
        XCTAssertNotNil(DisplayName.clean("Whitney \u{1F409}"))
        XCTAssertNotNil(DisplayName.clean("小明"))
    }

    func testRejectsTheUnusable() {
        for bad in ["", "   ", "\u{200B}\u{200B}", "a\tb", "a\u{0000}b", "a\u{202E}b", "\u{FEFF}x",
                    String(repeating: "A", count: 17), "\u{2028}"] {
            XCTAssertNil(DisplayName.clean(bad), "\(bad.unicodeScalars.map { $0.value }) should be refused")
        }
    }

    func testAnInvisibleNameIsNotAName() {
        XCTAssertNil(DisplayName.clean("\u{3164}"), "a filler that draws nothing")
        XCTAssertNil(DisplayName.clean(" \u{00A0} "))
    }
}

final class RoomCodeTests: XCTestCase {
    func testNormalisesWhatAPersonTypes() {
        XCTAssertEqual(RoomCode.normalise(" f7k2q9 "), "F7K2Q9")
        XCTAssertEqual(RoomCode.normalise("F7K-2Q9"), "F7K2Q9")
        XCTAssertEqual(RoomCode.normalise("f7k 2q9"), "F7K2Q9")
    }

    func testRefusesWhatCannotBeACode() {
        XCTAssertNil(RoomCode.normalise("F7K2Q"))
        XCTAssertNil(RoomCode.normalise("F7K2Q90"))
        XCTAssertNil(RoomCode.normalise("F7K2Q0"), "no zero")
        XCTAssertNil(RoomCode.normalise("F7K2QO"), "no letter O")
        XCTAssertNil(RoomCode.normalise("F7K2QI"), "no letter I")
        XCTAssertNil(RoomCode.normalise("F7K2QL"), "no letter L")
        XCTAssertNil(RoomCode.normalise(""))
    }

    func testTheAlphabetHasNoLookAlikes() {
        for banned in "01OIL" {
            XCTAssertFalse(PartyProtocol.roomCodeAlphabet.contains(banned))
        }
        XCTAssertEqual(PartyProtocol.roomCodeAlphabet.count, 31)
    }

    func testCodesAreShownInTwoHalves() {
        XCTAssertEqual(RoomCode.spaced("F7K2Q9"), "F7K 2Q9")
    }
}

final class MultiplayerIdentityTests: XCTestCase {
    func testAnInstallationHasAStableFateID() {
        let store = MemorySecretStore()
        let first = MultiplayerIdentity.load(from: store)
        let second = MultiplayerIdentity.load(from: store)
        XCTAssertEqual(first, second)
        XCTAssertTrue(MultiplayerIdentity.isFateID(first.fateID), first.fateID)
        XCTAssertEqual(store.read(MultiplayerIdentity.secretKey)?.count, 32)
    }

    func testDifferentInstallationsAreDifferent() {
        let a = MultiplayerIdentity.load(from: MemorySecretStore())
        let b = MultiplayerIdentity.load(from: MemorySecretStore())
        XCTAssertNotEqual(a.fateID, b.fateID)
    }

    func testTheFateIDRevealsNothingAboutTheSecret() {
        let secret = Data(repeating: 7, count: 32)
        let id = MultiplayerIdentity.fateID(for: secret)
        XCTAssertFalse(id.contains(secret.base64EncodedString()))
        XCTAssertEqual(id, MultiplayerIdentity.fateID(for: secret), "it is derived, so it is stable")
        XCTAssertNotEqual(id, MultiplayerIdentity.fateID(for: Data(repeating: 8, count: 32)))
    }

    func testAMissingOrDamagedSecretIsReplaced() {
        let store = MemorySecretStore()
        store.write(MultiplayerIdentity.secretKey, Data([1, 2, 3]))
        let identity = MultiplayerIdentity.load(from: store)
        XCTAssertTrue(MultiplayerIdentity.isFateID(identity.fateID))
        XCTAssertEqual(store.read(MultiplayerIdentity.secretKey)?.count, 32)
    }

    func testErasingStartsANewIdentity() {
        let store = MemorySecretStore()
        let before = MultiplayerIdentity.load(from: store)
        MultiplayerIdentity.erase(from: store)
        XCTAssertNotEqual(MultiplayerIdentity.load(from: store).fateID, before.fateID)
    }

    func testFateIDFormat() {
        XCTAssertTrue(MultiplayerIdentity.isFateID("FL-8K4P-72QM"))
        XCTAssertFalse(MultiplayerIdentity.isFateID("fl-8k4p-72qm"))
        XCTAssertFalse(MultiplayerIdentity.isFateID("FL-0K4P-72QM"))
        XCTAssertFalse(MultiplayerIdentity.isFateID("FL-8K4P"))
    }

    func testTheDisplayNameIsSavedAndValidated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MultiplayerPreferencesStore(directory: directory)
        XCTAssertNil(store.displayName)
        XCTAssertNil(store.setDisplayName("\u{200B}"))
        XCTAssertEqual(store.setDisplayName("  Jesse "), "Jesse")
        let reloaded = MultiplayerPreferencesStore(directory: directory)
        XCTAssertEqual(reloaded.displayName, "Jesse")
        reloaded.erase()
        XCTAssertNil(MultiplayerPreferencesStore(directory: directory).displayName)
    }

    func testARoomCredentialIsKeptInTheVaultAndForgotten() {
        let vault = PartySessionVault(store: MemorySecretStore())
        XCTAssertNil(vault.load())
        vault.save(SavedPartySession(code: "F7K2Q9", playerId: "p", token: "t", name: "Jesse"))
        XCTAssertEqual(vault.load()?.code, "F7K2Q9")
        vault.clear()
        XCTAssertNil(vault.load())
    }
}

// MARK: - Messages

final class PartyMessageTests: XCTestCase {
    func testTheClientSpeaksAgreedJSON() {
        XCTAssertEqual(ClientMessage.ready(true).text, #"{"ready":true,"t":"ready"}"#)
        XCTAssertEqual(ClientMessage.start.text, #"{"t":"start"}"#)
        XCTAssertEqual(ClientMessage.kick("abc").text, #"{"t":"kick","target":"abc"}"#)
        XCTAssertEqual(ClientMessage.rename("Jesse").text, #"{"name":"Jesse","t":"rename"}"#)
        XCTAssertEqual(ClientMessage.setRealm("ashenWilds").text, #"{"realm":"ashenWilds","t":"setRealm"}"#)
        XCTAssertEqual(ClientMessage.leave.text, #"{"t":"leave"}"#)
        XCTAssertEqual(ClientMessage.close.text, #"{"t":"close"}"#)
        let end = ClientMessage.runEnd(runId: "abc", outcome: "defeated", summary: .object(["wave": .number(7)]))
        XCTAssertEqual(end.text, #"{"outcome":"defeated","runId":"abc","summary":{"wave":7},"t":"runEnd"}"#)
    }

    func testALoadoutRoundTripsThroughJSON() throws {
        let loadout = PartyLoadout(weapon: "bow", hero: ["build": .string("lithe")], legacy: ["a-1", "b-2"])
        let text = ClientMessage.loadout(loadout).text
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        XCTAssertEqual(value["t"]?.stringValue, "loadout")
        XCTAssertEqual(value["loadout"]?.decoded(as: PartyLoadout.self), loadout)
    }

    func testEveryServerMessageIsUnderstood() throws {
        let room = Lobby.room(members: [Lobby.member("h", "Jesse", slot: 0, host: true)])
        let welcome = Lobby.welcome(you: "h", room: room)
        XCTAssertEqual(ServerMessage.decode(String(decoding: try JSONEncoder().encode(welcome), as: UTF8.self)),
                       .welcome(you: "h", room: room))
        XCTAssertEqual(ServerMessage.decode(#"{"t":"kicked"}"#), .kicked)
        XCTAssertEqual(ServerMessage.decode(#"{"t":"left"}"#), .left)
        XCTAssertEqual(ServerMessage.decode(#"{"t":"replaced"}"#), .replaced)
        XCTAssertEqual(ServerMessage.decode(#"{"t":"hostBack"}"#), .hostBack)
        XCTAssertEqual(ServerMessage.decode(#"{"t":"closed","reason":"expired"}"#), .closed(reason: "expired"))
        XCTAssertEqual(ServerMessage.decode(#"{"t":"newHost","id":"abc"}"#), .newHost(id: "abc"))
        XCTAssertEqual(ServerMessage.decode(#"{"t":"hostAway","until":1234}"#), .hostAway(until: 1234))
        XCTAssertEqual(ServerMessage.decode(#"{"t":"peer","id":"x","slot":2,"event":"disconnected"}"#),
                       .peer(PeerNotice(id: "x", slot: 2, event: .disconnected)))
        XCTAssertEqual(ServerMessage.decode(#"{"t":"error","code":"not_ready","message":"Kevin is not ready."}"#),
                       .error(code: "not_ready", message: "Kevin is not ready."))
        XCTAssertEqual(ServerMessage.decode(#"{"t":"runEnd","runId":"r","outcome":"defeated","summary":{"wave":3}}"#),
                       .runEnd(RunEndInfo(runId: "r", outcome: "defeated", summary: .object(["wave": .number(3)]))))
    }

    func testARunStartCarriesTheRoster() throws {
        let text = """
        {"t":"runStart","resumed":false,"runId":"r1","runNumber":2,"seed":"18446744073709551615","realm":"ashenWilds",
         "hostId":"h","you":"g","roster":[{"id":"h","name":"Jesse","fateId":"FL-AAAA-BBBB","slot":0,"weapon":"sword",
         "hero":{"build":"lithe"},"legacy":["a","b"]},{"id":"g","name":"Whitney","fateId":"FL-CCCC-DDDD","slot":1,
         "weapon":"bow","hero":null}]}
        """
        guard case .runStart(let info)? = ServerMessage.decode(text) else { return XCTFail("not understood") }
        XCTAssertEqual(info.seedValue, UInt64.max, "a 64-bit seed survives as text")
        XCTAssertEqual(info.roster.count, 2)
        XCTAssertEqual(info.roster[0].legacy, ["a", "b"])
        XCTAssertNil(info.roster[1].legacy)
        XCTAssertEqual(info.myEntry?.name, "Whitney")
        XCTAssertEqual(info.runNumber, 2)
    }

    func testUnknownAndBrokenMessagesAreIgnored() {
        XCTAssertNil(ServerMessage.decode("not json"))
        XCTAssertNil(ServerMessage.decode(#"{"t":"teleport"}"#))
        XCTAssertNil(ServerMessage.decode(#"{"no":"type"}"#))
        XCTAssertNil(ServerMessage.decode(#"{"t":"welcome"}"#))
    }

    func testServiceErrorsBecomePlayerFacingWords() {
        XCTAssertEqual(PartyError.from(code: "wrong_password", message: ""), .wrongPassword)
        XCTAssertEqual(PartyError.from(code: "room_full", message: ""), .roomFull)
        XCTAssertEqual(PartyError.from(code: "rate_limited", message: "", retryAfter: 30), .rateLimited(retryAfterSeconds: 30))
        XCTAssertTrue(PartyError.rateLimited(retryAfterSeconds: 30).message.contains("30"))
        XCTAssertEqual(PartyError.from(code: "mystery", message: "Odd."), .server("Odd."))
        for error in [PartyError.roomNotFound, .roomFull, .wrongPassword, .passwordRequired, .runInProgress,
                      .protocolMismatch, .unauthorized, .invalidName, .invalidCode, .notEnoughPlayers, .network] {
            XCTAssertFalse(error.message.isEmpty)
        }
    }
}

// MARK: - The HTTP requests

private final class ScriptedTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var status = 200
    var body = Data()
    var headers: [String: String] = [:]
    var fail = false

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if fail { throw URLError(.notConnectedToInternet) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        return (body, response)
    }
}

final class HTTPPartyAPITests: XCTestCase {
    private func success(code: String = "F7K2Q9") -> Data {
        let room = Lobby.room(code: code, members: [Lobby.member("host1", "Jesse", slot: 0, host: true)])
        let value = JSONValue.object(["code": .string(code), "playerId": .string("host1"), "token": .string("tok"),
                                      "room": JSONValue.from(room)!])
        return try! JSONEncoder().encode(value)
    }

    func testCreatingAPartySendsTheNameAndPasswordInTheBodyOnly() async throws {
        let transport = ScriptedTransport()
        transport.status = 201
        transport.body = success()
        let api = HTTPPartyAPI(baseURL: URL(string: "https://party.example")!, transport: transport)
        let result = try await api.create(name: " Jesse ", fateID: "FL-8K4P-72QM", password: "hunter22")
        XCTAssertEqual(result.code, "F7K2Q9")
        XCTAssertEqual(result.token, "tok")

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://party.example/v1/rooms")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertFalse(request.url!.absoluteString.contains("hunter22"), "a password never goes in a URL")
        let body = try JSONDecoder().decode(JSONValue.self, from: try XCTUnwrap(request.httpBody))
        XCTAssertEqual(body["name"]?.stringValue, "Jesse")
        XCTAssertEqual(body["password"]?.stringValue, "hunter22")
        XCTAssertEqual(body["fateId"]?.stringValue, "FL-8K4P-72QM")
        XCTAssertEqual(body["protocol"]?.intValue, PartyProtocol.version)
    }

    func testJoiningNormalisesTheCodeAndOmitsAnEmptyPassword() async throws {
        let transport = ScriptedTransport()
        transport.body = success()
        let api = HTTPPartyAPI(baseURL: URL(string: "https://party.example")!, transport: transport)
        _ = try await api.join(code: "f7k-2q9", name: "Whitney", fateID: "FL-8K4P-72QM", password: "")
        XCTAssertEqual(transport.requests.first?.url?.path, "/v1/rooms/F7K2Q9/join")
        let body = try JSONDecoder().decode(JSONValue.self, from: try XCTUnwrap(transport.requests.first?.httpBody))
        XCTAssertNil(body["password"])
    }

    func testABadNameOrCodeNeverLeavesThePhone() async {
        let transport = ScriptedTransport()
        let api = HTTPPartyAPI(baseURL: URL(string: "https://party.example")!, transport: transport)
        do {
            _ = try await api.create(name: "\u{200B}", fateID: "FL-8K4P-72QM", password: nil)
            XCTFail("should have thrown")
        } catch { XCTAssertEqual(error as? PartyError, .invalidName) }
        do {
            _ = try await api.join(code: "12", name: "Jesse", fateID: "FL-8K4P-72QM", password: nil)
            XCTFail("should have thrown")
        } catch { XCTAssertEqual(error as? PartyError, .invalidCode) }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testServiceRefusalsAreMapped() async {
        let cases: [(Int, String, PartyError)] = [
            (404, "room_not_found", .roomNotFound), (409, "room_full", .roomFull),
            (403, "wrong_password", .wrongPassword), (401, "password_required", .passwordRequired),
            (409, "run_in_progress", .runInProgress), (426, "protocol_mismatch", .protocolMismatch),
            (429, "rate_limited", .rateLimited(retryAfterSeconds: 12)),
        ]
        for (status, code, expected) in cases {
            let transport = ScriptedTransport()
            transport.status = status
            transport.body = Data(#"{"error":{"code":"\#(code)","message":"m","retryAfter":12}}"#.utf8)
            let api = HTTPPartyAPI(baseURL: URL(string: "https://party.example")!, transport: transport)
            do {
                _ = try await api.join(code: "F7K2Q9", name: "Jesse", fateID: "FL-8K4P-72QM", password: nil)
                XCTFail("should have thrown for \(code)")
            } catch {
                XCTAssertEqual(error as? PartyError, expected, code)
            }
        }
    }

    func testNoNetworkIsReportedAsSuch() async {
        let transport = ScriptedTransport()
        transport.fail = true
        let api = HTTPPartyAPI(baseURL: URL(string: "https://party.example")!, transport: transport)
        do {
            _ = try await api.create(name: "Jesse", fateID: "FL-8K4P-72QM", password: nil)
            XCTFail("should have thrown")
        } catch {
            XCTAssertEqual(error as? PartyError, .network)
        }
    }

    func testAnUnexpectedBodyIsAServerProblemNotACrash() async {
        let transport = ScriptedTransport()
        transport.body = Data("<html>oops</html>".utf8)
        let api = HTTPPartyAPI(baseURL: URL(string: "https://party.example")!, transport: transport)
        do {
            _ = try await api.create(name: "Jesse", fateID: "FL-8K4P-72QM", password: nil)
            XCTFail("should have thrown")
        } catch {
            guard case .server? = error as? PartyError else { return XCTFail("\(error)") }
        }
    }
}

final class ReconnectPolicyTests: XCTestCase {
    func testDelaysDoubleThenStopAtTheCap() {
        let policy = ReconnectPolicy(base: 1, cap: 10, maxAttempts: 10, floor: 0)
        XCTAssertEqual(policy.delay(forAttempt: 1, randomUnit: 1), 1)
        XCTAssertEqual(policy.delay(forAttempt: 2, randomUnit: 1), 2)
        XCTAssertEqual(policy.delay(forAttempt: 3, randomUnit: 1), 4)
        XCTAssertEqual(policy.delay(forAttempt: 4, randomUnit: 1), 8)
        XCTAssertEqual(policy.delay(forAttempt: 5, randomUnit: 1), 10)
        XCTAssertEqual(policy.delay(forAttempt: 30, randomUnit: 1), 10)
    }

    func testJitterSpreadsAttemptsBetweenTheFloorAndTheCeiling() {
        let policy = ReconnectPolicy(base: 1, cap: 10, maxAttempts: 10, floor: 0.25)
        XCTAssertEqual(policy.delay(forAttempt: 3, randomUnit: 0), 0.25, "never faster than the floor")
        XCTAssertEqual(policy.delay(forAttempt: 3, randomUnit: 0.5), 2)
        let samples = Set((0..<50).map { policy.delay(forAttempt: 4, randomUnit: Double($0) / 50) })
        XCTAssertGreaterThan(samples.count, 10, "a crowd does not retry in lockstep")
        XCTAssertLessThanOrEqual(samples.max() ?? 0, 8)
    }
}

// MARK: - The client

@MainActor
final class PartyClientTests: XCTestCase {
    func testHostingCreatesAPartyAndConnectsWithTheCredentialOutOfTheURL() async throws {
        let harness = try await PartyClientHarness.hosting()
        let client = harness.client!
        XCTAssertEqual(client.state, .connected)
        XCTAssertTrue(client.isHost)
        XCTAssertEqual(client.room?.code, "F7K2Q9")
        XCTAssertEqual(client.me?.name, "Jesse")

        let socket = harness.sockets.latest
        XCTAssertEqual(socket.connectedURL?.absoluteString, "wss://party.example/v1/rooms/F7K2Q9/ws")
        XCTAssertEqual(socket.connectedToken, "secret-token-value")
        XCTAssertFalse(socket.connectedURL!.absoluteString.contains("secret-token-value"))
        XCTAssertEqual(harness.vault.load()?.token, "secret-token-value", "kept in the vault for a rejoin")
    }

    func testJoiningEntersTheLobbyAsAGuest() async throws {
        let harness = try await PartyClientHarness.joined()
        let client = harness.client!
        XCTAssertEqual(client.state, .connected)
        XCTAssertFalse(client.isHost)
        XCTAssertEqual(client.room?.members.map { $0.name }, ["Jesse", "Whitney"])
        XCTAssertEqual(client.me?.name, "Whitney")
    }

    func testAFailedJoinLeavesThePlayerOnTheMenuWithAReason() async {
        let harness = PartyClientHarness()
        harness.api.onJoin = { _, _, _, _ in throw PartyError.wrongPassword }
        harness.rewire()
        do {
            try await harness.client.join(code: "F7K2Q9", name: "Whitney", password: "nope")
            XCTFail("should have thrown")
        } catch {
            XCTAssertEqual(error as? PartyError, .wrongPassword)
        }
        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertEqual(harness.client.lastError, .wrongPassword)
        XCTAssertTrue(harness.sockets.sockets.isEmpty)
        XCTAssertNil(harness.vault.load())
    }

    func testTheLobbyFollowsWhatTheServiceSays() async throws {
        let harness = try await PartyClientHarness.hosting()
        let updated = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true),
                                           Lobby.member("g1", "Whitney", slot: 1, ready: true),
                                           Lobby.member("g2", "Kevin", slot: 2)])
        harness.sockets.latest.deliver(Lobby.roomUpdate(updated))
        XCTAssertEqual(harness.client.room?.members.count, 3)
        XCTAssertFalse(harness.client.canStart)
        XCTAssertEqual(harness.client.startBlocker, "Waiting for Kevin")

        let everyoneReady = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true),
                                                 Lobby.member("g1", "Whitney", slot: 1, ready: true),
                                                 Lobby.member("g2", "Kevin", slot: 2, ready: true)])
        harness.sockets.latest.deliver(Lobby.roomUpdate(everyoneReady))
        XCTAssertTrue(harness.client.canStart)
        XCTAssertNil(harness.client.startBlocker)
    }

    func testTheHostCannotStartAlone() async throws {
        let harness = try await PartyClientHarness.hosting()
        XCTAssertFalse(harness.client.canStart)
        XCTAssertEqual(harness.client.startBlocker, "Waiting for another player")
    }

    func testAGuestNeverSeesStartAsAvailable() async throws {
        let harness = try await PartyClientHarness.joined()
        XCTAssertFalse(harness.client.canStart)
        XCTAssertNil(harness.client.startBlocker)
    }

    func testTheHostWaitsForADisconnectedGuest() async throws {
        let harness = try await PartyClientHarness.hosting()
        let room = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true),
                                        Lobby.member("g1", "Whitney", slot: 1, ready: true, connected: false)])
        harness.sockets.latest.deliver(Lobby.roomUpdate(room))
        XCTAssertFalse(harness.client.canStart)
        XCTAssertEqual(harness.client.startBlocker, "Whitney is not connected")
    }

    func testLobbyCommandsGoOutAsAgreedMessages() async throws {
        let harness = try await PartyClientHarness.hosting()
        let socket = harness.sockets.latest
        harness.client.setReady(true)
        harness.client.startRun()
        harness.client.kick("g1")
        harness.client.setRealm("hollowWood")
        harness.client.rename("  Jess  ")
        harness.client.setLoadout(PartyLoadout(weapon: "bow", hero: nil, legacy: ["a"]))
        XCTAssertEqual(socket.sentTypes, ["ready", "start", "kick", "setRealm", "rename", "loadout"])
        XCTAssertTrue(socket.sentTexts.contains(#"{"name":"Jess","t":"rename"}"#), "names are cleaned before sending")
    }

    func testABadRenameIsRefusedOnThePhone() async throws {
        let harness = try await PartyClientHarness.hosting()
        harness.client.rename("\u{200B}")
        XCTAssertEqual(harness.client.lastError, .invalidName)
        XCTAssertFalse(harness.sockets.latest.sentTypes.contains("rename"))
    }

    func testARunStartsAndEndsAndTheSamePartyContinues() async throws {
        let harness = try await PartyClientHarness.joined()
        var started: [RunStartInfo] = []
        var ended: [RunEndInfo] = []
        harness.client.onRunStart = { started.append($0) }
        harness.client.onRunEnd = { ended.append($0) }
        let socket = harness.sockets.latest

        socket.deliverText("""
        {"t":"runStart","resumed":false,"runId":"r1","runNumber":1,"seed":"42","realm":"ashenWilds","hostId":"host1",
         "you":"guest1","roster":[{"id":"host1","name":"Jesse","fateId":"FL-AAAA-BBBB","slot":0,"weapon":"sword","hero":null},
         {"id":"guest1","name":"Whitney","fateId":"FL-CCCC-DDDD","slot":1,"weapon":"bow","hero":null}]}
        """)
        XCTAssertEqual(started.map { $0.runId }, ["r1"])
        XCTAssertEqual(harness.client.activeRun?.seedValue, 42)

        socket.deliverText(#"{"t":"runEnd","runId":"r1","outcome":"defeated","summary":{"wave":4}}"#)
        XCTAssertEqual(ended.map { $0.outcome }, ["defeated"])
        XCTAssertNil(harness.client.activeRun)
        XCTAssertEqual(harness.client.lastRunEnd?.runId, "r1")

        let lobby = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true),
                                         Lobby.member("guest1", "Whitney", slot: 1)], runNumber: 1)
        socket.deliver(Lobby.roomUpdate(lobby))
        XCTAssertEqual(harness.client.room?.code, "F7K2Q9", "the same room code")
        XCTAssertEqual(harness.client.state, .connected)
        XCTAssertNotNil(harness.vault.load(), "still seated, credential kept")
    }

    func testOnlyTheHostCanEndARun() async throws {
        let guest = try await PartyClientHarness.joined()
        guest.client.endRun(runID: "r", outcome: "defeated", summary: nil)
        XCTAssertFalse(guest.sockets.latest.sentTypes.contains("runEnd"))

        let host = try await PartyClientHarness.hosting()
        host.client.endRun(runID: "r", outcome: "defeated", summary: nil)
        XCTAssertTrue(host.sockets.latest.sentTypes.contains("runEnd"))
    }

    func testGameplayFramesAreFramedByRole() async throws {
        let host = try await PartyClientHarness.hosting()
        host.client.sendFrame(.snapshot, payload: Data([9, 9]), target: 2)
        host.client.sendFrame(.events, payload: Data([7]))
        XCTAssertEqual(host.sockets.latest.sentFrames, [Data([2, 2, 9, 9]), Data([4, 0xFF, 7])])

        let guest = try await PartyClientHarness.joined()
        guest.client.sendFrame(.input, payload: Data([1, 2, 3]))
        XCTAssertEqual(guest.sockets.latest.sentFrames, [Data([1, 1, 2, 3])], "a guest sends the kind, then the payload")
    }

    func testAGuestFrameIsTooBigToSendWhenItExceedsTheLimit() async throws {
        let guest = try await PartyClientHarness.joined()
        guest.client.sendFrame(.input, payload: Data(repeating: 0, count: PartyProtocol.maxClientFrame))
        XCTAssertTrue(guest.sockets.latest.sentFrames.isEmpty)
    }

    func testFramesArriveWithTheirSeatForTheHostAndWithoutForGuests() async throws {
        let host = try await PartyClientHarness.hosting()
        var received: [(FrameKind, Int?, Data)] = []
        host.client.onFrame = { received.append(($0, $1, $2)) }
        host.sockets.latest.onBinary?(Data([1, 2, 10, 20]))
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0].0, .input)
        XCTAssertEqual(received[0].1, 2)
        XCTAssertEqual(received[0].2, Data([10, 20]))
        XCTAssertEqual(received[0].2[0], 10, "the payload can be indexed from zero")

        let guest = try await PartyClientHarness.joined()
        var guestReceived: [(FrameKind, Int?, Data)] = []
        guest.client.onFrame = { guestReceived.append(($0, $1, $2)) }
        guest.sockets.latest.onBinary?(Data([2, 5, 6, 7]))
        XCTAssertEqual(guestReceived.count, 1)
        XCTAssertEqual(guestReceived[0].0, .snapshot)
        XCTAssertNil(guestReceived[0].1)
        XCTAssertEqual(guestReceived[0].2[0], 5)
        // Junk is ignored.
        guest.sockets.latest.onBinary?(Data([99, 1]))
        guest.sockets.latest.onBinary?(Data())
        XCTAssertEqual(guestReceived.count, 1)
    }

    func testAHostWhoWentQuietIsNoticed() async throws {
        let guest = try await PartyClientHarness.joined()
        guest.sockets.latest.deliverText(#"{"t":"hostAway","until":1800000045000}"#)
        XCTAssertEqual(guest.client.hostAwayUntil, Date(timeIntervalSince1970: 1_800_000_045))
        guest.sockets.latest.deliverText(#"{"t":"hostBack"}"#)
        XCTAssertNil(guest.client.hostAwayUntil)
    }

    // MARK: Reconnecting

    func testADroppedConnectionReconnectsToTheSameSeatWithBackoff() async throws {
        let harness = try await PartyClientHarness.hosting()
        var reconnects = 0
        harness.client.onReconnected = { reconnects += 1 }
        let first = harness.sockets.latest
        first.drop()
        XCTAssertEqual(harness.client.state, .reconnecting(attempt: 1))
        XCTAssertNotNil(harness.client.room, "the lobby stays on screen while reconnecting")

        // The wait is between the floor and the first ceiling.
        await harness.settle()
        let wait = try XCTUnwrap(harness.clock.requested.last)
        XCTAssertGreaterThanOrEqual(wait, 0.25)
        XCTAssertLessThanOrEqual(wait, 0.5)
        XCTAssertEqual(harness.sockets.sockets.count, 1, "nothing until the wait is over")

        harness.clock.fire()
        await harness.settle()
        XCTAssertEqual(harness.sockets.sockets.count, 2)
        XCTAssertEqual(harness.sockets.latest.connectedToken, "secret-token-value", "the same credential, so the same seat")

        let room = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true)])
        harness.sockets.latest.deliver(Lobby.welcome(you: "host1", room: room))
        XCTAssertEqual(harness.client.state, .connected)
        XCTAssertEqual(reconnects, 1)
        XCTAssertEqual(harness.client.room?.members.count, 1, "no duplicate player")
    }

    func testRepeatedFailuresBackOffAndEventuallyGiveUp() async throws {
        var policy = ReconnectPolicy()
        policy.maxAttempts = 3
        let harness = PartyClientHarness()
        let room = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true)])
        harness.api.onCreate = { _, _, _ in
            JoinResult(code: "F7K2Q9", playerId: "host1", token: "secret-token-value", room: room)
        }
        harness.rewire(policy: policy)
        try await harness.client.host(name: "Jesse", password: nil)
        harness.sockets.latest.deliver(Lobby.welcome(you: "host1", room: room))

        for attempt in 1...3 {
            harness.sockets.latest.drop()
            XCTAssertEqual(harness.client.state, .reconnecting(attempt: attempt))
            await harness.settle()
            harness.clock.fire()
            await harness.settle()
        }
        harness.sockets.latest.drop()
        XCTAssertEqual(harness.client.state, .failed(.network))
    }

    func testResumingAFailedConnectionTriesAgainAtOnce() async throws {
        var policy = ReconnectPolicy()
        policy.maxAttempts = 1
        let harness = PartyClientHarness()
        harness.api.onCreate = { _, _, _ in
            JoinResult(code: "F7K2Q9", playerId: "host1", token: "t-t-t-t-t-t",
                       room: Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true)]))
        }
        harness.rewire(policy: policy)
        try await harness.client.host(name: "Jesse", password: nil)
        harness.sockets.latest.drop()
        await harness.settle()
        harness.clock.fire()
        await harness.settle()
        harness.sockets.latest.drop()
        XCTAssertEqual(harness.client.state, .failed(.network))
        let before = harness.sockets.sockets.count
        harness.client.resume()
        XCTAssertEqual(harness.sockets.sockets.count, before + 1)
        XCTAssertEqual(harness.client.state, .connecting)
    }

    func testAStaleConnectionIsRecycledWhenTheAppReturns() async throws {
        let harness = try await PartyClientHarness.hosting()
        harness.now = harness.now.addingTimeInterval(60)
        harness.client.resume()
        XCTAssertEqual(harness.client.state, .reconnecting(attempt: 1))
    }

    func testAHealthyConnectionIsJustPingedWhenTheAppReturns() async throws {
        let harness = try await PartyClientHarness.hosting()
        harness.client.resume()
        XCTAssertEqual(harness.client.state, .connected)
        XCTAssertTrue(harness.sockets.latest.sentTexts.contains("ping"))
    }

    func testTheHeartbeatNoticesAConnectionThatWentSilent() async throws {
        let harness = try await PartyClientHarness.hosting()
        await harness.settle()
        XCTAssertEqual(harness.clock.requested.last, 15, "the heartbeat is waiting")
        harness.now = harness.now.addingTimeInterval(50)
        harness.clock.fire()
        await harness.settle()
        XCTAssertEqual(harness.client.state, .reconnecting(attempt: 1))
    }

    func testTheHeartbeatPingsAHealthyConnection() async throws {
        let harness = try await PartyClientHarness.hosting()
        await harness.settle()
        harness.now = harness.now.addingTimeInterval(15)
        harness.clock.fire()
        await harness.settle()
        XCTAssertTrue(harness.sockets.latest.sentTexts.contains("ping"))
        XCTAssertEqual(harness.client.state, .connected)
    }

    func testAnAnswerToAPingIsIgnored() async throws {
        let harness = try await PartyClientHarness.hosting()
        harness.sockets.latest.deliverText("pong")
        XCTAssertEqual(harness.client.state, .connected)
    }

    // MARK: Being sent away

    func testBeingKickedEndsThePartyWithoutReconnecting() async throws {
        let harness = try await PartyClientHarness.joined()
        var left: PartyNotice?
        harness.client.onLeftParty = { left = $0 }
        let socket = harness.sockets.latest
        socket.deliverText(#"{"t":"kicked"}"#)
        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertEqual(harness.client.notice, .kicked)
        XCTAssertEqual(left, .kicked)
        XCTAssertNil(harness.vault.load(), "the old credential is forgotten")
        XCTAssertNil(harness.client.room)
        // The close that follows must not start a reconnect.
        socket.drop(code: 4003)
        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertEqual(harness.sockets.sockets.count, 1)
    }

    func testTheHostClosingThePartyEndsItForEveryone() async throws {
        let harness = try await PartyClientHarness.joined()
        harness.sockets.latest.deliverText(#"{"t":"closed","reason":"closed"}"#)
        XCTAssertEqual(harness.client.notice, .closedByHost)
        XCTAssertEqual(harness.client.state, .idle)
    }

    func testAnExpiredPartyIsReportedAsSuch() async throws {
        let harness = try await PartyClientHarness.joined()
        harness.sockets.latest.deliverText(#"{"t":"closed","reason":"expired"}"#)
        XCTAssertEqual(harness.client.notice, .expired)
    }

    func testARefusedUpgradeMeansTheSeatIsGone() async throws {
        let harness = try await PartyClientHarness.joined()
        harness.sockets.latest.drop()
        await harness.settle()
        harness.clock.fire()
        await harness.settle()
        harness.sockets.latest.drop(code: 1006, status: 401)
        XCTAssertEqual(harness.client.notice, .sessionEnded)
        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertNil(harness.vault.load())
    }

    func testAPartyThatNoLongerExistsIsReported() async throws {
        let harness = try await PartyClientHarness.joined()
        harness.sockets.latest.drop(code: 1006, status: 404)
        XCTAssertEqual(harness.client.notice, .expired)
    }

    func testAnOutdatedAppIsToldToUpdateNotToKeepRetrying() async throws {
        let harness = try await PartyClientHarness.joined()
        harness.sockets.latest.drop(code: 1006, status: 426)
        XCTAssertEqual(harness.client.state, .failed(.protocolMismatch))
        XCTAssertEqual(harness.sockets.sockets.count, 1)
    }

    func testAnotherDeviceTakingTheSeatEndsThisOne() async throws {
        let harness = try await PartyClientHarness.joined()
        harness.sockets.latest.deliverText(#"{"t":"replaced"}"#)
        XCTAssertEqual(harness.client.notice, .replaced)
        XCTAssertEqual(harness.client.state, .idle)
    }

    func testLeavingSaysGoodbyeAndForgetsTheParty() async throws {
        let harness = try await PartyClientHarness.joined()
        let socket = harness.sockets.latest
        harness.client.leave()
        XCTAssertEqual(socket.sentTypes.last, "leave")
        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertNil(harness.client.room)
        XCTAssertNil(harness.vault.load())
        XCTAssertFalse(harness.client.isInParty)
    }

    func testOnlyTheHostCanCloseTheParty() async throws {
        let guest = try await PartyClientHarness.joined()
        guest.client.closeParty()
        XCTAssertFalse(guest.sockets.latest.sentTypes.contains("close"))
        XCTAssertTrue(guest.client.isInParty)

        let host = try await PartyClientHarness.hosting()
        let socket = host.sockets.latest
        host.client.closeParty()
        XCTAssertEqual(socket.sentTypes.last, "close")
        XCTAssertFalse(host.client.isInParty)
    }

    // MARK: Coming back to a party

    func testAPartyIsRememberedAcrossARelaunch() async throws {
        let first = try await PartyClientHarness.hosting()
        XCTAssertTrue(first.client.hasSavedSession)

        // A new launch: a new client over the same vault.
        let relaunched = PartyClientHarness()
        relaunched.vault.save(try XCTUnwrap(first.vault.load()))
        relaunched.client.resumeSavedSession()
        XCTAssertEqual(relaunched.client.state, .connecting)
        XCTAssertEqual(relaunched.sockets.latest.connectedToken, "secret-token-value")
        XCTAssertEqual(relaunched.sockets.latest.connectedURL?.path, "/v1/rooms/F7K2Q9/ws")
        let room = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true)])
        relaunched.sockets.latest.deliver(Lobby.welcome(you: "host1", room: room))
        XCTAssertEqual(relaunched.client.state, .connected)
        XCTAssertTrue(relaunched.client.isHost)
    }

    func testASavedPartyThatIsGoneIsForgotten() async throws {
        let harness = PartyClientHarness()
        harness.vault.save(SavedPartySession(code: "F7K2Q9", playerId: "p", token: "t", name: "Jesse"))
        harness.client.resumeSavedSession()
        harness.sockets.latest.drop(code: 1006, status: 404)
        XCTAssertNil(harness.vault.load())
        XCTAssertEqual(harness.client.state, .idle)
    }

    func testTheLoadoutIsSentAgainToAFreshConnection() async throws {
        let harness = try await PartyClientHarness.hosting()
        harness.client.setLoadout(PartyLoadout(weapon: "bow", hero: nil, legacy: []))
        harness.sockets.latest.drop()
        await harness.settle()
        harness.clock.fire()
        await harness.settle()
        let room = Lobby.room(members: [Lobby.member("host1", "Jesse", slot: 0, host: true)])
        harness.sockets.latest.deliver(Lobby.welcome(you: "host1", room: room))
        XCTAssertTrue(harness.sockets.latest.sentTypes.contains("loadout"))
    }
}
