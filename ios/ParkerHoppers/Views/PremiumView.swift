import SwiftUI

struct PremiumView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Image(systemName: "pawprint.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor.gradient)
                        Text("Parker Hoppers Plus")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("Never miss a playdate.")
                            .foregroundStyle(.secondary)
                    }

                    WidgetPreview()

                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(icon: "square.grid.2x2.fill",
                                   title: "Home-screen widget",
                                   detail: "See who's at your parks without opening the app.")
                        FeatureRow(icon: "bell.badge.fill",
                                   title: "Instant arrival alerts",
                                   detail: "Get pinged the moment a friend's pup walks in.")
                        FeatureRow(icon: "airtag.fill",
                                   title: "AirTag sharing, made easy",
                                   detail: "Step-by-step help sharing your dog's AirTag with trusted friends in Apple's Find My, so they can help if your pup slips away.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 8) {
                        Button {
                            state.isPremium.toggle()
                            dismiss()
                        } label: {
                            Text(state.isPremium ? "Turn off Plus (demo)" : "Try Plus (demo)")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Text("Prototype only. No payment is taken.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A look-alike of the future home-screen widget, built from the same data.
private struct WidgetPreview: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let busiest = state.parks.max { state.visitors(at: $0).count < state.visitors(at: $1).count }

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill")
                Text("Parker Hoppers")
            }
            .font(.caption2.bold())
            .foregroundStyle(Color.accentColor)

            Spacer(minLength: 0)

            if let park = busiest {
                let visitors = state.visitors(at: park)
                Text(park.name)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                DogStack(dogs: visitors.flatMap(\.dogs), size: 24)
                Text(visitors.count == 1 ? "1 friend here" : "\(visitors.count) friends here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 160, height: 160, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
