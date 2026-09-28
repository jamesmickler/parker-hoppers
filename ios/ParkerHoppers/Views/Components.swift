import SwiftUI

/// A round dog badge. Stands in for a profile photo until dogs have real ones.
struct DogAvatar: View {
    let dog: Dog
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(dog.tint.gradient)
            Image(systemName: "dog.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
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
                    .font(.system(size: size * 0.35, weight: .bold))
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color(.systemGray5)))
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            }
        }
    }
}

/// The pop-down alert at the top of the screen.
struct BannerView: View {
    let banner: AppState.Banner

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: banner.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.subheadline.bold())
                Text(banner.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

/// Map marker showing how many pups are at a park.
struct ParkPin: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "pawprint.fill")
            if count > 0 {
                Text("\(count)").bold()
            }
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(count > 0 ? Color.accentColor : Color.gray))
        .overlay(Capsule().stroke(.white, lineWidth: 2))
    }
}

/// "Luna", "Waffles and Pickles", "Luna, Waffles, Mochi +2"
func dogNames(_ dogs: [Dog], limit: Int = 3) -> String {
    let names = dogs.map(\.name)
    guard names.count > limit else {
        return ListFormatter.localizedString(byJoining: names)
    }
    return names.prefix(limit).joined(separator: ", ") + " +\(names.count - limit)"
}

/// "just now", "12 min ago", "3 hr ago", "2 d ago"
func timeAgo(_ date: Date) -> String {
    let minutes = Int(Date.now.timeIntervalSince(date) / 60)
    if minutes < 1 { return "just now" }
    if minutes < 60 { return "\(minutes) min ago" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours) hr ago" }
    return "\(hours / 24) d ago"
}
