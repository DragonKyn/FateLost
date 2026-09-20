import Foundation

/// The wire protocol between the app and the party service. It mirrors
/// `worker/src/protocol.ts`, and `docs/MULTIPLAYER_PROTOCOL.md` describes it.
///
/// Control traffic (the lobby) is JSON text; gameplay traffic is binary
/// frames the server relays without reading (see `NetCodec`).
enum PartyProtocol {
    /// Bumped whenever a change would confuse an older app.
    static let version = 1
    static let maxPlayers = 4
    static let minPlayersToStart = 2
    static let roomCodeLength = 6
    /// No 0/O, 1/I or L: read aloud or off a screen, none can be mistaken.
    static let roomCodeAlphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    static let nameMaxLength = 16
    static let passwordMaxLength = 64
    static let maxClientFrame = 4096
    static let maxHostFrame = 24_000
    /// One host frame carrying several (see `PartyClient.sendBatch`).
    static let maxHostBatch = 64_000
    static let maxBatchEntries = 24
    /// Target byte meaning "every other member".
    static let targetAll: UInt8 = 0xFF
}

/// The kinds of binary frame, the first byte of every one.
enum FrameKind: UInt8 {
    /// Client to host: movement and presses.
    case input = 1
    /// Host to client: a picture of the world.
    case snapshot = 2
    /// Client to host: a build command.
    case command = 3
    /// Host to client: things that happened.
    case events = 4
    /// Host to client: the client's own build and progress.
    case selfState = 5
    /// Host to the room: several frames in one, each for its own seat. The
    /// room counts one message however many players it reaches, which is what
    /// keeps a busy party inside the free plan.
    case batch = 6
}

/// The service's address. Production unless a developer build points it at
/// staging.
enum PartyServiceConfig {
    static let production = URL(string: "https://fate-lost-multiplayer.wickedstudiosca.workers.dev")!
    static let staging = URL(string: "https://fate-lost-multiplayer-staging.wickedstudiosca.workers.dev")!
    static let overrideKey = "FateLostPartyServiceURL"

    static var baseURL: URL {
        #if FATELOST_DEVTOOLS
        if let text = UserDefaults.standard.string(forKey: overrideKey), let url = URL(string: text),
           url.scheme == "https" {
            return url
        }
        #endif
        return production
    }
}

// MARK: - Room codes

enum RoomCode {
    /// What a person typed, made into a code, or nil if it cannot be one.
    static func normalise(_ text: String) -> String? {
        let cleaned = text.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard cleaned.count == PartyProtocol.roomCodeLength else { return nil }
        guard cleaned.allSatisfy({ PartyProtocol.roomCodeAlphabet.contains($0) }) else { return nil }
        return cleaned
    }

    /// How a code is shown: unchanged, six characters, easy to read aloud.
    static func spaced(_ code: String) -> String {
        guard code.count == PartyProtocol.roomCodeLength else { return code }
        let middle = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<middle]) \(code[middle...])"
    }
}

// MARK: - Display names

/// The rules for a multiplayer name, the same on the phone and on the
/// server: visible, short, and never made of characters that cannot be seen.
enum DisplayName {
    static let maxLength = PartyProtocol.nameMaxLength

    /// The cleaned name, or nil if it cannot be used.
    static func clean(_ input: String) -> String? {
        guard input.unicodeScalars.count <= maxLength * 4 else { return nil }
        let normalised = input.precomposedStringWithCanonicalMapping
        // Control, formatting, unassigned, private-use, surrogate and
        // line/paragraph separators: they let a name look empty or spoof another.
        for scalar in normalised.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .control, .format, .unassigned, .privateUse, .surrogate, .lineSeparator, .paragraphSeparator:
                return nil
            default:
                continue
            }
        }
        // A few letters and marks that are drawn as nothing at all.
        let blankLetters: Set<UInt32> = [0x3164, 0x115F, 0x1160, 0xFFA0, 0x2800, 0x17B4, 0x17B5, 0x034F]
        if normalised.unicodeScalars.contains(where: { blankLetters.contains($0.value) }) { return nil }
        var collapsed = ""
        var previousWasSpace = false
        for scalar in normalised.unicodeScalars {
            if scalar.properties.isWhitespace {
                if !previousWasSpace { collapsed.unicodeScalars.append(" ") }
                previousWasSpace = true
            } else {
                collapsed.unicodeScalars.append(scalar)
                previousWasSpace = false
            }
        }
        let trimmed = collapsed.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.unicodeScalars.count <= maxLength else { return nil }
        let hasVisible = trimmed.unicodeScalars.contains { scalar in
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
                 .decimalNumber, .letterNumber, .otherNumber,
                 .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol,
                 .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
                 .initialPunctuation, .finalPunctuation, .otherPunctuation:
                return true
            default:
                return false
            }
        }
        return hasVisible ? trimmed : nil
    }

    static func isValid(_ input: String) -> Bool {
        clean(input) != nil
    }
}

