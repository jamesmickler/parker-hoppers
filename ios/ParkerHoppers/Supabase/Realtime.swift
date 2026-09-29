import Foundation

/// Live updates from Supabase over a WebSocket (Supabase Realtime's Phoenix protocol).
/// Tells the app the moment someone checks in, posts or likes, so alerts pop up within a
/// second or two. The app also re-syncs every 30 s, so a dropped connection only slows things down.
@MainActor
final class Realtime {
    struct Change {
        let table: String
        let type: String // INSERT, UPDATE or DELETE
        let record: [String: Any]
    }

    private static let topic = "realtime:parker-hoppers"
    private static let tables = ["profiles", "dogs", "check_ins", "posts", "post_likes"]

    private var socket: URLSessionWebSocketTask?
    private var heartbeat: Timer?
    private var ref = 0
    private var wanted = false
    private let onChange: (Change) -> Void

    init(onChange: @escaping (Change) -> Void) {
        self.onChange = onChange
    }

    func connect(accessToken: String) {
        wanted = true
        disconnectSocket()

        var components = URLComponents(url: SupabaseConfig.url, resolvingAgainstBaseURL: false)!
        components.scheme = "wss"
        components.path = "/realtime/v1/websocket"
        components.queryItems = [
            URLQueryItem(name: "apikey", value: SupabaseConfig.key),
            URLQueryItem(name: "vsn", value: "1.0.0"),
        ]
        let socket = URLSession.shared.webSocketTask(with: components.url!)
        self.socket = socket
        socket.resume()

        send(topic: Self.topic, event: "phx_join", payload: [
            "config": [
                "broadcast": ["ack": false, "self": false],
                "presence": ["key": ""],
                "postgres_changes": Self.tables.map { ["event": "*", "schema": "public", "table": $0] },
                "private": false,
            ],
            "access_token": accessToken,
        ])
        listen(on: socket)
        heartbeat = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.send(topic: "phoenix", event: "heartbeat", payload: [:]) }
        }
    }

    /// Sign-ins expire hourly; pass the refreshed one along so the database keeps sending changes.
    func update(accessToken: String) {
        send(topic: Self.topic, event: "access_token", payload: ["access_token": accessToken])
    }

    func disconnect() {
        wanted = false
        disconnectSocket()
    }

    private func disconnectSocket() {
        heartbeat?.invalidate()
        heartbeat = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func send(topic: String, event: String, payload: [String: Any]) {
        ref += 1
        let message: [String: Any] = ["topic": topic, "event": event, "payload": payload, "ref": String(ref)]
        guard let socket, let data = try? JSONSerialization.data(withJSONObject: message),
              let text = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(text)) { _ in }
    }

    private func listen(on socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            Task { @MainActor in
                guard let self, socket === self.socket else { return }
                switch result {
                case .success(let message):
                    self.handle(message)
                    self.listen(on: socket)
                case .failure:
                    self.reconnectSoon()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .string(let text): data = text.data(using: .utf8)
        case .data(let bytes): data = bytes
        @unknown default: data = nil
        }
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["event"] as? String == "postgres_changes",
              let payload = object["payload"] as? [String: Any],
              let change = payload["data"] as? [String: Any],
              let table = change["table"] as? String,
              let type = change["type"] as? String else { return }
        onChange(Change(table: table, type: type, record: change["record"] as? [String: Any] ?? [:]))
    }

    private func reconnectSoon() {
        disconnectSocket()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, self.wanted, self.socket == nil,
                  let session = try? await SupabaseClient.shared.validSession() else { return }
            self.connect(accessToken: session.accessToken)
        }
    }
}
