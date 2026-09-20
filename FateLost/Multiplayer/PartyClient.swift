import Foundation
import Observation

/// How long to wait before each attempt to get back to a party: doubling,
/// capped, and spread randomly ("full jitter") so a crowd of phones that lost
/// signal together do not all knock at the same instant.
struct ReconnectPolicy: Equatable {
    var base: Double = 0.5
    var cap: Double = 15
    var maxAttempts = 14
    /// Never retry faster than this, however the jitter falls.
    var floor: Double = 0.25

    /// Seconds to wait before attempt `attempt` (1 for the first retry).
    /// `randomUnit` is a number in 0..<1.
    func delay(forAttempt attempt: Int, randomUnit: Double) -> Double {
        let ceiling = min(cap, base * pow(2, Double(max(0, attempt - 1))))
        return max(floor, ceiling * min(max(randomUnit, 0), 1))
    }
}

/// Why the player is no longer in a party, for a message on the menu.
enum PartyNotice: Equatable {
    case kicked
    case closedByHost
    case expired
    case sessionEnded
    case replaced
    case connectionLost
    case left

    var message: String {
        switch self {
        case .kicked: return "The host removed you from the party."
        case .closedByHost: return "The host closed the party."
        case .expired: return "That party has ended."
        case .sessionEnded: return "You are no longer part of that party."
        case .replaced: return "This party was opened on another device."
        case .connectionLost: return "The connection to the party was lost."
        case .left: return "You left the party."
        }
    }
}

enum PartyConnectionState: Equatable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(PartyError)

    var isLive: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// A player's connection to their party.
///
/// It owns the lobby as the service last described it, the credential that
/// proves who this player is inside the party, and the socket. It reconnects
/// by itself, with backoff, and asks the service for the room again when it
/// does, so a dropped connection never creates a second copy of the player: the
/// service replaces the old socket for the same seat. What the game does with a
/// run lives elsewhere; this reports run starts and ends and hands over
/// gameplay frames untouched.
@MainActor
@Observable
final class PartyClient {
    /// Everything the client needs from outside, so tests can replace it.
    struct Environment {
        var api: PartyAPI
        var makeSocket: () -> PartySocket
        var baseURL: URL
        var fateID: String
        var vault: PartySessionVault?
        var sleep: (Double) async -> Void
        var randomUnit: () -> Double
        var now: () -> Date
        var policy = ReconnectPolicy()

        static func live(identity: MultiplayerIdentity, vault: PartySessionVault?) -> Environment {
            Environment(api: HTTPPartyAPI(), makeSocket: { URLSessionPartySocket() },
                        baseURL: PartyServiceConfig.baseURL, fateID: identity.fateID, vault: vault,
                        sleep: { seconds in try? await Task.sleep(for: .seconds(seconds)) },
                        randomUnit: { Double.random(in: 0..<1) }, now: { Date() })
        }
    }

    private(set) var state: PartyConnectionState = .idle
    private(set) var room: LobbyRoom?
    private(set) var myID: String?
    /// The run in progress, from the moment it starts until it ends.
    private(set) var activeRun: RunStartInfo?
    /// How the last run ended, until the next begins.
    private(set) var lastRunEnd: RunEndInfo?
    /// When the host is due back by, while they are away mid-run.
    private(set) var hostAwayUntil: Date?
    /// Why the player was returned to the menu, if they were.
    private(set) var notice: PartyNotice?
    /// The latest thing the service refused, for the screen to show.
    private(set) var lastError: PartyError?

    @ObservationIgnored var onRunStart: ((RunStartInfo) -> Void)?
    @ObservationIgnored var onRunEnd: ((RunEndInfo) -> Void)?
    @ObservationIgnored var onPeer: ((PeerNotice) -> Void)?
    /// A gameplay frame: its kind, the seat it came from (only when this
    /// player is the host receiving a client's frame), and its payload.
    @ObservationIgnored var onFrame: ((FrameKind, Int?, Data) -> Void)?
    /// The connection came back after a drop.
    @ObservationIgnored var onReconnected: (() -> Void)?
    /// The player is no longer in the party.
    @ObservationIgnored var onLeftParty: ((PartyNotice) -> Void)?