// MARK: - JSON

/// Any JSON value, for the parts of a message the app does not need to look
/// inside (a hero's look, a run summary).
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let value) = self { return value[key] }
        return nil
    }

    /// Any `Encodable`, as JSON.
    static func from<T: Encodable>(_ value: T) -> JSONValue? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    /// Back into a `Decodable`.
    func decoded<T: Decodable>(as type: T.Type) -> T? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - The room as members see it

enum LobbyPhase: String, Codable, Equatable {
    case lobby
    case inRun
}

struct LobbyMember: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    let fateId: String
    let slot: Int
    var host: Bool
    var ready: Bool
    var connected: Bool
    var weapon: String
    var hero: [String: JSONValue]?
}

struct LobbyRoom: Codable, Equatable {
    struct Run: Codable, Equatable {
        let runId: String
        let seed: String
        let startedAt: Double
    }

    struct LastRun: Codable, Equatable {
        let runId: String
        let outcome: String
        let summary: JSONValue?
    }

    let code: String
    let protocolVersion: Int
    let hostId: String
    var phase: LobbyPhase
    var runNumber: Int
    let hasPassword: Bool
    let maxPlayers: Int
    var realm: String
    var members: [LobbyMember]
    var run: Run?
    var lastRun: LastRun?
    var hostGraceEndsAt: Double?

    enum CodingKeys: String, CodingKey {
        case code
        case protocolVersion = "protocol"
        case hostId, phase, runNumber, hasPassword, maxPlayers, realm, members, run, lastRun, hostGraceEndsAt
    }

    func member(_ id: String) -> LobbyMember? {
        members.first { $0.id == id }
    }

    var host: LobbyMember? { member(hostId) }
}

/// What every member is told when a run begins (or, on a reconnect, resumes).
struct RunStartInfo: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let id: String
        let name: String
        let fateId: String
        let slot: Int
        let weapon: String
        let hero: [String: JSONValue]?
        /// Only the host is told what each player owns.
        let legacy: [String]?
    }

    let resumed: Bool
    let runId: String
    let runNumber: Int
    let seed: String
    let realm: String
    let hostId: String
    let you: String
    let roster: [Entry]

    var seedValue: UInt64 { UInt64(seed) ?? 0 }
    var myEntry: Entry? { roster.first { $0.id == you } }
}

struct RunEndInfo: Equatable {
    let runId: String
    let outcome: String
    let summary: JSONValue?
}

enum PeerEvent: String, Equatable {
    case connected
    case disconnected
    case left
}

struct PeerNotice: Equatable {
    let id: String
    let slot: Int
    let event: PeerEvent
}

// MARK: - Messages

enum ServerMessage: Equatable {
    case welcome(you: String, room: LobbyRoom)
    case room(LobbyRoom)
    case runStart(RunStartInfo)
    case runEnd(RunEndInfo)
    case error(code: String, message: String)
    case kicked
    case left
    case replaced
    case closed(reason: String)
    case peer(PeerNotice)
    case hostAway(until: Double)
    case hostBack
    case newHost(id: String)

    /// Reads one text frame from the service, or nil if it is not one we know.
    static func decode(_ text: String) -> ServerMessage? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONDecoder().decode(JSONValue.self, from: data),
              let type = object["t"]?.stringValue else { return nil }
        let decoder = JSONDecoder()
        switch type {
        case "welcome":
            struct Body: Decodable { let you: String; let room: LobbyRoom }
            guard let body = try? decoder.decode(Body.self, from: data) else { return nil }
            return .welcome(you: body.you, room: body.room)
        case "room":
            struct Body: Decodable { let room: LobbyRoom }
            guard let body = try? decoder.decode(Body.self, from: data) else { return nil }
            return .room(body.room)
        case "runStart":
            guard let info = try? decoder.decode(RunStartInfo.self, from: data) else { return nil }
            return .runStart(info)
        case "runEnd":
            guard let runId = object["runId"]?.stringValue, let outcome = object["outcome"]?.stringValue else {
                return nil
            }
            return .runEnd(RunEndInfo(runId: runId, outcome: outcome, summary: object["summary"]))
        case "error":
            return .error(code: object["code"]?.stringValue ?? "unknown",
                          message: object["message"]?.stringValue ?? "Something went wrong.")
        case "kicked": return .kicked
        case "left": return .left
        case "replaced": return .replaced
        case "closed": return .closed(reason: object["reason"]?.stringValue ?? "closed")
        case "peer":
            guard let id = object["id"]?.stringValue, let slot = object["slot"]?.intValue,
                  let event = object["event"]?.stringValue.flatMap(PeerEvent.init(rawValue:)) else { return nil }
            return .peer(PeerNotice(id: id, slot: slot, event: event))
        case "hostAway":
            guard case .number(let until)? = object["until"] else { return nil }
            return .hostAway(until: until)
        case "hostBack": return .hostBack
        case "newHost":
            guard let id = object["id"]?.stringValue else { return nil }
            return .newHost(id: id)
        default:
            return nil
        }
    }
}

