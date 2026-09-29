import SwiftUI
import MapKit

struct ParkDetailView: View {
    @Environment(AppState.self) private var state
    let park: Park
    @State private var showingCheckIn = false

    private var amHere: Bool { state.myCheckIn?.parkID == park.id }

    private var directions: URL {
        URL(string: "https://maps.apple.com/?daddr=\(park.latitude),\(park.longitude)&q=\(park.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
    }

    var body: some View {
        let visitors = state.visitors(at: park)
        let count = state.dogCount(at: park)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Map(initialPosition: .region(MKCoordinateRegion(center: park.coordinate, latitudinalMeters: 700, longitudinalMeters: 700))) {
                    Annotation(park.name, coordinate: park.coordinate) {
                        ParkPin(count: count, friendsHere: !visitors.isEmpty)
                    }
                    .annotationTitles(.hidden)
                    if let zone = park.zone {
                        MapCircle(center: park.coordinate, radius: zone.radius)
                            .foregroundStyle(Color.accentColor.opacity(0.15))
                            .stroke(Color.accentColor, lineWidth: 1)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(park.name).font(.title2.bold())
                    Text("\(park.area) · \(park.address)").foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let access = park.access { Badge(text: "🔒 \(access)") }
                    if let status = park.offLeashStatus() { Badge(text: status.text, highlighted: status.open) }
                    if let fenced = park.fenced { Badge(text: fenced ? "Fenced" : "Open field") }
                }

                HStack(spacing: 10) {
                    if amHere {
                        Button(role: .destructive) {
                            Task {
                                if await state.attempt({ try await state.checkOut() }) {
                                    state.showBanner("Checked out", "Thanks for hopping by! 🐾")
                                }
                            }
                        } label: {
                            Text("Check out").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            showingCheckIn = true
                        } label: {
                            Label("We’re here!", systemImage: "pawprint.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Link(destination: directions) {
                        Image(systemName: "location.north.line.fill").frame(width: 30)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Directions")
                }
                .controlSize(.large)

                Text("At the park now").font(.headline).padding(.top, 6)
                ParkMix(dogs: visitors.flatMap(state.dogs(of:)))
                Card {
                    if visitors.isEmpty {
                        Text("No one’s checked in here yet.").foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(visitors) { visit in
                                VisitorRow(checkIn: visit)
                            }
                        }
                    }
                }

                if state.prefs.autoCheckIn && park.zone != nil && !amHere {
                    Button("Demo: pretend I just walked in") {
                        state.autoCheckIn.pretendArrival(at: park)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("PARK INFO").font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                VStack(spacing: 0) {
                    InfoRow(label: "Hours", value: park.hoursText)
                    Divider().padding(.leading)
                    InfoRow(label: "Auto check-in", value: park.zone.map {
                        "Within \(Int($0.radius)) m\($0.maxAccuracy != nil ? ", outdoors only" : "")"
                    } ?? "Check in by hand here")
                    Divider().padding(.leading)
                    Toggle(isOn: Binding(get: { state.alertsOn(park) }, set: { _ in state.toggleAlerts(park) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Arrival alerts")
                            Text("Get a heads-up when friends show up here").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCheckIn) { CheckInSheet(park: park) }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .padding()
    }
}

/// "Right now: 2 large · 1 small", plus a heads-up about dogs that are shy or need space.
private struct ParkMix: View {
    let dogs: [Dog]

    var body: some View {
        let mix = DogSize.allCases.compactMap { size -> String? in
            let count = dogs.filter { $0.size == size }.count
            return count > 0 ? "\(count) \(size.label.lowercased())" : nil
        }
        if !mix.isEmpty {
            Text("🐕 Right now: \(mix.joined(separator: " · "))").font(.subheadline).foregroundStyle(.secondary)
        }
        ForEach(dogs.filter(\.needsCare)) { dog in
            Text("⚠️ \(dog.name) \(dog.comfort?.headsUp ?? "")")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct VisitorRow: View {
    @Environment(AppState.self) private var state
    let checkIn: CheckIn

    var body: some View {
        let dogs = state.dogs(of: checkIn)
        let who = checkIn.personID == state.myID ? "You" : "with \(state.person(checkIn.personID)?.name ?? "someone")"
        HStack(spacing: 12) {
            DogStack(dogs: dogs, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(dogNames(dogs)).font(.headline)
                Text("\(who) · arrived \(timeAgo(checkIn.arrivedAt))").font(.subheadline).foregroundStyle(.secondary)
                let details = dogs.count == 1
                    ? dogs[0].details
                    : dogs.filter { !$0.details.isEmpty }.map { "\($0.name): \($0.details)" }.joined(separator: " · ")
                if !details.isEmpty {
                    Text(details).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct CheckInSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let park: Park
    @State private var selected: Set<String> = []
    @State private var saving = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(state.myDogs) { dog in
                        Button {
                            if selected.contains(dog.id) { selected.remove(dog.id) } else { selected.insert(dog.id) }
                        } label: {
                            HStack(spacing: 12) {
                                DogAvatar(dog: dog, size: 36)
                                Text(dog.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selected.contains(dog.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selected.contains(dog.id) ? Color.accentColor : Color.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Who’s coming along?")
                } footer: {
                    Text("Your friends will see you here. You’ll be checked out automatically after 90 minutes.")
                }
            }
            .navigationTitle(park.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Check in") {
                        Task {
                            saving = true
                            let dogs = state.myDogs.filter { selected.contains($0.id) }
                            if await state.attempt({ try await state.checkIn(park: park, dogIDs: dogs.map(\.id)) }) {
                                dismiss()
                                state.showBanner("You’re checked in!", "Friends can now see \(dogNames(dogs)) at \(park.name).")
                            }
                            saving = false
                        }
                    }
                    .disabled(selected.isEmpty || saving)
                }
            }
            .onAppear { selected = Set(state.myDogs.map(\.id)) }
        }
        .presentationDetents([.medium])
    }
}
