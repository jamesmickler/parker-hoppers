import SwiftUI
import Observation

/// Everything the app knows and every change it can make.
///
/// Real people, dogs, check-ins and posts come from the shared database (the same one the
/// website uses). The made-up demo pack only shows up at a park when the 🔔 button is tapped.
/// Settings like "Your parks" are kept on this phone.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    enum Status { case loading, needsJoin, ready }

    struct Banner: Identifiable {
        let id = UUID()
        var title: String
        var message: String
        var parkID: String?
        var action: (label: String, run: () -> Void)?
    }

    /// Kept on this phone.
    struct Prefs: Codable {
        var alertParkIDs: Set<String> = Park.defaultAlertIDs
        var alertsEnabled = true
        var isPlus = false
        var autoCheckIn = false
        var hiddenAuthorIDs: Set<String> = []
        /// The park you were checked into automatically, if any.
        var autoParkID: String?
        /// Shows the demo pack and the "a friend arrives" button, for presentations.
        var demoMode = false

        init() {}

        /// Settings saved by an older version may be missing newer ones; keep what's there.
        init(from decoder: Decoder) throws {
            let saved = try decoder.container(keyedBy: CodingKeys.self)
            let defaults = Prefs()
            alertParkIDs = try saved.decodeIfPresent(Set<String>.self, forKey: .alertParkIDs) ?? defaults.alertParkIDs
            alertsEnabled = try saved.decodeIfPresent(Bool.self, forKey: .alertsEnabled) ?? defaults.alertsEnabled
            isPlus = try saved.decodeIfPresent(Bool.self, forKey: .isPlus) ?? defaults.isPlus
            autoCheckIn = try saved.decodeIfPresent(Bool.self, forKey: .autoCheckIn) ?? defaults.autoCheckIn
            hiddenAuthorIDs = try saved.decodeIfPresent(Set<String>.self, forKey: .hiddenAuthorIDs) ?? defaults.hiddenAuthorIDs
            autoParkID = try saved.decodeIfPresent(String.self, forKey: .autoParkID)
            demoMode = try saved.decodeIfPresent(Bool.self, forKey: .demoMode) ?? defaults.demoMode
        }
    }

    private(set) var status: Status = .loading
    private(set) var cloud = CloudSnapshot()
    private(set) var myID: String? = SupabaseClient.shared.session?.userID
    private(set) var isOffline = false
    private(set) var demoCheckIns: [CheckIn] = []
    private(set) var prefs: Prefs
    var banner: Banner?

    @ObservationIgnored let autoCheckIn = AutoCheckIn()
    @ObservationIgnored private var realtime: Realtime?
    @ObservationIgnored private var syncTimer: Timer?
    @ObservationIgnored private var reloadTask: Task<Void, Never>?
    @ObservationIgnored private var pendingArrivals: [(personID: String, parkID: String)] = []
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    private static let prefsKey = "parker-hoppers-prefs"

    private init() {
        let saved = UserDefaults.standard.data(forKey: Self.prefsKey)
        prefs = saved.flatMap { try? JSONDecoder().decode(Prefs.self, from: $0) } ?? Prefs()
        // Set up location watching right away: when the phone wakes the app because you
        // walked into a park, the news is delivered as the app starts.
        autoCheckIn.state = self
        if prefs.autoCheckIn { autoCheckIn.syncRegions() }
    }

    func updatePrefs(_ change: (inout Prefs) -> Void) {
        change(&prefs)
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: Self.prefsKey)
        }
    }

    // MARK: - Starting up

    func start() async {
        guard myID != nil else {
            status = .needsJoin
            return
        }
        await refresh()
        if me == nil && !isOffline {
            // Signed in on this phone but the profile is gone (e.g. left on another device).
            status = .needsJoin
        } else {
            status = .ready
            goLive()
        }
    }

    func refresh() async {
        guard let myID else { return }
        do {
            cloud = try await Cloud.load(myID: myID)
            isOffline = false
        } catch {
            isOffline = true
        }
    }

    func appBecameActive() {
        guard status == .ready else { return }
        Task { await resync() }
        autoCheckIn.appBecameActive()
    }

    func appWentToBackground() {
        autoCheckIn.appWentToBackground()
    }

    /// Live updates while the app is open, plus a full re-sync every 30 s as a safety net.
    private func goLive() {
        guard realtime == nil else { return }
        let realtime = Realtime { [weak self] change in self?.handle(change) }
        self.realtime = realtime
        Task {
            if let session = try? await SupabaseClient.shared.validSession() {
                realtime.connect(accessToken: session.accessToken)
            }
        }
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.resync() }
        }
    }

    private func stopLive() {
        realtime?.disconnect()
        realtime = nil
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Reloads, and hands a renewed sign-in to the live connection so it keeps working past the hour.
    private func resync() async {
        let before = SupabaseClient.shared.session?.accessToken
        await refresh()
        if let after = SupabaseClient.shared.session?.accessToken, after != before {
            realtime?.update(accessToken: after)
        }
    }

    private func handle(_ change: Realtime.Change) {
        if change.table == "check_ins", change.type != "DELETE",
           let personID = change.record["user_id"] as? String, personID != myID,
           let parkID = change.record["park_id"] as? String {
            pendingArrivals.append((personID, parkID))
        }
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refresh()
            let arrivals = pendingArrivals
            pendingArrivals = []
            for arrival in arrivals {
                announceArrival(personID: arrival.personID, parkID: arrival.parkID)
            }
        }
    }

    // MARK: - Reading

    var me: Person? { myID.flatMap { cloud.profiles[$0] } }

    func dog(_ id: String) -> Dog? {
        cloud.dogs[id] ?? DemoPack.dogs.first { $0.id == id }
    }

    func person(_ id: String) -> Person? {
        cloud.profiles[id] ?? DemoPack.people.first { $0.id == id }
    }

    var myDogs: [Dog] { me?.dogIDs.compactMap(dog) ?? [] }

    func dogs(of checkIn: CheckIn) -> [Dog] { checkIn.dogIDs.compactMap(dog) }

    /// Real people first, then the demo pack while Demo Mode is on.
    var friends: [Person] {
        let real = cloud.profiles.values.filter { $0.id != myID }.sorted { $0.name < $1.name }
        return real + (prefs.demoMode ? DemoPack.people : [])
    }

    private var currentCheckIns: [CheckIn] {
        (cloud.checkIns + (prefs.demoMode ? demoCheckIns : [])).filter {
            Date.now.timeIntervalSince($0.arrivedAt) < Cloud.checkInWindow && person($0.personID) != nil
        }
    }

    func visitors(at park: Park) -> [CheckIn] {
        currentCheckIns.filter { $0.parkID == park.id }.sorted { $0.arrivedAt > $1.arrivedAt }
    }

    func dogCount(at park: Park) -> Int {
        visitors(at: park).reduce(0) { $0 + dogs(of: $1).count }
    }

    func checkIn(for personID: String) -> CheckIn? {
        currentCheckIns.first { $0.personID == personID }
    }

    var myCheckIn: CheckIn? { myID.flatMap(checkIn(for:)) }

    var friendCheckIns: [CheckIn] {
        currentCheckIns.filter { $0.personID != myID }.sorted { $0.arrivedAt > $1.arrivedAt }
    }

    var posts: [Post] {
        cloud.posts.filter {
            !cloud.reportedPostIDs.contains($0.id) && !prefs.hiddenAuthorIDs.contains($0.authorID) && person($0.authorID) != nil
        }
    }

    func alertsOn(_ park: Park) -> Bool { prefs.alertParkIDs.contains(park.id) }

    var myParks: [Park] {
        Park.all.filter(alertsOn).sorted { dogCount(at: $0) > dogCount(at: $1) }
    }

    var otherParks: [Park] { Park.all.filter { !alertsOn($0) } }

    /// Parks automatic check-in watches: your parks that have a check-in zone.
    var watchedParks: [Park] { Park.all.filter { alertsOn($0) && $0.zone != nil } }

    /// The park you were checked into automatically, while you're still checked in there.
    var autoCheckedInPark: Park? {
        guard let id = prefs.autoParkID, myCheckIn?.parkID == id else { return nil }
        return Park.find(id)
    }

    // MARK: - Changing

    /// Runs a change that talks to the server; shows a banner instead of failing silently.
    @discardableResult
    func attempt(_ work: () async throws -> Void) async -> Bool {
        do {
            try await work()
            return true
        } catch {
            showBanner("That didn’t go through", friendly(error))
            return false
        }
    }

    func join(name: String, dog: Dog, photo: UIImage?) async throws {
        myID = try await Cloud.join(name: name, dog: dog, photo: photo?.jpeg(maxSide: 320))
        await refresh()
        status = .ready
        goLive()
        showBanner("Welcome to the pack, \(name)!", "Tap a park and “We’re here!” when you and \(dog.name) arrive.")
    }

    func checkIn(park: Park, dogIDs: [String], auto: Bool = false) async throws {
        guard let myID else { return }
        try await Cloud.checkIn(myID: myID, parkID: park.id, dogIDs: dogIDs)
        updatePrefs { $0.autoParkID = auto ? park.id : nil }
        await refresh()
    }

    func checkOut() async throws {
        guard let myID else { return }
        try await Cloud.checkOut(myID: myID)
        updatePrefs { $0.autoParkID = nil }
        await refresh()
    }

    /// Walks a demo friend into one of your parks so the arrival alert can be shown off.
    func simulateArrival() {
        let idle = DemoPack.people.filter { checkIn(for: $0.id) == nil }
        guard let friend = (idle.isEmpty ? DemoPack.people : idle).randomElement(),
              let park = (myParks.isEmpty ? Park.all : myParks).randomElement() else { return }
        demoCheckIns.removeAll { $0.personID == friend.id }
        demoCheckIns.append(CheckIn(personID: friend.id, parkID: park.id, dogIDs: friend.dogIDs, arrivedAt: .now))
        announceArrival(personID: friend.id, parkID: park.id)
    }

    func resetDemoPack() {
        demoCheckIns = []
    }

    /// Demo Mode on shows the demo pack and its button; off hides them and sends the pack home.
    func setDemoMode(_ on: Bool) {
        updatePrefs { $0.demoMode = on }
        if !on { demoCheckIns = [] }
    }

    func toggleAlerts(_ park: Park) {
        updatePrefs {
            if $0.alertParkIDs.contains(park.id) { $0.alertParkIDs.remove(park.id) } else { $0.alertParkIDs.insert(park.id) }
        }
        autoCheckIn.syncRegions()
    }

    func toggleLike(_ post: Post) async throws {
        guard let myID else { return }
        try await Cloud.setLike(post.id, liked: !post.likedByMe, myID: myID)
        await refresh()
    }

    func addPost(dogID: String, parkID: String, caption: String, photo: UIImage?) async throws {
        try await Cloud.addPost(dogID: dogID, parkID: parkID, caption: caption, photo: photo?.jpeg(maxSide: 1080))
        await refresh()
    }

    func deletePost(_ post: Post) async throws {
        try await Cloud.deletePost(post.id)
        await refresh()
    }

    func report(_ post: Post) async throws {
        try await Cloud.report(post.id)
        await refresh()
        showBanner("Thanks for letting us know", "That post is hidden while we review it.")
    }

    func hidePosts(from person: Person) {
        updatePrefs { $0.hiddenAuthorIDs.insert(person.id) }
        showBanner("Posts hidden", "You won’t see \(person.name)’s posts anymore.")
    }

    func addDog(_ dog: Dog, photo: UIImage?) async throws {
        try await Cloud.addDog(dog, photo: photo?.jpeg(maxSide: 320))
        await refresh()
    }

    func leave() async throws {
        guard let myID else { return }
        try await Cloud.leave(myID: myID)
        stopLive()
        self.myID = nil
        cloud = CloudSnapshot()
        updatePrefs { $0.autoParkID = nil }
        status = .needsJoin
    }

    // MARK: - Automatic check-in

    func autoArrive(at park: Park) async {
        guard myID != nil else { return }
        if me == nil { await refresh() }
        let dogs = myDogs
        guard myCheckIn == nil, !dogs.isEmpty else { return }
        guard await attempt({ try await checkIn(park: park, dogIDs: dogs.map(\.id), auto: true) }) else { return }

        let title = "You’re at \(park.name)"
        let message = "Checked in \(dogNames(dogs)) automatically."
        if UIApplication.shared.applicationState == .active {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showBanner(title, message, parkID: park.id, action: ("Undo", { [weak self] in
                Task { await self?.undoAutoCheckIn() }
            }))
        } else {
            Notifier.post(title: title, body: "\(message) Friends can see you’re here.", undo: true)
        }
    }

    func autoLeave(from park: Park) async {
        guard autoCheckedInPark?.id == park.id else { return }
        guard await attempt({ try await checkOut() }) else { return }
        if UIApplication.shared.applicationState == .active {
            showBanner("Checked out", "Looks like you left \(park.name). See you next time! 🐾")
        } else {
            Notifier.post(title: "Checked out of \(park.name)", body: "See you next time! 🐾", undo: false)
        }
    }

    func undoAutoCheckIn() async {
        guard autoCheckedInPark != nil else { return }
        await attempt { try await checkOut() }
    }

    // MARK: - Banner

    func announceArrival(personID: String, parkID: String) {
        guard prefs.alertsEnabled, let park = Park.find(parkID), alertsOn(park), let person = person(personID) else { return }
        let dogs = checkIn(for: personID).map(dogs(of:)) ?? []
        let title = dogs.isEmpty ? "\(person.name) just arrived!" : "\(dogNames(dogs)) just arrived!"
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showBanner(title, "\(person.name) is at \(park.name).", parkID: park.id)
    }

    func showBanner(_ title: String, _ message: String, parkID: String? = nil,
                    action: (label: String, run: () -> Void)? = nil) {
        let banner = Banner(title: title, message: message, parkID: parkID, action: action)
        withAnimation(.spring(duration: 0.4)) { self.banner = banner }
        bannerTask?.cancel()
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(action == nil ? 4.5 : 8))
            guard !Task.isCancelled, self.banner?.id == banner.id else { return }
            withAnimation { self.banner = nil }
        }
    }

    private func friendly(_ error: Error) -> String {
        if error is URLError { return "Check your internet connection and try again." }
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("anonymous sign-ins are disabled") {
            return "Sign-ups are switched off in Supabase (Allow anonymous sign-ins)."
        }
        if message.localizedCaseInsensitiveContains("rate limit") {
            return "Too many sign-ups from this network. Try again in a bit."
        }
        return message
    }
}

extension UIImage {
    /// Shrinks a photo so it uploads fast, as a JPEG.
    func jpeg(maxSide: CGFloat) -> Data? {
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
