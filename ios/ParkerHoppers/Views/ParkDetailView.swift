import SwiftUI
import MapKit

struct ParkDetailView: View {
    @Environment(AppState.self) private var state
    let park: Park
    @State private var showingCheckIn = false

    var body: some View {
        let visitors = state.visitors(at: park)
        let amHere = state.myCheckIn?.parkID == park.id

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: park.coordinate, latitudinalMeters: 800, longitudinalMeters: 800))) {
                    Annotation(park.name, coordinate: park.coordinate) {
                        ParkPin(count: state.dogCount(at: park))
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(park.name)
                        .font(.title2.bold())
                    Text(park.neighborhood)
                        .foregroundStyle(.secondary)
                }

                if amHere {
                    Button(role: .destructive) {
                        withAnimation { state.checkOut() }
                    } label: {
                        Label("Check out", systemImage: "figure.walk.departure")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button {
                        showingCheckIn = true
                    } label: {
                        Label("We're here!", systemImage: "pawprint.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("At the park now")
                        .font(.headline)
                    if visitors.isEmpty {
                        Text("None of your friends are here yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(visitors) { visit in
                        VisitorRow(checkIn: visit, isMe: visit.person.id == state.me.id)
                    }
                    if park.otherDogCount > 0 {
                        Label("\(park.otherDogCount) more pups from outside your network",
                              systemImage: "pawprint")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                Toggle(isOn: alertsBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arrival alerts")
                        Text("Get notified when friends show up here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCheckIn) {
            CheckInSheet(park: park)
        }
    }

    private var alertsBinding: Binding<Bool> {
        Binding(
            get: { state.myParkIDs.contains(park.id) },
            set: { _ in state.toggleAlerts(for: park) }
        )
    }
}

private struct VisitorRow: View {
    let checkIn: CheckIn
    var isMe = false

    var body: some View {
        HStack(spacing: 12) {
            DogStack(dogs: checkIn.dogs, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(dogNames(checkIn.dogs))
                    .font(.headline)
                Text(isMe
                     ? "You · arrived \(timeAgo(checkIn.arrivedAt))"
                     : "with \(checkIn.person.name) · arrived \(timeAgo(checkIn.arrivedAt))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct CheckInSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let park: Park
    @State private var selected: Set<Dog.ID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(state.me.dogs) { dog in
                        Button {
                            if selected.contains(dog.id) {
                                selected.remove(dog.id)
                            } else {
                                selected.insert(dog.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                DogAvatar(dog: dog, size: 36)
                                Text(dog.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selected.contains(dog.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selected.contains(dog.id) ? Color.accentColor : Color.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Who's coming along?")
                } footer: {
                    Text("Your friends will see you here. You'll be checked out automatically after 90 minutes.")
                }
            }
            .navigationTitle(park.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Check in") {
                        state.checkIn(at: park, with: state.me.dogs.filter { selected.contains($0.id) })
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear {
                selected = Set(state.me.dogs.map(\.id))
            }
        }
        .presentationDetents([.medium])
    }
}
