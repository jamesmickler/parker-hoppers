import SwiftUI

struct PlusView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image("AppIconSmall").resizable().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 16))
                        Text("Parker Hoppers Plus").font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Text("Never miss a playdate.").foregroundStyle(.secondary)
                    }

                    WidgetPreview()
                    Text("Home-screen widget preview").font(.caption).foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 18) {
                        feature("📱", "Home-screen widget", "See who’s at your parks without opening the app.")
                        feature("⚡️", "Instant arrival alerts", "Get pinged the moment a friend’s pup walks in.")
                        feature("📍", "AirTag sharing, made easy", "Step-by-step help sharing your dog’s AirTag with trusted friends in Apple’s Find My, so they can help if your pup slips away.")
                    }

                    Button {
                        let on = !state.prefs.isPlus
                        state.updatePrefs { $0.isPlus = on }
                        dismiss()
                        state.showBanner(on ? "Welcome to Plus! ✨" : "Plus turned off",
                                         on ? "Your widget and instant alerts are on." : "You’re back on the free plan.")
                    } label: {
                        Text(state.prefs.isPlus ? "Turn off Plus (demo)" : "Try Plus (demo)").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Prototype only. No payment is taken.").font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func feature(_ emoji: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji).font(.title2).frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

/// A look-alike of the future home-screen widget, built from the same data.
private struct WidgetPreview: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let park = Park.all.max { state.visitors(at: $0).count < state.visitors(at: $1).count } ?? Park.all[0]
        let visitors = state.visitors(at: park)
        VStack(alignment: .leading, spacing: 6) {
            Label("Parker Hoppers", systemImage: "pawprint.fill")
                .font(.caption2.bold())
                .foregroundStyle(Color.accentColor)
            Spacer(minLength: 0)
            Text(park.name).font(.subheadline.bold()).lineLimit(2)
            DogStack(dogs: visitors.flatMap { state.dogs(of: $0) }, size: 24)
            Text(visitors.count == 1 ? "1 friend here" : "\(visitors.count) friends here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 170, height: 170, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }
}
