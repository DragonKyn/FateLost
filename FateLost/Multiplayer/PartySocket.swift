import Foundation

/// One WebSocket to the party service. A seam so the client can be tested
/// with a scripted socket.
protocol PartySocket: AnyObject {
    var onText: ((String) -> Void)? { get set }
    var onBinary: ((Data) -> Void)? { get set }
    /// Called once when the connection ends: the close code (1006 when it
    /// dropped or never opened) and, if the upgrade itself was refused, the
    /// HTTP status that refused it.
    var onClose: ((_ code: Int, _ httpStatus: Int?) -> Void)? { get set }
    func connect(url: URL, token: String)
    func send(text: String)
    func send(data: Data)
    func close(code: Int)
}

/// The real socket, over `URLSessionWebSocketTask`, always `wss://` in
/// production. The room credential goes in a header, never in the URL.
final class URLSessionPartySocket: NSObject, PartySocket, URLSessionWebSocketDelegate {
    var onText: ((String) -> Void)?
    var onBinary: ((Data) -> Void)?
    var onClose: ((Int, Int?) -> Void)?

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var finished = false

    func connect(url: URL, token: String) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(String(PartyProtocol.version), forHTTPHeaderField: "X-Fate-Protocol")
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: .main)
        self.session = session
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = 128 * 1024
        self.task = task
        task.resume()
        listen(to: task)
    }

    func send(text: String) {
        task?.send(.string(text)) { _ in }
    }

    func send(data: Data) {
        task?.send(.data(data)) { _ in }
    }

    func close(code: Int) {
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code) ?? .normalClosure
        task?.cancel(with: closeCode, reason: nil)
        finish(code: code, httpStatus: nil)
    }

    private func listen(to task: URLSessionWebSocketTask) {
        task.receive { [weak self, weak task] result in
            guard let self, let task, task === self.task, !self.finished else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text): self.onText?(text)
                case .data(let data): self.onBinary?(data)
                @unknown default: break
                }
                self.listen(to: task)
            case .failure:
                let status = (task.response as? HTTPURLResponse)?.statusCode
                self.finish(code: task.closeCode.rawValue == 0 ? 1006 : task.closeCode.rawValue,
                            httpStatus: status.flatMap { $0 >= 400 ? $0 : nil })
            }
        }
    }

    private func finish(code: Int, httpStatus: Int?) {
        guard !finished else { return }
        finished = true
        session?.invalidateAndCancel()
        session = nil
        task = nil
        onClose?(code, httpStatus)
        onText = nil
        onBinary = nil
        onClose = nil
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard webSocketTask === task else { return }
        finish(code: closeCode.rawValue == 0 ? 1005 : closeCode.rawValue, httpStatus: nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard task === self.task, error != nil else { return }
        let status = (task.response as? HTTPURLResponse)?.statusCode
        finish(code: 1006, httpStatus: status.flatMap { $0 >= 400 ? $0 : nil })
    }
}
