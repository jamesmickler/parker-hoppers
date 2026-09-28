import SwiftUI
import CoreLocation

struct Dog: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var breed: String
    var tint: Color
}

struct Person: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var dogs: [Dog]
}

struct Park: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var neighborhood: String
    var latitude: Double
    var longitude: Double
    /// Pups from people outside your network. You see a count, never who they are.
    var otherDogCount: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct CheckIn: Identifiable, Hashable {
    let id = UUID()
    var person: Person
    var dogs: [Dog]
    var parkID: Park.ID
    var arrivedAt: Date
}

struct Post: Identifiable {
    let id = UUID()
    var author: Person
    var dog: Dog
    var parkName: String
    var caption: String
    var postedAt: Date
    var likes: Int
    /// Colors and symbol stand in for a real photo until one is attached.
    var palette: [Color]
    var symbol: String
    var image: UIImage? = nil
    var likedByMe = false
}
