import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var tab = 0
    @State private var parksPath = NavigationPath()

    var body: some View {
        Group {
            switch state.status {
            case .loading:
                Image("AppIconSmall")
                    .resizable()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            case .needsJoin:
                JoinView()
            case .ready:
                TabView(selection: $tab) {
                    ParksView(path: $parksPath)
                        .tabItem { Label("Parks", systemImage: "map.fill") }
                        .tag(0)
                    MomentsView()
                        .tabItem { Label("Moments", systemImage: "photo.on.rectangle.angled") }
                        .tag(1)
                    FriendsView()
                        .tabItem { Label("Friends", systemImage: "person.2.fill") }
                        .tag(2)
                    MeView()
                        .tabItem { Label("Me", systemImage: "pawprint.fill") }
                        .tag(3)
                }
            }
        }
        .tint(Color.accentColor)
        .overlay(alignment: .top) {
            if let banner = state.banner {
                BannerView(banner: banner) { park in
                    tab = 0
                    parksPath = NavigationPath([park])
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
