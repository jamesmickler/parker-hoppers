import SwiftUI
import Observation

/// Everything the app knows right now. In the prototype it lives only on the phone;
/// later it will load from and save to a server so friends see each other.
@MainActor
@Observable
final class AppState {
    struct Banner: Identifiable, Equatable {
        let id = UUID()
        var icon: String
        var title: String
        var message: String
    }

    var me: Person
    var friends: [Person]
    var parks: [Park]
    var checkIns: [CheckIn]
    var posts: [Post]
    /// Parks you get arrival alerts for.
    var myParkIDs: Set<Park.ID>
    var banner: Banner?
    var isPremium = false
    var autoCheckIn = false
    var alertsEnabled = true

    init() {
        me = MockData.me
        friends = MockData.friends
        parks = MockData.parks
        checkIns = MockData.checkIns
        posts = MockData.posts
        myParkIDs = Set(MockData.parks.prefix(2).map(\.id))
    }

    // MARK: - Parks

    var myCheckIn: CheckIn? {
        checkIns.first { $0.person.id == me.id }
    }

    var myParks: [Park] {
        parks.filter { myParkIDs.contains($0.id) }
            .sorted { dogCount(at: $0) > dogCount(at: $1) }
    }

    var otherParks: [Park] {
        parks.filter { !myParkIDs.contains($0.id) }
    }

    func park(id: Park.ID) -> Park? {
        parks.first { $0.id == id }
    }

    func visitors(at park: Park) -> [CheckIn] {
        checkIns.filter { $0.parkID == park.id }
            .sorted { $0.arrivedAt > $1.arrivedAt }
    }

    func dogCount(at park: Park) -> Int {
        visitors(at: park).reduce(park.otherDogCount) { $0 + $1.dogs.count }
    }

    func toggleAlerts(for park: Park) {
        if myParkIDs.contains(park.id) {
            myParkIDs.remove(park.id)
        } else {
            myParkIDs.insert(park.id)
        }
    }

    func checkIn(at park: Park, with dogs: [Dog]) {
        checkOut()
        checkIns.append(CheckIn(person: me, dogs: dogs, parkID: park.id, arrivedAt: .now))
        showBanner(icon: "checkmark.circle.fill",
                   title: "You're checked in!",
                   message: "Friends can now see \(dogNames(dogs)) at \(park.name).")
    }

    func checkOut() {
        checkIns.removeAll { $0.person.id == me.id }
    }

    // MARK: - Friends

    var friendCheckIns: [CheckIn] {
        checkIns.filter { $0.person.id != me.id }
            .sorted { $0.arrivedAt > $1.arrivedAt }
    }

    func currentCheckIn(for person: Person) -> CheckIn? {
        checkIns.first { $0.person.id == person.id }
    }

    /// Pretends a friend just walked into one of your parks so you can feel what the alert is like.
    func simulateFriendArrival() {
        let idle = friends.filter { currentCheckIn(for: $0) == nil }
        guard let friend = idle.randomElement() ?? friends.randomElement(),
              let park = myParks.randomElement() ?? parks.randomElement() else { return }

        checkIns.removeAll { $0.person.id == friend.id }
        checkIns.append(CheckIn(person: friend, dogs: friend.dogs, parkID: park.id, arrivedAt: .now))

        guard alertsEnabled else { return }
        showBanner(icon: "pawprint.fill",
                   title: "\(dogNames(friend.dogs)) just arrived!",
                   message: "\(friend.name) is at \(park.name).")
    }

    // MARK: - Feed

    func toggleLike(_ post: Post) {
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[i].likedByMe.toggle()
        posts[i].likes += posts[i].likedByMe ? 1 : -1
    }

    func addPost(dog: Dog, parkName: String, caption: String, image: UIImage?) {
        let post = Post(author: me, dog: dog, parkName: parkName, caption: caption,
                        postedAt: .now, likes: 0, palette: [dog.tint, .accentColor],
                        symbol: "camera.fill", image: image)
        posts.insert(post, at: 0)
    }

    func delete(_ post: Post) {
        posts.removeAll { $0.id == post.id }
    }

    func report(_ post: Post) {
        delete(post)
        showBanner(icon: "flag.fill",
                   title: "Thanks for letting us know",
                   message: "That post is hidden while we review it.")
    }

    func hidePosts(from person: Person) {
        posts.removeAll { $0.author.id == person.id }
        showBanner(icon: "eye.slash.fill",
                   title: "Posts hidden",
                   message: "You won't see \(person.name)'s posts anymore.")
    }

    // MARK: - Profile

    func addDog(name: String, breed: String, tint: Color) {
        me.dogs.append(Dog(name: name, breed: breed, tint: tint))
    }

    // MARK: - Banner

    func showBanner(icon: String, title: String, message: String) {
        let banner = Banner(icon: icon, title: title, message: message)
        withAnimation(.spring) { self.banner = banner }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if self.banner?.id == banner.id {
                withAnimation { self.banner = nil }
            }
        }
    }
}
