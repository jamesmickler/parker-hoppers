import SwiftUI
import CoreLocation
import PhotosUI

struct MeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @State private var showingPlus = false
    @State private var showingAddDog = false
    @State private var editingDog: Dog?
    @State private var confirmingLeave = false

    var body: some View {
        NavigationStack {
            List {
                Section("Your pack") {
                    ForEach(state.myDogs) { dog in
                        Button { editingDog = dog } label: {
                            HStack(spacing: 12) {
                                DogAvatar(dog: dog)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dog.name).font(.headline).foregroundStyle(.primary)
                                    Text([dog.breedText, dog.details.isEmpty ? "Tap to add size and comfort with other dogs" : dog.details]
                                        .filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showingAddDog = true } label: { Label("Add a dog", systemImage: "plus") }
                }

                Section {
                    Button { showingPlus = true } label: {
                        HStack(spacing: 12) {
                            Image("AppIconSmall").resizable().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.prefs.isPlus ? "You have Park Hoppers Plus" : "Get Park Hoppers Plus")
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
                        set: { state.setAutoCheckIn($0) }
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
                    Button("Leave Park Hoppers", role: .destructive) { confirmingLeave = true }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deletes your name, dogs, check-ins and posts from Park Hoppers.")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { state.prefs.demoMode },
                        set: { on in
                            state.setDemoMode(on)
                            state.showBanner(on ? "Demo Mode is on" : "Demo Mode is off",
                                             on ? "Tap Demo on the Parks tab to have a made-up friend arrive." : "The demo friends are gone.")
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Demo Mode")
                            Text("Adds a Demo button on the Parks tab that makes a made-up friend arrive, so you can show off alerts without a second phone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if state.prefs.demoMode {
                        Button("Send demo friends home", role: .destructive) {
                            state.resetDemoPack()
                            state.showBanner("Demo friends went home", "Maya, Theo and friends left the parks.")
                        }
                    }
                } header: {
                    Text("Presenting")
                }
            }
            .navigationTitle(state.me?.name ?? "Me")
            .sheet(isPresented: $showingPlus) { PlusView() }
            .sheet(isPresented: $showingAddDog) { DogFormSheet() }
            .sheet(item: $editingDog) { DogFormSheet(editing: $0) }
            .confirmationDialog("Leave Park Hoppers?", isPresented: $confirmingLeave, titleVisibility: .visible) {
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
        case .denied, .restricted: ("Location is off for Park Hoppers. Turn it on in Settings.", true)
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

/// Adding a new dog, or editing one of mine.
private struct DogFormSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let editing: Dog?
    @State private var name: String
    @State private var breed: String
    @State private var color: String
    @State private var size: DogSize?
    @State private var comfort: DogComfort?
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var saving = false

    init(editing: Dog? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _breed = State(initialValue: editing?.breedText ?? "")
        _color = State(initialValue: editing?.colorHex ?? colorChoices[1])
        _size = State(initialValue: editing?.size)
        _comfort = State(initialValue: editing?.comfort)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DogPhotoPicker(item: $pickerItem, photo: $photo, color: color, name: name, photoURL: editing?.photoURL)
                        .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name", text: $name)
                    TextField("Breed (optional)", text: $breed)
                }
                Section("Size") {
                    DogSizePicker(selection: $size)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    DogComfortPicker(selection: $comfort)
                }
                Section("Badge color") {
                    DogColorPicker(selection: $color)
                }
            }
            .navigationTitle(editing.map { "Edit \($0.name)" } ?? "Add a dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        Task {
                            saving = true
                            let dogName = name.trimmingCharacters(in: .whitespaces)
                            let breedName = breed.trimmingCharacters(in: .whitespaces)
                            let dog = Dog(id: editing?.id ?? "", name: dogName, breed: breedName.isEmpty ? "Good dog" : breedName,
                                          colorHex: color, photoURL: editing?.photoURL, size: size, comfort: comfort)
                            if let editing {
                                if await state.attempt({ try await state.updateDog(dog, photo: photo) }) {
                                    dismiss()
                                    state.showBanner("\(dogName) is updated", editing.details == dog.details
                                                     ? "Saved." : "Friends see the new details at the park.")
                                }
                            } else if await state.attempt({ try await state.addDog(dog, photo: photo) }) {
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
    /// The dog's current photo, when editing.
    var photoURL: URL?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            ZStack {
                Circle().fill(Color(hex: color).gradient)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else if let photoURL {
                    AsyncImage(url: photoURL) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
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
