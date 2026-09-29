import CoreLocation

/// A dog park. The list matches the website (web/data.js); park IDs are shared with the
/// database, so keep them in sync.
struct Park: Identifiable, Hashable {
    enum Time: Hashable {
        case dawn, dusk
        case hour(Double)
    }

    struct Window: Hashable {
        var start: Time
        var end: Time
    }

    /// Where automatic check-in kicks in: a circle in meters, and the worst GPS precision
    /// (in meters) trusted there.
    struct Zone: Hashable {
        var radius: Double
        var maxAccuracy: Double?

        var accuracyLimit: Double { maxAccuracy ?? max(30, radius) }
    }

    let id: String
    var name: String
    var area: String
    var address: String
    var latitude: Double
    var longitude: Double
    /// Off-leash windows; nil when the park doesn't publish them.
    var hours: [Window]?
    var hoursText: String
    var access: String? = nil
    var fenced: Bool?
    /// nil means manual check-in only.
    var zone: Zone?

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }

    /// Whether a location reading puts you inside the zone, with GPS precise enough to trust.
    func contains(_ reading: CLLocation) -> Bool {
        guard let zone, reading.horizontalAccuracy >= 0 else { return false }
        return reading.horizontalAccuracy <= zone.accuracyLimit && reading.distance(from: location) <= zone.radius
    }
}

extension Park {
    /// Real Charleston off-leash areas (City of Charleston dog park list and Charleston County
    /// Parks), plus The Jasper's residents-only dog run.
    static let all: [Park] = [
        Park(id: "hazel-parker", name: "Hazel Parker Off-Leash Area", area: "French Quarter",
             address: "70 E Bay St", latitude: 32.77483, longitude: -79.92624,
             hours: [Window(start: .dawn, end: .hour(9)), Window(start: .hour(17), end: .dusk)],
             hoursText: "Dawn–9 AM and 5 PM–dusk", fenced: false, zone: Zone(radius: 60)),
        Park(id: "cannon-park", name: "Cannon Park", area: "Harleston Village",
             address: "131 Rutledge Ave", latitude: 32.78287, longitude: -79.94416,
             hours: [Window(start: .dawn, end: .hour(9)), Window(start: .hour(17), end: .dusk)],
             hoursText: "Dawn–9 AM and 5 PM–dusk", fenced: false, zone: Zone(radius: 80)),
        Park(id: "brittlebank", name: "Brittlebank Park", area: "West Side",
             address: "185 Lockwood Dr", latitude: 32.78802, longitude: -79.96057,
             hours: [Window(start: .dawn, end: .dusk)],
             hoursText: "Dawn–dusk", fenced: false, zone: Zone(radius: 120)),
        Park(id: "white-point", name: "White Point Garden", area: "South of Broad",
             address: "2 Murray Blvd", latitude: 32.76981, longitude: -79.93035,
             hours: [Window(start: .dawn, end: .hour(9)), Window(start: .hour(17), end: .hour(23))],
             hoursText: "Dawn–9 AM and 5–11 PM", fenced: false, zone: Zone(radius: 100)),
        Park(id: "horse-lot", name: "Horse Lot Off-Leash Area", area: "Harleston Village",
             address: "2 Chisolm St", latitude: 32.77442, longitude: -79.94154,
             hours: [Window(start: .dawn, end: .dusk)],
             hoursText: "Dawn–dusk", fenced: false, zone: Zone(radius: 50)),
        // Amenity at The Jasper apartments. A tight circle on the dog run itself that only
        // trusts precise (outdoor) GPS, so being inside the building doesn't count.
        Park(id: "the-jasper", name: "The Jasper Dog Park", area: "Harleston Village",
             address: "310 Broad St", latitude: 32.776453, longitude: -79.943101,
             hours: nil, hoursText: "Set by the building", access: "Residents only",
             fenced: nil, zone: Zone(radius: 20, maxAccuracy: 15)),
        Park(id: "ackerman", name: "Ackerman Park Dog Park", area: "West Ashley",
             address: "55 Sycamore Ave", latitude: 32.78940, longitude: -79.98879,
             hours: [Window(start: .dawn, end: .dusk)],
             hoursText: "Dawn–dusk", fenced: true, zone: Zone(radius: 90)),
        // Where the dog park sits inside the 600-acre county park isn't mapped: manual check-in only.
        Park(id: "james-island", name: "James Island County Park Dog Park", area: "James Island",
             address: "871 Riverland Dr", latitude: 32.73485, longitude: -79.98947,
             hours: nil, hoursText: "County park hours · small entry fee", fenced: true, zone: nil),
    ]

    static func find(_ id: String?) -> Park? { all.first { $0.id == id } }

    /// "Your parks" (arrival alerts on) on a fresh install.
    static let defaultAlertIDs: Set<String> = ["hazel-parker", "cannon-park", "horse-lot", "the-jasper"]

    /// The parks the main map opens on; James Island and West Ashley are a drag away.
    static let downtownIDs: Set<String> = ["hazel-parker", "cannon-park", "brittlebank", "white-point"]
}

// MARK: - Off-leash hours

extension Park {
    /// Rough Charleston sunrise/sunset by month, in hours (local time). Good enough for dawn and dusk.
    private static let sun: [(dawn: Double, dusk: Double)] = [
        (7.3, 17.6), (7.1, 18.1), (7.4, 19.4), (6.9, 19.8), (6.4, 20.2), (6.2, 20.5),
        (6.4, 20.5), (6.7, 20.1), (7.0, 19.5), (7.3, 18.9), (6.8, 17.4), (7.2, 17.3),
    ]

    /// Whether dogs can be off-leash right now, e.g. "Off-leash now · until 9 AM".
    func offLeashStatus(at date: Date = .now) -> (open: Bool, text: String)? {
        guard let hours else { return nil }
        let calendar = Calendar.current
        let sun = Self.sun[calendar.component(.month, from: date) - 1]
        let now = Double(calendar.component(.hour, from: date)) + Double(calendar.component(.minute, from: date)) / 60

        func value(_ time: Time) -> Double {
            switch time {
            case .dawn: sun.dawn
            case .dusk: sun.dusk
            case .hour(let h): h
            }
        }
        func label(_ time: Time) -> String {
            switch time {
            case .dawn:
                return "dawn"
            case .dusk:
                return "dusk"
            case .hour(let h):
                let hour = Int(h)
                let suffix = hour >= 12 && hour < 24 ? "PM" : "AM"
                return "\((hour + 11) % 12 + 1) \(suffix)"
            }
        }

        for window in hours {
            if now >= value(window.start) && now < value(window.end) {
                return (true, "Off-leash now · until \(label(window.end))")
            }
            if now < value(window.start) {
                return (false, "Off-leash from \(label(window.start))")
            }
        }
        return (false, "Off-leash again tomorrow at dawn")
    }
}