    @ObservationIgnored private var env: Environment
    @ObservationIgnored private var session: SavedPartySession?
    @ObservationIgnored private var socket: PartySocket?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private var lastHeard = Date()
    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private var hasConnectedBefore = false
    @ObservationIgnored private(set) var loadout: PartyLoadout?

    init(environment: Environment) {
        env = environment
    }

    // MARK: - Derived

    var isHost: Bool {
        guard let myID, let room else { return false }
        return room.hostId == myID
    }

    var me: LobbyMember? {
        guard let myID else { return nil }
        return room?.member(myID)
    }

    var isInParty: Bool { session != nil }
    var hasSavedSession: Bool { env.vault?.load() != nil }
    var fateID: String { env.fateID }

    /// Whether the host can start: two or more players, every guest ready
    /// and connected.
    var canStart: Bool {
        guard isHost, let room, room.phase == .lobby, room.members.count >= PartyProtocol.minPlayersToStart else {
            return false
        }
        return room.members.filter { !$0.host }.allSatisfy { $0.ready && $0.connected }
    }

    /// Why the host cannot start yet, in words.
    var startBlocker: String? {
        guard isHost, let room else { return nil }
        if room.members.count < PartyProtocol.minPlayersToStart { return "Waiting for another player" }
        if let waiting = room.members.first(where: { !$0.host && !$0.connected }) {
            return "\(waiting.name) is not connected"
        }
        if let waiting = room.members.first(where: { !$0.host && !$0.ready }) {
            return "Waiting for \(waiting.name)"
        }
        return nil
    }

    // MARK: - Entering a party

    func host(name: String, password: String?) async throws {
        try await enter { [env] in
            try await env.api.create(name: name, fateID: env.fateID, password: password)
        }
    }

    func join(code: String, name: String, password: String?) async throws {
        try await enter { [env] in
            try await env.api.join(code: code, name: name, fateID: env.fateID, password: password)
        }
    }

    private func enter(_ request: () async throws -> JoinResult) async throws {
        forgetParty()
        notice = nil
        lastError = nil
        state = .connecting
        let result: JoinResult
        do {
            result = try await request()
        } catch {
            state = .idle
            if let error = error as? PartyError { lastError = error }
            throw error
        }
        let saved = SavedPartySession(code: result.code, playerId: result.playerId, token: result.token,
                                      name: result.room.member(result.playerId)?.name ?? "")
        session = saved
        env.vault?.save(saved)
        myID = result.playerId
        room = result.room
        attempt = 0
        hasConnectedBefore = false
        openSocket()
    }

    /// Goes back into the party this phone was last in, if it is still there.
    /// The outcome arrives as state: `connected`, or the party is forgotten.
    func resumeSavedSession() {
        guard session == nil, let saved = env.vault?.load() else { return }
        session = saved
        myID = saved.playerId
        notice = nil
        attempt = 0
        hasConnectedBefore = false
        state = .connecting
        openSocket()
    }

    // MARK: - Leaving

    /// Leaves the party for good.
    func leave() {
        guard session != nil else { return }
        send(.leave)
        let farewell = socket
        socket = nil
        end(with: .left, notify: false)
        linger(farewell)
    }

    /// Host only: closes the party for everyone.
    func closeParty() {
        guard isHost else { return }
        send(.close)
        let farewell = socket
        socket = nil
        end(with: .left, notify: false)
        linger(farewell)
    }

    /// Keeps a socket open a moment longer so a last message can get out,
    /// then closes it.
    private func linger(_ farewell: PartySocket?) {
        guard let farewell else { return }
        farewell.onText = nil
        farewell.onBinary = nil
        farewell.onClose = nil
        Task { [env] in
            await env.sleep(0.5)
            farewell.close(code: 1000)
        }
    }