/// What the app sends over the socket as text.
enum ClientMessage: Equatable {
    case ready(Bool)
    case loadout(PartyLoadout)
    case rename(String)
    case setRealm(String)
    case start
    case kick(String)
    case close
    case leave
    case runEnd(runId: String, outcome: String, summary: JSONValue?)

    var text: String {
        var body: [String: JSONValue]
        switch self {
        case .ready(let ready):
            body = ["t": .string("ready"), "ready": .bool(ready)]
        case .loadout(let loadout):
            body = ["t": .string("loadout"), "loadout": JSONValue.from(loadout) ?? .null]
        case .rename(let name):
            body = ["t": .string("rename"), "name": .string(name)]
        case .setRealm(let realm):
            body = ["t": .string("setRealm"), "realm": .string(realm)]
        case .start:
            body = ["t": .string("start")]
        case .kick(let target):
            body = ["t": .string("kick"), "target": .string(target)]
        case .close:
            body = ["t": .string("close")]
        case .leave:
            body = ["t": .string("leave")]
        case let .runEnd(runId, outcome, summary):
            body = ["t": .string("runEnd"), "runId": .string(runId), "outcome": .string(outcome),
                    "summary": summary ?? .null]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(JSONValue.object(body)) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// What a player brings to a party: their weapon, their look and what they
/// own. The host builds their hero from it.
struct PartyLoadout: Codable, Equatable {
    var weapon: String
    var hero: [String: JSONValue]?
    /// Legacy node ids, plus a few pseudo-ids for mastery and codex rewards.
    var legacy: [String]
}

// MARK: - Errors

/// Why a request to the service, or the connection, did not work, in words
/// a player can act on.
enum PartyError: Error, Equatable {
    case roomNotFound
    case roomFull
    case wrongPassword
    case passwordRequired
    case runInProgress
    case rateLimited(retryAfterSeconds: Int)
    case protocolMismatch
    case unauthorized
    case invalidName
    case invalidCode
    case forbidden(String)
    case notReady(String)
    case notEnoughPlayers
    case network
    case server(String)

    var message: String {
        switch self {
        case .roomNotFound: return "No party has that code. It may have ended."
        case .roomFull: return "That party is full."
        case .wrongPassword: return "That password is not right."
        case .passwordRequired: return "This party needs a password."
        case .runInProgress: return "That party is mid-run. Try again when they are back in the lobby."
        case .rateLimited(let seconds):
            return seconds > 0 ? "Too many tries. Wait \(seconds) seconds and try again."
                : "Too many tries. Wait a moment and try again."
        case .protocolMismatch: return "This version of Fate Lost cannot play with the party service. Update the game."
        case .unauthorized: return "You are no longer part of that party."
        case .invalidName: return "That name cannot be used."
        case .invalidCode: return "A party code is six letters and numbers."
        case .forbidden(let text): return text
        case .notReady(let text): return text
        case .notEnoughPlayers: return "A run needs at least two players."
        case .network: return "Could not reach the party service. Check your connection."
        case .server(let text): return text
        }
    }

    /// Maps a service error code to what the player should be told.
    static func from(code: String, message: String, retryAfter: Int = 0) -> PartyError {
        switch code {
        case "room_not_found": return .roomNotFound
        case "room_full": return .roomFull
        case "wrong_password": return .wrongPassword
        case "password_required": return .passwordRequired
        case "run_in_progress": return .runInProgress
        case "rate_limited": return .rateLimited(retryAfterSeconds: retryAfter)
        case "protocol_mismatch": return .protocolMismatch
        case "unauthorized": return .unauthorized
        case "forbidden": return .forbidden(message)
        case "not_ready": return .notReady(message)
        case "not_enough_players": return .notEnoughPlayers
        default: return .server(message)
        }
    }
}
