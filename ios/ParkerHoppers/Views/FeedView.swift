import SwiftUI
import PhotosUI

struct FeedView: View {
    @Environment(AppState.self) private var state
    @State private var showingComposer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(state.posts) { post in
                        PostCard(post: post)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Park Moments")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingComposer = true
                    } label: {
                        Label("New post", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                NewPostSheet()
            }
        }
    }
}

private struct PostCard: View {
    @Environment(AppState.self) private var state
    let post: Post

    private var isMine: Bool { post.author.id == state.me.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                DogAvatar(dog: post.dog, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(isMine ? "\(post.dog.name) · you" : "\(post.dog.name) · with \(post.author.name)")
                        .font(.subheadline.bold())
                    Text("\(post.parkName) · \(timeAgo(post.postedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Menu {
                    if isMine {
                        Button("Delete post", systemImage: "trash", role: .destructive) {
                            withAnimation { state.delete(post) }
                        }
                    } else {
                        Button("Report post", systemImage: "flag") {
                            withAnimation { state.report(post) }
                        }
                        Button("Hide \(post.author.name)'s posts", systemImage: "eye.slash") {
                            withAnimation { state.hidePosts(from: post.author) }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(.secondary)
            }

            PhotoView(post: post)

            Button {
                state.toggleLike(post)
            } label: {
                Label("\(post.likes)", systemImage: post.likedByMe ? "heart.fill" : "heart")
                    .font(.subheadline.bold())
                    .foregroundStyle(post.likedByMe ? Color.pink : Color.primary)
            }
            .buttonStyle(.plain)

            Text(post.caption)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct PhotoView: View {
    let post: Post

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                if let image = post.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(colors: post.palette, startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: post.symbol)
                            .font(.system(size: 72))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 6)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct NewPostSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var dogID: Dog.ID?
    @State private var parkName = ""
    @State private var caption = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Label("Choose a photo", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity, minHeight: 120)
                        }
                    }
                }

                Section("Details") {
                    Picker("Pup", selection: $dogID) {
                        ForEach(state.me.dogs) { dog in
                            Text(dog.name).tag(Optional(dog.id))
                        }
                    }
                    Picker("Park", selection: $parkName) {
                        ForEach(state.parks) { park in
                            Text(park.name).tag(park.name)
                        }
                    }
                    TextField("What happened?", text: $caption, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        guard let dog = state.me.dogs.first(where: { $0.id == dogID }) else { return }
                        state.addPost(dog: dog, parkName: parkName, caption: caption, image: image)
                        dismiss()
                    }
                    .disabled(caption.isEmpty && image == nil)
                }
            }
            .onAppear {
                if dogID == nil { dogID = state.me.dogs.first?.id }
                if parkName.isEmpty {
                    let current = state.myCheckIn.flatMap { state.park(id: $0.parkID) }
                    parkName = current?.name ?? state.parks.first?.name ?? ""
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let picked = UIImage(data: data) {
                        image = picked
                    }
                }
            }
        }
    }
}
