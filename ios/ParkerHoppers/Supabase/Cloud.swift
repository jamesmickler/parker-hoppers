import Foundation

/// Everything real, from the shared database: the same tables the website uses.
struct CloudSnapshot {
    var profiles: [String: Person] = [:]
    var dogs: [String: Dog] = [:]
    var checkIns: [CheckIn] = []
    var posts: [Post] = []
    var reportedPostIDs: Set<String> = []
}

/// Reads and writes Park Hoppers data in Supabase.
@MainActor
enum Cloud {
    private static var db: SupabaseClient { .shared }

    private struct ProfileRow: Decodable { let id: String; let name: String }
    private struct DogRow: Decodable {
        let id: String; let ownerId: String; let name: String; let breed: String; let color: String; let photoUrl: String?
        let size: String?; let comfort: String?
    }
    private struct CheckInRow: Decodable { let userId: String; let parkId: String; let dogIds: [String]; let arrivedAt: Date }
    private struct PostRow: Decodable {
        let id: String; let authorId: String; let dogId: String?; let parkId: String?
        let caption: String; let photoUrl: String?; let createdAt: Date
    }
    private struct LikeRow: Decodable { let postId: String; let userId: String }
    private struct ReportRow: Decodable { let postId: String }

    static let checkInWindow: TimeInterval = 90 * 60

    static func load(myID: String) async throws -> CloudSnapshot {
        let since = encode(ISO8601DateFormatter().string(from: .now.addingTimeInterval(-checkInWindow)))
        async let profileRows: [ProfileRow] = db.select("profiles", "select=id,name")
        async let dogRows: [DogRow] = db.select("dogs", "select=id,owner_id,name,breed,color,photo_url,size,comfort&order=created_at")
        async let checkInRows: [CheckInRow] = db.select("check_ins", "select=user_id,park_id,dog_ids,arrived_at&arrived_at=gt.\(since)")
        async let postRows: [PostRow] = db.select("posts", "select=id,author_id,dog_id,park_id,caption,photo_url,created_at&order=created_at.desc&limit=60")
        async let likeRows: [LikeRow] = db.select("post_likes", "select=post_id,user_id")
        async let reportRows: [ReportRow] = db.select("reports", "select=post_id")

        var snapshot = CloudSnapshot()
        for row in try await profileRows {
            snapshot.profiles[row.id] = Person(id: row.id, name: row.name, dogIDs: [])
        }
        for row in try await dogRows {
            snapshot.dogs[row.id] = Dog(id: row.id, name: row.name, breed: row.breed, colorHex: row.color,
                                        photoURL: row.photoUrl.flatMap(URL.init(string:)),
                                        size: row.size.flatMap(DogSize.init(rawValue:)),
                                        comfort: row.comfort.flatMap(DogComfort.init(rawValue:)))
            snapshot.profiles[row.ownerId]?.dogIDs.append(row.id)
        }
        snapshot.checkIns = try await checkInRows.map {
            CheckIn(personID: $0.userId, parkID: $0.parkId, dogIDs: $0.dogIds, arrivedAt: $0.arrivedAt)
        }
        let likes = try await likeRows
        snapshot.posts = try await postRows.map { row in
            let postLikes = likes.filter { $0.postId == row.id }
            return Post(id: row.id, authorID: row.authorId, dogID: row.dogId, parkID: row.parkId, caption: row.caption,
                        photoURL: row.photoUrl.flatMap(URL.init(string:)), postedAt: row.createdAt,
                        likes: postLikes.count, likedByMe: postLikes.contains { $0.userId == myID })
        }
        snapshot.reportedPostIDs = try await Set(reportRows.map(\.postId))
        return snapshot
    }

    /// Name-only sign-up: no email or password. Creates the person and their first dog.
    static func join(name: String, dog: Dog, photo: Data?) async throws -> String {
        let session: SupabaseClient.Session
        if let existing = db.session {
            session = existing
        } else {
            session = try await db.signInAnonymously()
        }
        try await db.insert("profiles", ["id": session.userID, "name": name], onConflict: "id")
        try await addDog(dog, photo: photo)
        return session.userID
    }

    static func addDog(_ dog: Dog, photo: Data?) async throws {
        var row = fields(of: dog)
        if let photo { row["photo_url"] = try await db.uploadPhoto(photo).absoluteString }
        try await db.insert("dogs", row)
    }

    /// Saves changes to one of my dogs, and a new photo if one was picked.
    static func updateDog(_ dog: Dog, photo: Data?) async throws {
        var changes = fields(of: dog)
        if let photo { changes["photo_url"] = try await db.uploadPhoto(photo).absoluteString }
        try await db.update("dogs", "id=eq.\(dog.id)", changes)
    }

    private static func fields(of dog: Dog) -> [String: Any] {
        ["name": dog.name, "breed": dog.breed, "color": dog.colorHex,
         "size": dog.size?.rawValue ?? NSNull(), "comfort": dog.comfort?.rawValue ?? NSNull()]
    }

    // MARK: Friends (see supabase/migrations/20260929030000_friends_and_dog_details.sql)

    /// Makes a one-time invite code (works for 7 days).
    static func createInvite() async throws -> String {
        try await db.rpc("create_invite")
    }

    /// Uses a friend's invite code ("K7P2-9QXM" or "k7p29qxm" both work). Returns the friend's name.
    static func acceptInvite(_ code: String) async throws -> String {
        try await db.rpc("accept_invite", ["invite_code": code])
    }

    static func removeFriend(myID: String, friendID: String) async throws {
        try await db.delete("friendships", "user_a=in.(\(myID),\(friendID))&user_b=in.(\(myID),\(friendID))")
    }

    static func checkIn(myID: String, parkID: String, dogIDs: [String]) async throws {
        try await db.insert("check_ins", ["user_id": myID, "park_id": parkID, "dog_ids": dogIDs], onConflict: "user_id")
    }

    /// Asks the server to send friends' phones a "just arrived!" notification (once per arrival).
    static func notifyArrival() async {
        do {
            try await db.invokeFunction("notify-arrival")
        } catch {
            print("Couldn't send arrival notifications:", error)
        }
    }

    static func checkOut(myID: String) async throws {
        try await db.delete("check_ins", "user_id=eq.\(myID)")
    }

    static func addPost(dogID: String, parkID: String, caption: String, photo: Data?) async throws {
        var row: [String: Any] = ["dog_id": dogID, "park_id": parkID, "caption": caption]
        if let photo { row["photo_url"] = try await db.uploadPhoto(photo).absoluteString }
        try await db.insert("posts", row)
    }

    static func deletePost(_ id: String) async throws {
        try await db.delete("posts", "id=eq.\(id)")
    }

    static func setLike(_ postID: String, liked: Bool, myID: String) async throws {
        if liked {
            try await db.insert("post_likes", ["post_id": postID])
        } else {
            try await db.delete("post_likes", "post_id=eq.\(postID)&user_id=eq.\(myID)")
        }
    }

    static func report(_ postID: String) async throws {
        do {
            try await db.insert("reports", ["post_id": postID])
        } catch let error as SupabaseError where error.status == 409 {
            // Already reported.
        }
    }

    /// Deletes the person, their dogs, check-ins, posts and likes, then signs out.
    static func leave(myID: String) async throws {
        try await db.delete("profiles", "id=eq.\(myID)")
        db.signOut()
    }

    /// Makes a value safe to put in a URL query ("+" in a timestamp would otherwise become a space).
    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
