import SwiftUI
import PhotosUI

/// Name-only sign-up: your first name and your dog. No email or password.
struct JoinView: View {
    @Environment(AppState.self) private var state
    @State private var name = ""
    @State private var dogName = ""
    @State private var breed = ""
    @State private var color = colorChoices[1]
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var saving = false

    private var ready: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !dogName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image("AppIconSmall")
                    .resizable()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .orange.opacity(0.35), radius: 12, y: 6)
                    .padding(.top, 40)
                Text("Park Hoppers").font(.largeTitle.bold())
                Text("See when your friends’ dogs are at the park, so you can meet up.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                DogPhotoPicker(item: $pickerItem, photo: $photo, color: color, name: dogName)
                    .padding(.vertical, 6)

                VStack(spacing: 10) {
                    field("Your first name", text: $name).textContentType(.givenName)
                    field("Your dog’s name", text: $dogName)
                    field("Breed (optional)", text: $breed)
                }
                DogColorPicker(selection: $color)

                Button {
                    Task { await join() }
                } label: {
                    Label(saving ? "Joining…" : "Join the pack", systemImage: "pawprint.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!ready || saving)

                Text("No email or password. Everyone testing Park Hoppers can see your first name, your dogs, and the park you check in at.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func join() async {
        saving = true
        defer { saving = false }
        let dog = Dog(id: "", name: dogName.trimmingCharacters(in: .whitespaces),
                      breed: breed.trimmingCharacters(in: .whitespaces).isEmpty ? "Good dog" : breed, colorHex: color)
        await state.attempt {
            try await state.join(name: name.trimmingCharacters(in: .whitespaces), dog: dog, photo: photo)
        }
    }
}
