import SwiftUI
import MapKit

struct ParksView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let mine = state.myCheckIn, let park = state.park(id: mine.parkID) {
                        MyCheckInCard(checkIn: mine, park: park)
                    }

                    ParksMap()

                    if !state.myParks.isEmpty {
                        Text("Your parks")
                            .font(.title3.bold())
                            .padding(.top, 4)
                        ForEach(state.myParks) { park in
                            NavigationLink(value: park) { ParkRow(park: park) }
                                .buttonStyle(.plain)
                        }
                    }

                    if !state.otherParks.isEmpty {
                        Text("Nearby")
                            .font(.title3.bold())
                            .padding(.top, 4)
                        ForEach(state.otherParks) { park in
                            NavigationLink(value: park) { ParkRow(park: park) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Parker Hoppers")
            .navigationDestination(for: Park.self) { park in
                ParkDetailView(park: park)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        state.simulateFriendArrival()
                    } label: {
                        Label("Simulate a friend arriving", systemImage: "bell.badge")
                    }
                }
            }
        }
    }
}

private struct ParksMap: View {
    @Environment(AppState.self) private var state

    private let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.775, longitude: -122.445),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.11)
    )

    var body: some View {
        Map(initialPosition: .region(region)) {
            ForEach(state.parks) { park in
                Annotation(park.name, coordinate: park.coordinate) {
                    ParkPin(count: state.dogCount(at: park))
                }
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct MyCheckInCard: View {
    @Environment(AppState.self) private var state
    let checkIn: CheckIn
    let park: Park

    var body: some View {
        HStack(spacing: 12) {
            DogStack(dogs: checkIn.dogs, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("You're at \(park.name)")
                    .font(.headline)
                Text("Checked in \(timeAgo(checkIn.arrivedAt))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Leave") {
                withAnimation { state.checkOut() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ParkRow: View {
    @Environment(AppState.self) private var state
    let park: Park

    var body: some View {
        let friendDogs = state.visitors(at: park).flatMap(\.dogs)

        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(park.name)
                        .font(.headline)
                    if state.myParkIDs.contains(park.id) {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(park.neighborhood)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if friendDogs.isEmpty {
                    Text(park.otherDogCount > 0 ? "No friends here yet" : "Quiet right now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        DogStack(dogs: friendDogs, size: 26)
                        Text(dogNames(friendDogs, limit: 2))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text("\(state.dogCount(at: park))")
                    .font(.title2.bold())
                Text("pups")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
