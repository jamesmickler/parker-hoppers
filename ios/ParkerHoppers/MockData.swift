import SwiftUI

/// Made-up people, dogs and parks so the prototype has something to show.
/// Everything here gets replaced by real data once accounts and a server exist.
enum MockData {
    // Your dogs
    static let biscuit = Dog(name: "Biscuit", breed: "Golden Retriever", tint: .orange)
    static let pepper = Dog(name: "Pepper", breed: "Australian Shepherd", tint: .gray)

    // Friends' dogs
    static let luna = Dog(name: "Luna", breed: "Border Collie", tint: .indigo)
    static let waffles = Dog(name: "Waffles", breed: "Corgi", tint: .brown)
    static let pickles = Dog(name: "Pickles", breed: "Dachshund", tint: .green)
    static let mochi = Dog(name: "Mochi", breed: "Shiba Inu", tint: .red)
    static let bruno = Dog(name: "Bruno", breed: "Boxer", tint: .teal)
    static let olive = Dog(name: "Olive", breed: "Labradoodle", tint: .pink)

    static let me = Person(name: "You", dogs: [biscuit, pepper])

    static let maya = Person(name: "Maya", dogs: [luna])
    static let theo = Person(name: "Theo", dogs: [waffles, pickles])
    static let priya = Person(name: "Priya", dogs: [mochi])
    static let sam = Person(name: "Sam", dogs: [bruno])
    static let dana = Person(name: "Dana", dogs: [olive])

    static let friends = [maya, theo, priya, sam, dana]

    static let parks = [
        Park(name: "Maple Hollow Dog Park", neighborhood: "Mission Hill",
             latitude: 37.7599, longitude: -122.4148, otherDogCount: 4),
        Park(name: "Riverside Bark Run", neighborhood: "Embarcadero",
             latitude: 37.7955, longitude: -122.3937, otherDogCount: 2),
        Park(name: "Sunset Paws Field", neighborhood: "Outer Sunset",
             latitude: 37.7534, longitude: -122.4930, otherDogCount: 6),
        Park(name: "Pine Ridge Off-Leash Area", neighborhood: "Presidio",
             latitude: 37.7989, longitude: -122.4662, otherDogCount: 0),
        Park(name: "Corgi Commons", neighborhood: "Noe Valley",
             latitude: 37.7502, longitude: -122.4337, otherDogCount: 3),
    ]

    static let checkIns = [
        CheckIn(person: maya, dogs: maya.dogs, parkID: parks[0].id,
                arrivedAt: .now.addingTimeInterval(-12 * 60)),
        CheckIn(person: theo, dogs: theo.dogs, parkID: parks[0].id,
                arrivedAt: .now.addingTimeInterval(-35 * 60)),
        CheckIn(person: priya, dogs: priya.dogs, parkID: parks[1].id,
                arrivedAt: .now.addingTimeInterval(-5 * 60)),
    ]

    static let posts = [
        Post(author: maya, dog: luna, parkName: parks[0].name,
             caption: "Luna finally caught the frisbee mid-air 🥏 Took three weeks of practice!",
             postedAt: .now.addingTimeInterval(-50 * 60), likes: 14,
             palette: [.indigo, .purple], symbol: "figure.disc.sports"),
        Post(author: theo, dog: waffles, parkName: parks[0].name,
             caption: "Waffles vs. the puddle. The puddle won.",
             postedAt: .now.addingTimeInterval(-3 * 3600), likes: 23,
             palette: [.brown, .orange], symbol: "drop.fill"),
        Post(author: priya, dog: mochi, parkName: parks[1].name,
             caption: "Mochi made three new friends today and refused to leave 🐾",
             postedAt: .now.addingTimeInterval(-6 * 3600), likes: 9,
             palette: [.red, .pink], symbol: "heart.fill"),
        Post(author: sam, dog: bruno, parkName: parks[2].name,
             caption: "Bruno's first time off-leash. Zoomies achieved.",
             postedAt: .now.addingTimeInterval(-26 * 3600), likes: 31,
             palette: [.teal, .blue], symbol: "hare.fill"),
        Post(author: dana, dog: olive, parkName: parks[4].name,
             caption: "Golden hour, golden doodle.",
             postedAt: .now.addingTimeInterval(-50 * 3600), likes: 18,
             palette: [.pink, .yellow], symbol: "sun.max.fill"),
    ]
}
