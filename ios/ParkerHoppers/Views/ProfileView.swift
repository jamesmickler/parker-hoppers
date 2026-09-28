import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var state
    @State private var showingPremium = false
    @State private var showingAddDog = false

    var body: some View {
        @Bindable var state = state

        NavigationStack {
            List {
                Section("Your pack") {
                    ForEach(state.me.dogs) { dog in
                        HStack(spacing: 12) {
                            DogAvatar(dog: dog)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dog.name)
                                    .font(.headline)
                                Text(dog.breed)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button {
                        showingAddDog = true
                    } label: {
                        Label("Add a dog", systemImage: "plus")
                    }
                }

                Section {
                    Button {
                        showingPremium = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.isPremium ? "You have Parker Hoppers Plus" : "Get Parker Hoppers Plus")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Widget, instant alerts, AirTag sharing")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Auto check-in at my parks", isOn: $state.autoCheckIn)
                    Toggle("Friend arrival alerts", isOn: $state.alertsEnabled)
                } header: {
                    Text("At the park")
                } footer: {
                    Text("Auto check-in will use your location to notice when you arrive at one of your parks. It isn't hooked up yet in this prototype.")
                }

                Section("Privacy") {
                    LabeledContent("Who sees me at the park", value: "Friends only")
                    LabeledContent("Who sees my posts", value: "Friends only")
                }
            }
            .navigationTitle("Me")
            .sheet(isPresented: $showingPremium) {
                PremiumView()
            }
            .sheet(isPresented: $showingAddDog) {
                AddDogSheet()
            }
        }
    }
}

private struct AddDogSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var breed = ""
    @State private var tint = Color.blue

    private let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .teal, .brown, .gray]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        DogAvatar(dog: Dog(name: name, breed: breed, tint: tint), size: 80)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name", text: $name)
                    TextField("Breed", text: $breed)
                }
                Section("Badge color") {
                    HStack {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if color == tint {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { tint = color }
                        }
                    }
                }
            }
            .navigationTitle("Add a dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        state.addDog(name: name, breed: breed.isEmpty ? "Good dog" : breed, tint: tint)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
