import SwiftUI
import UserNotifications

@main
struct ParkerHoppersApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let state = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .task { await state.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: state.appBecameActive()
            case .background: state.appWentToBackground()
            default: break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Create the app's state (and its location watcher) right away: when iOS launches the
        // app in the background because you walked into a park, that news arrives immediately.
        _ = AppState.shared
        return true
    }

    /// The "Undo" button on an automatic check-in notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.actionIdentifier == Notifier.undoAction else { return completionHandler() }
        Task { @MainActor in
            await AppState.shared.undoAutoCheckIn()
            completionHandler()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
