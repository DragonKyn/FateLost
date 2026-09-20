import Foundation

/// What the service hands back when a player creates or joins a party.
struct JoinResult: Equatable {
    let code: String
    let playerId: String
    /// The room credential. A secret: never logged, never shown.
    let token: String
    let room: LobbyRoom
}

/// The two requests that get a player into a party. Everything after that
/// happens over the socket.
protocol PartyAPI {
    func create(name: String, fateID: String, password: String?) async throws -> JoinResult
    func join(code: String, name: String, fateID: String, password: String?) async throws -> JoinResult
}

/// Sends HTTP requests. A seam so tests can answer them without a network.
protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (body, response) = try await self.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (body, http)
    }
}

/// Talks to the party service over HTTPS. Passwords travel in the request
/// body only, never in a URL, and are never written to a log.
struct HTTPPartyAPI: PartyAPI {
    let baseURL: URL
    let transport: HTTPTransport

    init(baseURL: URL = PartyServiceConfig.baseURL, transport: HTTPTransport = URLSession.shared) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func create(name: String, fateID: String, password: String?) async throws -> JoinResult {
        try await request(path: "/v1/rooms", name: name, fateID: fateID, password: password)
    }

    func join(code: String, name: String, fateID: String, password: String?) async throws -> JoinResult {
        guard let normalised = RoomCode.normalise(code) else { throw PartyError.invalidCode }
        return try await request(path: "/v1/rooms/\(normalised)/join", name: name, fateID: fateID,
                                 password: password)
    }

    private func request(path: String, name: String, fateID: String, password: String?) async throws -> JoinResult {
        guard let cleaned = DisplayName.clean(name) else { throw PartyError.invalidName }
        var body: [String: JSONValue] = [
            "protocol": .number(Double(PartyProtocol.version)),
            "name": .string(cleaned),
            "fateId": .string(fateID),
        ]
        if let password, !password.isEmpty {
            body["password"] = .string(password)
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONEncoder().encode(JSONValue.object(body))

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw PartyError.network
        }
        guard (200..<300).contains(response.statusCode) else {
            throw Self.error(from: data, status: response.statusCode, retryAfterHeader: response.value(forHTTPHeaderField: "retry-after"))
        }
        struct Body: Decodable {
            let code: String
            let playerId: String
            let token: String
            let room: LobbyRoom
        }
        guard let parsed = try? JSONDecoder().decode(Body.self, from: data) else {
            throw PartyError.server("The party service sent something unexpected.")
        }
        return JoinResult(code: parsed.code, playerId: parsed.playerId, token: parsed.token, room: parsed.room)
    }

    /// Turns an error response into something a player can read.
    static func error(from data: Data, status: Int, retryAfterHeader: String? = nil) -> PartyError {
        if let object = try? JSONDecoder().decode(JSONValue.self, from: data),
           let inner = object["error"], let code = inner["code"]?.stringValue {
            let retry = inner["retryAfter"]?.intValue ?? Int(retryAfterHeader ?? "") ?? 0
            return PartyError.from(code: code, message: inner["message"]?.stringValue ?? "", retryAfter: retry)
        }
        if status == 429 { return .rateLimited(retryAfterSeconds: Int(retryAfterHeader ?? "") ?? 0) }
        if status == 426 { return .protocolMismatch }
        if status == 404 { return .roomNotFound }
        return .server("The party service had a problem (\(status)).")
    }
}
