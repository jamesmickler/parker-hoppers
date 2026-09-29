import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            List {
                Section("At the park now") {
                    if state.friendCheckIns.isEmpty {
                        Text("No friends at the park right now.").foregroundStyle(.secondary)
                    }
                    ForEach(state.friendCheckIns) { visit in
                        let dogs = state.dogs(of: visit)
                        HStack(spacing: 12) {
                            DogStack(dogs: dogs, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(state.person(visit.personID)?.name ?? "") & \(dogNames(dogs))").font(.headline)
                                Text("\(Park.find(visit.parkID)?.name ?? "") · \(timeAgo(visit.arrivedAt))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Your pack") {
                    ForEach(state.friends) { friend in
                        let dogs = friend.dogIDs.compactMap(state.dog)
                        HStack(spacing: 12) {
                            DogStack(dogs: dogs, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(friend.name).font(.headline)
                                    if friend.isDemo {
                                        Text("DEMO")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                Text(dogs.map { "\($0.name) the \($0.breed)" }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if state.checkIn(for: friend.id) != nil {
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
            .refreshable { await state.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: URL(string: "https://jamesmickler.github.io/parker-hoppers/")!,
                              message: Text("Join my pack on Park Hoppers so our dogs can meet up at the park! 🐾")) {
                        Label("Invite a friend", systemImage: "person.badge.plus")
                    }
                }
            }
        }
    }
}
