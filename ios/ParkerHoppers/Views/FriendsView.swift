import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            List {
                Section("At the park now") {
                    if state.friendCheckIns.isEmpty {
                        Text("No friends at the park right now.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(state.friendCheckIns) { visit in
                        HStack(spacing: 12) {
                            DogStack(dogs: visit.dogs, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(visit.person.name) & \(dogNames(visit.dogs))")
                                    .font(.headline)
                                Text("\(state.park(id: visit.parkID)?.name ?? "A park") · \(timeAgo(visit.arrivedAt))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Your pack") {
                    ForEach(state.friends) { friend in
                        HStack(spacing: 12) {
                            DogStack(dogs: friend.dogs, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.name)
                                    .font(.headline)
                                Text(friend.dogs.map { "\($0.name) the \($0.breed)" }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if state.currentCheckIn(for: friend) != nil {
                                Text("At park")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: "Join my pack on Parker Hoppers so our dogs can meet up at the park! 🐾") {
                        Label("Invite a friend", systemImage: "person.badge.plus")
                    }
                }
            }
        }
    }
}
