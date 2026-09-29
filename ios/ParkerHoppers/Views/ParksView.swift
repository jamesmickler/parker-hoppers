import SwiftUI
import MapKit

struct ParksView: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath
    @State private var nearby: (park: Park, meters: Double)?
    @State private var locating = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let mine = state.myCheckIn, let park = Park.find(mine.parkID) {
                        HereCard(checkIn: mine, park: park)
                    }

                    ParksMap(path: $path)

                    if !state.myParks.isEmpty {
                        Text("Your parks").font(.title3.bold()).padding(.top, 10)
                        ForEach(state.myParks) { park in
                            NavigationLink(value: park) { ParkRow(park: park) }.buttonStyle(.plain)
                        }
                    }
                    if !state.otherParks.isEmpty {
                        Text("More dog parks").font(.title3.bold()).padding(.top, 10)
                        ForEach(state.otherParks) { park in
                            NavigationLink(value: park) { ParkRow(park: park) }.buttonStyle(.plain)
                        }
                    }

                    Text("Public park locations and hours come from the City of Charleston and Charleston County Parks." + (state.prefs.demoMode
                        ? " Demo Mode is on: tap Demo to have a made-up friend (Maya, Theo, Priya, Sam or Dana) arrive."
                        : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Park Hoppers")
            .navigationDestination(for: Park.self) { park in
                ParkDetailView(park: park)
            }
            .refreshable { await state.refresh() }
            .toolbar {
                if state.prefs.demoMode {
                    // Labeled "Demo" so it isn't mistaken for notifications.
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            state.simulateArrival()
                        } label: {
                            // Built by hand: toolbars shrink a plain Label down to just its icon.
                            HStack(spacing: 4) {
                                Image(systemName: "bell.badge")
                                Text("Demo").fontWeight(.semibold)
                            }
                            .padding(.horizontal, 4)
                        }
                        .accessibilityLabel("Demo: a friend arrives")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await locate() }
                    } label: {
                        Label("Find the park I’m at", systemImage: locating ? "location.fill" : "location")
                    }
                }
            }
            .sheet(isPresented: Binding(get: { nearby != nil }, set: { if !$0 { nearby = nil } })) {
                if let nearby {
                    NearbySheet(park: nearby.park, meters: nearby.meters) { park in
                        self.nearby = nil
                        path.append(park)
                    }
                }
            }
        }
    }

    private func locate() async {
        locating = true
        defer { locating = false }
        guard let here = await OneShotLocation().current() else {
            state.showBanner("Couldn’t find your location", "Allow location access for Park Hoppers in Settings, then try again.")
            return
        }
        let ranked = Park.all.map { ($0, here.distance(from: $0.location)) }.sorted { $0.1 < $1.1 }
        if let first = ranked.first { nearby = (first.0, first.1) }
    }
}

private struct HereCard: View {
    @Environment(AppState.self) private var state
    let checkIn: CheckIn
    let park: Park

    var body: some View {
        HStack(spacing: 12) {
            DogStack(dogs: state.dogs(of: checkIn), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("You’re at \(park.name)").font(.headline)
                Text("Checked in \(timeAgo(checkIn.arrivedAt))\(state.autoCheckedInPark != nil ? " automatically" : "") · auto check-out after 90 min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Leave") {
                Task {
                    if await state.attempt({ try await state.checkOut() }) {
                        state.showBanner("Checked out", "Thanks for hopping by! 🐾")
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ParksMap: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath

    private var downtown: MKCoordinateRegion {
        let parks = Park.all.filter { Park.downtownIDs.contains($0.id) }
        let lats = parks.map(\.latitude), lngs = parks.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lngs.min()! + lngs.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (lats.max()! - lats.min()!) * 1.6, longitudeDelta: (lngs.max()! - lngs.min()!) * 1.4)
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        // Read the counts here, not inside the map's content, so the pins update when people check in.
        let counts = Dictionary(uniqueKeysWithValues: Park.all.map { ($0.id, state.dogCount(at: $0)) })
        let busy = Set(Park.all.filter { !state.visitors(at: $0).isEmpty }.map(\.id))
        Map(initialPosition: .region(downtown)) {
            ForEach(Park.all) { park in
                Annotation(park.name, coordinate: park.coordinate) {
                    ParkPin(count: counts[park.id] ?? 0, friendsHere: busy.contains(park.id))
                        .onTapGesture { path.append(park) }
                }
                .annotationTitles(.hidden)
            }
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct ParkRow: View {
    @Environment(AppState.self) private var state
    let park: Park

    var body: some View {
        let dogs = state.visitors(at: park).flatMap { state.dogs(of: $0) }
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(park.name).font(.headline)
                    if state.alertsOn(park) {
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(Color.accentColor)
                    }
                }
                Text(park.access.map { "\(park.area) · \($0)" } ?? park.area)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if dogs.isEmpty {
                    Text("No one here yet").font(.caption).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        DogStack(dogs: dogs, size: 24)
                        Text(dogNames(dogs, limit: 2)).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text("\(state.dogCount(at: park))").font(.title2.bold())
                Text("pups").font(.caption2).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct NearbySheet: View {
    @Environment(\.dismiss) private var dismiss
    let park: Park
    let meters: Double
    let open: (Park) -> Void
    @State private var checkingIn = false

    private var atPark: Bool { meters <= (park.zone?.radius ?? 150) }

    private var distance: String {
        let miles = meters / 1609.34
        return miles < 0.1 ? "\(Int(meters * 3.281)) ft" : String(format: "%.1f mi", miles)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Card {
                    VStack(spacing: 4) {
                        Text(park.name).font(.headline)
                        Text("\(park.area) · \(distance) away (\(Int(meters)) m)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                Button {
                    checkingIn = true
                } label: {
                    Label(atPark ? "Check in here" : "Pretend I’m there (demo)", systemImage: "pawprint.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("View park") { open(park) }
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(atPark ? "Looks like you’re at the park!" : "Nearest dog park")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $checkingIn, onDismiss: { dismiss() }) { CheckInSheet(park: park) }
        }
        .presentationDetents([.medium])
    }
}
