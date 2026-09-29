import CoreLocation
import OSLog
import UIKit
import UserNotifications

private let log = Logger(subsystem: "com.parkerhoppers.app", category: "AutoCheckIn")

/// Automatic check-in that works with the phone in your pocket.
///
/// iOS watches a circle around each of your parks and wakes the app when you walk into one,
/// even if it's closed. Those circles are coarse (iOS is only accurate to 100–200 m there),
/// so they just start the check: precise GPS then has to put you inside the park's own zone
/// (20 m for The Jasper) with good accuracy for about 45 seconds before you're checked in.
/// Walking out of the circle again checks you out.
@MainActor
final class AutoCheckIn: NSObject, CLLocationManagerDelegate {
    static let stayFor: TimeInterval = 45
    /// iOS won't reliably notice circles smaller than this, so it's the wake-up radius.
    static let wakeRadius: CLLocationDistance = 150
    /// Stop precise GPS if a wake-up hasn't turned into a check-in by then (saves battery).
    static let giveUpAfter: TimeInterval = 10 * 60

    weak var state: AppState?
    private let manager = CLLocationManager()
    /// iOS's place watcher. Kept under one name so it picks up where it left off when iOS
    /// relaunches the app in the background.
    /// Created once: iOS crashes the app if a second watcher with the same name is made.
    private var monitorTask: Task<CLMonitor, Never>?
    private var monitorEvents: Task<Void, Never>?
    private var insideWakeCircles: Set<String> = []
    /// Parks iOS said it can't watch (e.g. in the Simulator, which can't save the watch list).
    /// For those, the app watches for itself, but only while it's open.
    private var unwatchable: Set<String> = []
    private var arriving: (parkID: String, since: Date)?
    private var preciseSince: Date?
    private var lastReading: CLLocation?
    /// A phone standing still may stop reporting new positions, so re-judge the last one
    /// once the 45 seconds are up.
    private var dwellTimer: Timer?
    private var appIsActive = UIApplication.shared.applicationState == .active

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .fitness
        // Clear out circles registered by earlier builds through iOS's older place-watching API.
        for region in manager.monitoredRegions { manager.stopMonitoring(for: region) }
    }

    var authorization: CLAuthorizationStatus { manager.authorizationStatus }

    /// False when iOS said it can't watch your parks (then it only works while the app is open).
    var canWatchInBackground: Bool { unwatchable.isEmpty }

    /// Turning the setting on: asks for location (then "Always") and notification permission.
    func enable() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
        default: break
        }
        Notifier.requestPermission()
        syncRegions()
    }

    func disable() {
        insideWakeCircles = []
        stopPrecise()
        Task {
            guard let monitorTask else { return }
            let monitor = await monitorTask.value
            for id in await monitor.identifiers { await monitor.remove(id) }
        }
    }

    /// Makes iOS watch exactly the parks you have alerts on (and that have a zone).
    func syncRegions() {
        guard let state, state.prefs.autoCheckIn else {
            disable()
            return
        }
        let wanted = Dictionary(uniqueKeysWithValues: state.watchedParks.map { ($0.id, $0) })
        if manager.authorizationStatus != .authorizedAlways && appIsActive {
            // Without "Always", iOS won't wake the app, so also watch closely while it's open.
            startPrecise()
        }
        Task {
            let monitor = await startMonitor()
            for id in await monitor.identifiers where wanted[id] == nil {
                await monitor.remove(id)
                insideWakeCircles.remove(id)
            }
            let watching = Set(await monitor.identifiers)
            for park in wanted.values where !watching.contains(park.id) {
                let circle = CLMonitor.CircularGeographicCondition(center: park.coordinate,
                                                                   radius: max(park.zone?.radius ?? 0, Self.wakeRadius))
                // Assuming "outside" means iOS reports right away if you're already inside.
                await monitor.add(circle, identifier: park.id, assuming: .unsatisfied)
                log.notice("Watching \(park.id, privacy: .public)")
            }
            // Catch up on what iOS last said about each circle (inside, outside, or can't watch).
            for id in await monitor.identifiers {
                if let record = await monitor.record(for: id) { handle(record.lastEvent) }
            }
        }
    }

    private func startMonitor() async -> CLMonitor {
        if let monitorTask { return await monitorTask.value }
        let task = Task { () -> CLMonitor in
            let monitor = await CLMonitor("ParkerHoppersParks") // letters and digits only, or iOS crashes the app
            monitorEvents = Task { [weak self] in
                do {
                    for try await event in await monitor.events {
                        self?.handle(event)
                    }
                } catch {
                    log.error("Place watching stopped: \(error.localizedDescription, privacy: .public)")
                }
            }
            return monitor
        }
        monitorTask = task
        return await task.value
    }

    private func handle(_ event: CLMonitor.Event) {
        switch event.state {
        case .satisfied:
            unwatchable.remove(event.identifier)
            entered(event.identifier)
        case .unsatisfied:
            unwatchable.remove(event.identifier)
            exited(event.identifier)
        case .unmonitored:
            log.error("iOS can't watch \(event.identifier, privacy: .public); watching while the app is open instead")
            unwatchable.insert(event.identifier)
            if appIsActive { startPrecise() }
        default:
            break
        }
    }

    func appBecameActive() {
        appIsActive = true
        guard state?.prefs.autoCheckIn == true else { return }
        syncRegions()
        if !unwatchable.isEmpty { startPrecise() }
    }

    func appWentToBackground() {
        appIsActive = false
        // Keep precise GPS in the background only while confirming an arrival iOS woke us for.
        if manager.authorizationStatus != .authorizedAlways || insideWakeCircles.isEmpty { stopPrecise() }
    }

    /// Demo button: act as if precise GPS just confirmed you're at this park.
    func pretendArrival(at park: Park) {
        Task { await state?.autoArrive(at: park) }
    }

    // MARK: Precise GPS

    private func startPrecise() {
        guard preciseSince == nil else { return }
        log.notice("Starting precise GPS")
        preciseSince = .now
        if manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
    }

    private func stopPrecise() {
        guard preciseSince != nil else { return }
        log.notice("Stopping precise GPS")
        preciseSince = nil
        arriving = nil
        lastReading = nil
        dwellTimer?.invalidate()
        dwellTimer = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func judge(_ reading: CLLocation) {
        lastReading = reading
        guard let state, state.prefs.autoCheckIn else { return stopPrecise() }
        if state.myCheckIn != nil {
            // Already checked in; leaving is handled by the wake-up circle.
            if !appIsActive || manager.authorizationStatus == .authorizedAlways { stopPrecise() }
            return
        }
        let now = Date.now
        guard let park = state.watchedParks.first(where: { $0.contains(reading) }) else {
            arriving = nil
            let tooLong = preciseSince.map { now.timeIntervalSince($0) > Self.giveUpAfter } ?? false
            if !appIsActive && (insideWakeCircles.isEmpty || tooLong) { stopPrecise() }
            return
        }
        guard let arriving, arriving.parkID == park.id else {
            log.notice("Inside \(park.id, privacy: .public)'s zone; waiting \(Int(Self.stayFor))s to be sure")
            self.arriving = (park.id, now)
            dwellTimer?.invalidate()
            dwellTimer = Timer.scheduledTimer(withTimeInterval: Self.stayFor + 1, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    // Only trust a reading from the last two minutes.
                    guard let self, let last = self.lastReading, Date.now.timeIntervalSince(last.timestamp) < 120 else { return }
                    self.judge(last)
                }
            }
            return
        }
        if now.timeIntervalSince(arriving.since) >= Self.stayFor {
            log.notice("Stayed in \(park.id, privacy: .public)'s zone; checking in")
            self.arriving = nil
            if !appIsActive || manager.authorizationStatus == .authorizedAlways { stopPrecise() }
            Task { await state.autoArrive(at: park) }
        }
    }

    private func entered(_ parkID: String) {
        log.notice("Entered wake-up circle for \(parkID, privacy: .public)")
        insideWakeCircles.insert(parkID)
        startPrecise()
    }

    private func exited(_ parkID: String) {
        log.notice("Left wake-up circle for \(parkID, privacy: .public)")
        insideWakeCircles.remove(parkID)
        if let state, let park = Park.find(parkID), state.autoCheckedInPark?.id == parkID {
            Task { await state.autoLeave(from: park) }
        }
        if insideWakeCircles.isEmpty && !appIsActive { stopPrecise() }
    }

    // MARK: CLLocationManagerDelegate (delivered on the main thread, where the manager was made)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard state?.prefs.autoCheckIn == true else { return }
            if manager.authorizationStatus == .authorizedWhenInUse { manager.requestAlwaysAuthorization() }
            syncRegions()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let reading = locations.last else { return }
            log.debug("Reading ±\(Int(reading.horizontalAccuracy))m: \(reading.coordinate.latitude, privacy: .public), \(reading.coordinate.longitude, privacy: .public)")
            judge(reading)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// Finds where you are once, for the 📍 "which park am I at?" button.
@MainActor
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    func current() async -> CLLocation? {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
            case .denied, .restricted: finish(nil)
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated { finish(locations.last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(nil) }
    }
}

/// Phone notifications for automatic check-ins that happen while the app is closed.
enum Notifier {
    static let category = "AUTO_CHECK_IN"
    static let undoAction = "UNDO"

    static func requestPermission() {
        let center = UNUserNotificationCenter.current()
        let undo = UNNotificationAction(identifier: undoAction, title: "Undo", options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: category, actions: [undo], intentIdentifiers: [])])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(title: String, body: String, undo: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if undo { content.categoryIdentifier = category }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
