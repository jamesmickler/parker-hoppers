import SwiftUI
import CoreLocation

struct Dog: Identifiable, Hashable {
    let id: String
    var name: String
    var breed: String
    var colorHex: String
    var photoURL: URL?
    var size: DogSize?
    var comfort: DogComfort?

    var color: Color { Color(hex: colorHex) }

    /// The breed, unless it's the "Good dog" filler used when none was given.
    var breedText: String { breed == "Good dog" ? "" : breed }

    /// "Large · Loves all dogs" (whatever's known about the dog).
    var details: String {
        [size?.label, comfort?.label].compactMap { $0 }.joined(separator: " · ")
    }

    /// Shy dogs and dogs that need space get a heads-up on the park page.
    var needsCare: Bool { comfort == .shy || comfort == .needsSpace }
}

// Dog details. The raw values are stored in the database (dogs.size, dogs.comfort);
// keep them in sync with web/data.js.
enum DogSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var hint: String {
        switch self {
        case .small: "under 25 lb"
        case .medium: "25–50 lb"
        case .large: "over 50 lb"
        }
    }
}

enum DogComfort: String, CaseIterable, Identifiable {
    case lovesAll = "loves_all"
    case smallDogs = "small_dogs"
    case bigDogs = "big_dogs"
    case shy
    case needsSpace = "needs_space"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .lovesAll: "Loves all dogs"
        case .smallDogs: "Best with small dogs"
        case .bigDogs: "Best with big dogs"
        case .shy: "Shy, warms up slowly"
        case .needsSpace: "Needs space from other dogs"
        }
    }
    /// For the park page: "Mochi needs space from other dogs".
    var headsUp: String? {
        switch self {
        case .shy: "is shy and warms up slowly"
        case .needsSpace: "needs space from other dogs"
        default: nil
        }
    }
}

struct Person: Identifiable, Hashable {
    let id: String
    var name: String
    var dogIDs: [String]
    /// Part of the made-up demo pack rather than a real person who joined.
    var isDemo = false
}

/// One per person: checking in again replaces it.
struct CheckIn: Identifiable, Hashable {
    var id: String { personID }
    let personID: String
    var parkID: String
    var dogIDs: [String]
    var arrivedAt: Date
}

struct Post: Identifiable {
    let id: String
    var authorID: String
    var dogID: String?
    var parkID: String?
    var caption: String
    var photoURL: URL?
    var postedAt: Date
    var likes: Int
    var likedByMe: Bool
}

extension Color {
    /// "#F2762E" → Color. Falls back to gray for anything unexpected.
    init(hex: String) {
        var value: UInt64 = 0
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, Scanner(string: digits).scanHexInt64(&value) else {
            self = .gray
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// "Luna", "Waffles and Pickles", "Luna, Waffles, Mochi +2"
func dogNames(_ dogs: [Dog], limit: Int = 3) -> String {
    let names = dogs.map(\.name)
    guard names.count > limit else { return ListFormatter.localizedString(byJoining: names) }
    return names.prefix(limit).joined(separator: ", ") + " +\(names.count - limit)"
}

/// "just now", "12 min ago", "3 hr ago", "2 d ago"
func timeAgo(_ date: Date) -> String {
    let minutes = Int(Date.now.timeIntervalSince(date) / 60)
    if minutes < 1 { return "just now" }
    if minutes < 60 { return "\(minutes) min ago" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours) hr ago" }
    return "\(hours / 24) d ago"
}