    /// The app came back to the front. If the connection died while it was
    /// away, or looks stale, reconnect now rather than waiting out a timer.
    func resume() {
        guard session != nil else { return }
        switch state {
        case .connected:
            if env.now().timeIntervalSince(lastHeard) > 20 {
                connectionEnded(code: 1006, httpStatus: nil)
            } else {
                socket?.send(text: "ping")
            }
        case .reconnecting, .failed:
            reconnectTask?.cancel()
            attempt = 0
            openSocket()
        case .connecting, .idle:
            break
        }
    }

    // MARK: - Lobby commands

    func setReady(_ ready: Bool) { send(.ready(ready)) }
    func startRun() { send(.start) }
    func kick(_ memberID: String) { send(.kick(memberID)) }
    func setRealm(_ realm: String) { send(.setRealm(realm)) }

    func rename(_ name: String) {
        guard let cleaned = DisplayName.clean(name) else {
            lastError = .invalidName
            return
        }
        send(.rename(cleaned))
    }

    /// Tells the service what this player brings. Remembered, so it can be
    /// sent again after a reconnect.
    func setLoadout(_ loadout: PartyLoadout) {
        self.loadout = loadout
        send(.loadout(loadout))
    }

    /// Host only: reports that the run is over. The service returns everyone
    /// to the lobby.
    func endRun(runID: String, outcome: String, summary: JSONValue?) {
        guard isHost else { return }
        send(.runEnd(runId: runID, outcome: outcome, summary: summary))
    }

    func clearError() { lastError = nil }
    func clearNotice() { notice = nil }

    // MARK: - Gameplay frames

    /// Sends a frame to the host (from a client) or to one seat / everyone
    /// (from the host, with `target`).
    func sendFrame(_ kind: FrameKind, payload: Data, target: UInt8 = PartyProtocol.targetAll) {
        var frame = Data([kind.rawValue])
        if isHost { frame.append(target) }
        frame.append(payload)
        let limit = isHost ? PartyProtocol.maxHostFrame : PartyProtocol.maxClientFrame
        guard frame.count <= limit else { return }
        socket?.send(data: frame)
    }

    // MARK: - Socket

    private func send(_ message: ClientMessage) {
        socket?.send(text: message.text)
    }

    private var socketURL: URL? {
        guard let session else { return nil }
        var components = URLComponents(url: env.baseURL.appendingPathComponent("v1/rooms/\(session.code)/ws"),
                                       resolvingAgainstBaseURL: false)
        components?.scheme = env.baseURL.scheme == "http" ? "ws" : "wss"
        return components?.url
    }

    private func openSocket() {
        guard let session, let url = socketURL else { return }
        reconnectTask?.cancel()
        socket?.onText = nil
        socket?.onBinary = nil
        socket?.onClose = nil
        socket?.close(code: 1000)

        let fresh = env.makeSocket()
        fresh.onText = { [weak self, weak fresh] text in
            guard let self, let fresh, fresh === self.socket else { return }
            self.handle(text: text)
        }
        fresh.onBinary = { [weak self, weak fresh] data in
            guard let self, let fresh, fresh === self.socket else { return }
            self.handle(binary: data)
        }
        fresh.onClose = { [weak self, weak fresh] code, status in
            guard let self, let fresh, fresh === self.socket else { return }
            self.connectionEnded(code: code, httpStatus: status)
        }
        socket = fresh
        lastHeard = env.now()
        switch state {
        case .connected, .reconnecting:
            break
        default:
            state = hasConnectedBefore ? .reconnecting(attempt: max(attempt, 1)) : .connecting
        }
        fresh.connect(url: url, token: session.token)
    }

