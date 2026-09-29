/// Made-up friends for demos. They never appear at a park on their own; the 🔔 button on the
/// Parks tab walks one of them into one of your parks so the arrival alert can be shown off.
/// Same pack as the website (web/data.js).
enum DemoPack {
    static let dogs: [Dog] = [
        Dog(id: "luna", name: "Luna", breed: "Border Collie", colorHex: "#5B5FD6", size: .medium, comfort: .lovesAll),
        Dog(id: "waffles", name: "Waffles", breed: "Corgi", colorHex: "#C98A4B", size: .small, comfort: .bigDogs),
        Dog(id: "pickles", name: "Pickles", breed: "Dachshund", colorHex: "#34A853", size: .small, comfort: .smallDogs),
        Dog(id: "mochi", name: "Mochi", breed: "Shiba Inu", colorHex: "#E5484D", size: .medium, comfort: .needsSpace),
        Dog(id: "bruno", name: "Bruno", breed: "Boxer", colorHex: "#2BB5B8", size: .large, comfort: .lovesAll),
        Dog(id: "olive", name: "Olive", breed: "Labradoodle", colorHex: "#FF6B8B", size: .large, comfort: .shy),
    ]

    static let people: [Person] = [
        Person(id: "maya", name: "Maya", dogIDs: ["luna"], isDemo: true),
        Person(id: "theo", name: "Theo", dogIDs: ["waffles", "pickles"], isDemo: true),
        Person(id: "priya", name: "Priya", dogIDs: ["mochi"], isDemo: true),
        Person(id: "sam", name: "Sam", dogIDs: ["bruno"], isDemo: true),
        Person(id: "dana", name: "Dana", dogIDs: ["olive"], isDemo: true),
    ]
}
