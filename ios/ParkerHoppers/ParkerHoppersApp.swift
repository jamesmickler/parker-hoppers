import SwiftUI

@main
struct ParkerHoppersApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
        }
    }
}
