import SwiftUI
import CoreLocation
import PhotosUI

struct MeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @State private var showingPlus = false
    @State private var showingAddDog = false
    @State private var confirmingLeave = false

    var body: some View {
        NavigationStack {
            List {
                Section("Your pack") {
                    ForEach(state.myDogs) { dog in
                        HStack(spacing: 12) {
                            DogAvatar(dog: dog)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dog.name).font(.headline)
                                Text(dog.breed).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button { showingAddDog = true } label: { Label("Add a dog", systemImage: "plus") }
                }

                Section {
                    Button { showingPlus = true } label: {
                        HStack(spacing: 12) {
                            Image("AppIconSmall").resizable().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.prefs.isPlus ? "You have Parker Hoppers Plus" : "Get Parker Hoppers Plus")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Home-screen widget, instant alerts, AirTag sharing help")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Friend arrival alerts", isOn: Binding(
                        get: { state.prefs.alertsEnabled },
                        set: { value in state.updatePrefs { $0.alertsEnabled = value } }
                    ))
                    Toggle(isOn: Binding(
                        get: { state.prefs.autoCheckIn },
                        set: { value in
                            state.updatePrefs { $0.autoCheckIn = value }
                            if value { state.autoCheckIn.enable() } else { state.autoCheckIn.disable() }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto check-in at my parks")
                            Text("Checks you in when you arrive at a park with 🔔 alerts on, even with the app closed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if state.prefs.autoCheckIn {
                        AutoCheckInStatus()
                    }
                } header: {
                    Text("At the park")
                }

                Section("Privacy") {
                    LabeledContent("Who sees me at the park", value: "Friends only")
                    LabeledContent("Who sees my posts", value: "Friends only")
                }

                Section {
                    Button("Leave Parker Hoppers", role: .destructive) { confirmingLeave = true }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deletes your name, dogs, check-ins and posts from Parker Hoppers.")
                }

                Section {
                    Button("Reset demo pack", role: .destructive) {
                        state.resetDemoPack()
                        state.showBanner("Demo pack reset", "Maya, Theo and friends went home.")
                    }
                } header: {
                    Text("Demo pack")
                } footer: {
                    Text("Sends Maya, Theo and the other made-up friends home. Real people aren’t affected.")
                }
            }
            .navigationTitle(state.me?.name ?? "Me")
            .sheet(isPresented: $showingPlus) { PlusView() }
            .sheet(isPresented: $showingAddDog) { AddDogSheet() }
            .confirmationDialog("Leave Parker Hoppers?", isPresented: $confirmingLeave, titleVisibility: .visible) {
                Button("Leave and delete my data", role: .destructive) {
                    Task { await state.attempt { try await state.leave() } }
                }
            } message: {
                Text("This deletes your name, dogs, check-ins and posts.")
            }
        }
    }
}

/// Explains what location permission allows, and links to Settings if it's missing.
private struct AutoCheckInStatus: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL

    var body: some View {
        let (text, needsSettings): (String, Bool) = switch state.autoCheckIn.authorization {
        case .authorizedAlways where !state.autoCheckIn.canWatchInBackground:
            ("Location: Always, but this device can’t watch parks in the background (the Simulator can’t). It checks you in while the app is open.", false)
        case .authorizedAlways: ("Location: Always ✓ Works with the app closed.", false)
        case .authorizedWhenInUse: ("Location: While Using. It only works while the app is open. Choose “Always” in Settings for pocket check-ins.", true)
        case .denied, .restricted: ("Location is off for Parker Hoppers. Turn it on in Settings.", true)
        default: ("Waiting for location permission…", false)
        }
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.caption).foregroundStyle(.secondary)
            if needsSettings {
                Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                    .font(.caption.bold())
            }
        }
    }
}

private struct AddDogSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var breed = ""
    @State private var color = colorChoices[1]
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DogPhotoPicker(item: $pickerItem, photo: $photo, color: color, name: name)
                        .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name", text: $name)
                    TextField("Breed (optional)", text: $breed)
                }
                Section("Badge color") {
                    DogColorPicker(selection: $color)
                }
            }
            .navigationTitle("Add a dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        Task {
                            saving = true
                            let dogName = name.trimmingCharacters(in: .whitespaces)
                            let dog = Dog(id: "", name: dogName, breed: breed.isEmpty ? "Good dog" : breed, colorHex: color)
                            if await state.attempt({ try await state.addDog(dog, photo: photo) }) {
                                dismiss()
                                state.showBanner("\(dogName) joined your pack!", "You can bring them when you check in.")
                            }
                            saving = false
                        }
                    }
                    .disabled(saving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Round photo picker used when adding a dog or joining.
struct DogPhotoPicker: View {
    @Binding var item: PhotosPickerItem?
    @Binding var photo: UIImage?
    let color: String
    let name: String

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            ZStack {
                Circle().fill(Color(hex: color).gradient)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else if let first = name.first {
                    Text(String(first).uppercased()).font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
                } else {
                    Image(systemName: "camera.fill").font(.title).foregroundStyle(.white)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .frame(maxWidth: .infinity)
        }
        .onChange(of: item) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) { photo = UIImage(data: data) }
            }
        }
        .accessibilityLabel("Add a photo of your dog")
    }
}
