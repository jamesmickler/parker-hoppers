import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TabView {
            ParksView()
                .tabItem { Label("Parks", systemImage: "map.fill") }
            FeedView()
                .tabItem { Label("Moments", systemImage: "photo.on.rectangle.angled") }
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
            ProfileView()
                .tabItem { Label("Me", systemImage: "pawprint.fill") }
        }
        .overlay(alignment: .top) {
            if let banner = state.banner {
                BannerView(banner: banner)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { state.banner = nil } }
            }
        }
    }
}
