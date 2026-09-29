import SwiftUI
import PhotosUI

struct MomentsView: View {
    @Environment(AppState.self) private var state
    @State private var composing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    if state.posts.isEmpty {
                        Text("No moments yet. Share the first one!")
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                    }
                    ForEach(state.posts) { post in
                        PostCard(post: post)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Park Moments")
            .refreshable { await state.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { composing = true } label: { Label("Share a moment", systemImage: "camera") }
                }
            }
            .sheet(isPresented: $composing) { NewPostSheet() }
        }
    }
}

private struct PostCard: View {
    @Environment(AppState.self) private var state
    let post: Post

    var body: some View {
        let author = state.person(post.authorID)
        let dog = post.dogID.flatMap(state.dog)
        let isMine = post.authorID == state.myID
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let dog { DogAvatar(dog: dog, size: 38) }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(dog?.name ?? author?.name ?? "") · \(isMine ? "you" : "with \(author?.name ?? "someone")")")
                        .font(.subheadline.bold())
                    Text("\(Park.find(post.parkID)?.name ?? "") · \(timeAgo(post.postedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Menu {
                    if isMine {
                        Button("Delete post", systemImage: "trash", role: .destructive) {
                            Task { await state.attempt { try await state.deletePost(post) } }
                        }
                    } else {
                        Button("Report post", systemImage: "flag") {
                            Task { await state.attempt { try await state.report(post) } }
                        }
                        if let author {
                            Button("Hide \(author.name)’s posts", systemImage: "eye.slash") { state.hidePosts(from: author) }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis").padding(8).contentShape(Rectangle())
                }
                .foregroundStyle(.secondary)
            }

            Color.clear
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay {
                    if let url = post.photoURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        LinearGradient(colors: [dog?.color ?? .orange, .accentColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .overlay(Image(systemName: "camera.fill").font(.system(size: 60)).foregroundStyle(.white.opacity(0.9)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                Task { await state.attempt { try await state.toggleLike(post) } }
            } label: {
                Label("\(post.likes)", systemImage: post.likedByMe ? "heart.fill" : "heart")
                    .font(.subheadline.bold())
                    .foregroundStyle(post.likedByMe ? Color.pink : Color.primary)
            }
            .buttonStyle(.plain)

            if !post.caption.isEmpty { Text(post.caption) }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct NewPostSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var dogID = ""
    @State private var parkID = ""
    @State private var caption = ""
    @State private var saving = false

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
                            Label("Add a photo", systemImage: "photo.badge.plus").frame(maxWidth: .infinity, minHeight: 120)
                        }
                    }
                }
                Section {
                    Picker("Pup", selection: $dogID) {
                        ForEach(state.myDogs) { Text($0.name).tag($0.id) }
                    }
                    Picker("Park", selection: $parkID) {
                        ForEach(Park.all) { Text($0.name).tag($0.id) }
                    }
                    TextField("What happened at the park?", text: $caption, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Sharing…" : "Share") {
                        Task {
                            saving = true
                            let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                            if await state.attempt({ try await state.addPost(dogID: dogID, parkID: parkID, caption: text, photo: image) }) {
                                dismiss()
                            }
                            saving = false
                        }
                    }
                    .disabled(saving || dogID.isEmpty || (image == nil && caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
            .onAppear {
                if dogID.isEmpty { dogID = state.myDogs.first?.id ?? "" }
                if parkID.isEmpty { parkID = state.myCheckIn?.parkID ?? Park.all[0].id }
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) { image = UIImage(data: data) }
                }
            }
        }
    }
}
