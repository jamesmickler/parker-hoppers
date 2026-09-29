import SwiftUI

/// A round dog badge: the dog's photo, or its first letter on its color.
struct DogAvatar: View {
    let dog: Dog
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(dog.color.gradient)
            Text(dog.name.prefix(1).uppercased())
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
            if let url = dog.photoURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
        .accessibilityLabel(dog.name)
    }
}

/// Overlapping dog badges, e.g. everyone at a park.
struct DogStack: View {
    let dogs: [Dog]
    var size: CGFloat = 32
    var maxShown = 4

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(dogs.prefix(maxShown)) { dog in
                DogAvatar(dog: dog, size: size)
            }
            if dogs.count > maxShown {
                Text("+\(dogs.count - maxShown)")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.gray))
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            }
        }
    }
}

/// The pop-down alert at the top of the screen, like an iPhone notification.
struct BannerView: View {
    @Environment(AppState.self) private var state
    let banner: AppState.Banner
    let openPark: (Park) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image("AppIconSmall")
                .resizable()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title).font(.subheadline.bold())
                Text(banner.message).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let action = banner.action {
                Button(action.label) {
                    withAnimation { state.banner = nil }
                    action.run()
                }
                .font(.subheadline.bold())
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            } else {
                Text("now").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .padding(.horizontal)
        .onTapGesture {
            withAnimation { state.banner = nil }
            if let park = Park.find(banner.parkID) { openPark(park) }
        }
    }
}

/// Map marker: how many pups are at a park, orange when friends are there.
struct ParkPin: View {
    let count: Int
    let friendsHere: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "pawprint.fill")
            if count > 0 { Text("\(count)").bold() }
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(friendsHere ? Color.accentColor : Color.gray))
        .overlay(Capsule().stroke(.white, lineWidth: 2))
    }
}

/// A small gray pill, e.g. "Residents only" or "Fenced".
struct Badge: View {
    let text: String
    var highlighted = false

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(highlighted ? Color.green : Color.secondary)
            .background(highlighted ? Color.green.opacity(0.15) : Color(.systemGray5), in: Capsule())
    }
}

/// White rounded panel used for rows and cards.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

let colorChoices = ["#F2A23A", "#5B8DEF", "#34A853", "#FF6B8B", "#A77BF3", "#2BB5B8", "#C98A4B", "#8E8E93"]

/// A row of color dots for picking a dog's badge color.
struct DogColorPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(colorChoices, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 30, height: 30)
                    .overlay {
                        if hex == selection {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selection = hex }
                    .accessibilityLabel("Color \(hex)")
            }
        }
    }
}
