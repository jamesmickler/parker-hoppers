/// Made-up friends for demos. They never appear at a park on their own; the 🔔 button on the
/// Parks tab walks one of them into one of your parks so the arrival alert can be shown off.
/// Same pack as the website (web/data.js).
enum DemoPack {
    static let dogs: [Dog] = [
        Dog(id: "luna", name: "Luna", breed: "Border Collie", colorHex: "#5B5FD6"),
        Dog(id: "waffles", name: "Waffles", breed: "Corgi", colorHex: "#C98A4B"),
        Dog(id: "pickles", name: "Pickles", breed: "Dachshund", colorHex: "#34A853"),
        Dog(id: "mochi", name: "Mochi", breed: "Shiba Inu", colorHex: "#E5484D"),
        Dog(id: "bruno", name: "Bruno", breed: "Boxer", colorHex: "#2BB5B8"),
        Dog(id: "olive", name: "Olive", breed: "Labradoodle", colorHex: "#FF6B8B"),
    ]

    static let people: [Person] = [
        Person(id: "maya", name: "Maya", dogIDs: ["luna"], isDemo: true),
        Person(id: "theo", name: "Theo", dogIDs: ["waffles", "pickles"], isDemo: true),
        Person(id: "priya", name: "Priya", dogIDs: ["mochi"], isDemo: true),
        Person(id: "sam", name: "Sam", dogIDs: ["bruno"], isDemo: true),
        Person(id: "dana", name: "Dana", dogIDs: ["olive"], isDemo: true),
    ]
}