    private func handle(text: String) {
        lastHeard = env.now()
        guard text != "pong", let message = ServerMessage.decode(text) else { return }
        switch message {
        case let .welcome(you, room):
            myID = you
            self.room = room
            let wasReconnect = hasConnectedBefore
            hasConnectedBefore = true
            attempt = 0
            state = .connected
            syncHostAway(from: room)
            startHeartbeat()
            // What this player carries is not remembered by a fresh seat.
            if let loadout, room.phase == .lobby { send(.loadout(loadout)) }
            if wasReconnect { onReconnected?() }
        case .room(let room):
            self.room = room
            syncHostAway(from: room)
        case .runStart(let info):
            activeRun = info
            lastRunEnd = nil
            onRunStart?(info)
        case .runEnd(let info):
            activeRun = nil
            lastRunEnd = info
            onRunEnd?(info)
        case let .error(code, text):
            lastError = PartyError.from(code: code, message: text)
        case .kicked:
            end(with: .kicked)
        case .left:
            end(with: .left)
        case .closed(let reason):
            end(with: reason == "expired" ? .expired : .closedByHost)
        case .replaced:
            end(with: .replaced)
        case .peer(let notice):
            onPeer?(notice)
        case .hostAway(let until):
            hostAwayUntil = Date(timeIntervalSince1970: until / 1000)
        case .hostBack:
            hostAwayUntil = nil
        case .newHost:
            break
        }
    }

    private func handle(binary data: Data) {
        lastHeard = env.now()
        guard let first = data.first, let kind = FrameKind(rawValue: first) else { return }
        // Payloads are re-based so they can be indexed from zero.
        if isHost {
            guard data.count >= 2 else { return }
            onFrame?(kind, Int(data[data.startIndex + 1]), Data(data.dropFirst(2)))
        } else {
            onFrame?(kind, nil, Data(data.dropFirst(1)))
        }
    }

    private func syncHostAway(from room: LobbyRoom) {
        if let until = room.hostGraceEndsAt {
            hostAwayUntil = Date(timeIntervalSince1970: until / 1000)
        } else {
            hostAwayUntil = nil
        }
    }

    // MARK: - Trouble

    private func connectionEnded(code: Int, httpStatus: Int?) {
        heartbeatTask?.cancel()
        socket = nil
        guard session != nil else { return }
        switch code {
        case 4001, 4003:
            end(with: code == 4003 ? .kicked : .sessionEnded)
            return
        case 4004:
            end(with: .closedByHost)
            return
        default:
            break
        }
        if let httpStatus {
            switch httpStatus {
            case 401:
                end(with: .sessionEnded)
                return
            case 404:
                end(with: .expired)
                return
            case 426:
                state = .failed(.protocolMismatch)
                return
            default:
                break
            }
        }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        attempt += 1
        guard attempt <= env.policy.maxAttempts else {
            state = .failed(.network)
            return
        }
        state = .reconnecting(attempt: attempt)
        let delay = env.policy.delay(forAttempt: attempt, randomUnit: env.randomUnit())
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self, env] in
            await env.sleep(delay)
            guard !Task.isCancelled, let self else { return }
            self.openSocket()
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self, env] in
            while !Task.isCancelled {
                await env.sleep(15)
                guard !Task.isCancelled, let self else { return }
                if self.env.now().timeIntervalSince(self.lastHeard) > 45 {
                    // Nothing heard, not even the answer to a ping: the
                    // connection is dead even if the phone has not noticed.
                    self.socket?.close(code: 1001)
                    self.connectionEnded(code: 1006, httpStatus: nil)
                    return
                }
                self.socket?.send(text: "ping")
            }
        }
    }

    /// The player is out of the party: forget it and say why.
    private func end(with reason: PartyNotice, notify: Bool = true) {
        forgetParty()
        env.vault?.clear()
        state = .idle
        notice = reason
        if notify { onLeftParty?(reason) }
    }

    private func forgetParty() {
        reconnectTask?.cancel()
        heartbeatTask?.cancel()
        socket?.onText = nil
        socket?.onBinary = nil
        socket?.onClose = nil
        socket?.close(code: 1000)
        socket = nil
        session = nil
        room = nil
        myID = nil
        activeRun = nil
        lastRunEnd = nil
        hostAwayUntil = nil
        loadout = nil
        attempt = 0
        hasConnectedBefore = false
    }
}
