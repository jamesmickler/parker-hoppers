import Foundation
import Security

/// The same Supabase project as the website (web/config.js). Both values are meant to be
/// public; what each person can read or change is enforced by the rules in
/// supabase/migrations/. Never put the secret key or the database password in the app.
enum SupabaseConfig {
    static let url = URL(string: "https://dndbyhphjvumqkjtuncn.supabase.co")!
    static let key = "sb_publishable_CPvPGu-xoE7FlLkOmzgpNg_UMLeWgnA"
}

struct SupabaseError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

/// A small Supabase client covering what Park Hoppers needs: name-only (anonymous) sign-in,
/// reading and writing rows, and uploading photos. Live updates are in Realtime.swift.
@MainActor
final class SupabaseClient {
    static let shared = SupabaseClient()

    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userID: String
    }

    private(set) var session: Session? = Keychain.load()
    private var refreshing: Task<Session, Error>?

    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseTimestamp(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
            }
            return date
        }
        return decoder
    }()

    // MARK: Auth

    func signInAnonymously() async throws -> Session {
        let data = try await request("POST", "auth/v1/signup", json: ["data": [String: String]()], signedIn: false)
        return try store(sessionFrom: data)
    }

    /// The current session, refreshed first if it's about to expire.
    func validSession() async throws -> Session {
        guard let session else { throw SupabaseError(status: 401, message: "Not signed in") }
        if session.expiresAt.timeIntervalSinceNow > 60 { return session }
        if let refreshing { return try await refreshing.value }
        let task = Task { () throws -> Session in
            let data = try await request("POST", "auth/v1/token?grant_type=refresh_token",
                                         json: ["refresh_token": session.refreshToken], signedIn: false)
            return try store(sessionFrom: data)
        }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value
    }

    func signOut() {
        session = nil
        Keychain.delete()
    }

    private func store(sessionFrom data: Data) throws -> Session {
        struct Response: Decodable {
            struct User: Decodable { let id: String }
            let accessToken: String
            let refreshToken: String
            let expiresIn: Double
            let user: User
        }
        let response = try decoder.decode(Response.self, from: data)
        let session = Session(accessToken: response.accessToken, refreshToken: response.refreshToken,
                              expiresAt: .now.addingTimeInterval(response.expiresIn), userID: response.user.id)
        self.session = session
        Keychain.save(session)
        return session
    }

    // MARK: Rows

    /// Reads rows, e.g. `select("dogs", "select=id,name&order=created_at")`.
    func select<Row: Decodable>(_ table: String, _ query: String) async throws -> [Row] {
        let data = try await request("GET", "rest/v1/\(table)?\(query)")
        return try decoder.decode([Row].self, from: data)
    }

    /// Adds a row. With `onConflict`, replaces the existing row that has the same value in that column.
    func insert(_ table: String, _ row: [String: Any], onConflict: String? = nil) async throws {
        let path = onConflict.map { "rest/v1/\(table)?on_conflict=\($0)" } ?? "rest/v1/\(table)"
        let prefer = onConflict == nil ? "return=minimal" : "resolution=merge-duplicates,return=minimal"
        _ = try await request("POST", path, json: row, prefer: prefer)
    }

    /// Deletes rows matching a filter, e.g. `delete("posts", "id=eq.\(id)")`.
    func delete(_ table: String, _ filter: String) async throws {
        _ = try await request("DELETE", "rest/v1/\(table)?\(filter)")
    }

    // MARK: Server functions

    /// Runs one of the project's Edge Functions (e.g. "notify-arrival") as the signed-in person.
    func invokeFunction(_ name: String) async throws {
        _ = try await request("POST", "functions/v1/\(name)", json: [String: String]())
    }

    // MARK: Photos

    /// Uploads a JPEG into the signed-in person's folder and returns its public link.
    func uploadPhoto(_ jpeg: Data) async throws -> URL {
        let session = try await validSession()
        let path = "\(session.userID)/\(UUID().uuidString.lowercased()).jpg"
        _ = try await request("POST", "storage/v1/object/photos/\(path)", body: jpeg, contentType: "image/jpeg")
        return SupabaseConfig.url.appending(path: "storage/v1/object/public/photos/\(path)")
    }

    // MARK: Plumbing

    private func request(_ method: String, _ path: String, json: Any? = nil, body: Data? = nil,
                         contentType: String = "application/json", prefer: String? = nil,
                         signedIn: Bool = true) async throws -> Data {
        var request = URLRequest(url: URL(string: path, relativeTo: SupabaseConfig.url)!)
        request.httpMethod = method
        request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
        if signedIn {
            let token = try await validSession().accessToken
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if let body {
            request.httpBody = body
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = object?["msg"] ?? object?["message"] ?? object?["error_description"] ?? object?["error"]
            throw SupabaseError(status: status, message: message as? String ?? "Server error \(status)")
        }
        return data
    }
}

/// Postgres timestamps have microseconds ("2026-09-28T23:44:07.355065+00:00"), which the
/// standard parser won't take, so trim them to milliseconds first.
func parseTimestamp(_ text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let trimmed = text.replacingOccurrences(of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
    if let date = formatter.date(from: trimmed) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
}

/// Keeps the sign-in in the iPhone's Keychain rather than in plain app storage.
private enum Keychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.parkerhoppers.session",
        kSecAttrAccount as String: "supabase",
    ]

    static func load() -> SupabaseClient.Session? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SupabaseClient.Session.self, from: data)
    }

    static func save(_ session: SupabaseClient.Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        delete()
        var item = query
        item[kSecValueData as String] = data
        // Readable after first unlock, so a check-in can finish while the phone is in a pocket.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
