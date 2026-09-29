import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var state
    @State private var invite: InviteSheet.Start?
    @State private var removing: Person?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { invite = .share } label: { Label("Invite a friend", systemImage: "person.badge.plus") }
                    Button { invite = .enterCode } label: { Label("Enter a friend’s code", systemImage: "plus") }
                } footer: {
                    Text("Only friends see your name, your dogs and where you check in.")
                }

                Section("At the park now") {
                    if state.friendCheckIns.isEmpty {
                        Text("No friends at the park right now.").foregroundStyle(.secondary)
                    }
                    ForEach(state.friendCheckIns) { visit in
                        let dogs = state.dogs(of: visit)
                        HStack(spacing: 12) {
                            DogStack(dogs: dogs, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(state.person(visit.personID)?.name ?? "") & \(dogNames(dogs))").font(.headline)
                                Text("\(Park.find(visit.parkID)?.name ?? "") · \(timeAgo(visit.arrivedAt))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Your pack") {
                    if state.friends.isEmpty {
                        Text("No friends yet. Invite someone you know from the park!").foregroundStyle(.secondary)
                    }
                    ForEach(state.friends) { friend in
                        FriendRow(friend: friend) { removing = friend }
                            .swipeActions {
                                if !friend.isDemo {
                                    Button { removing = friend } label: { Label("Remove", systemImage: "person.badge.minus") }
                                        .tint(.red)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Friends")
            .refreshable { await state.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { invite = .share } label: { Image(systemName: "person.badge.plus") }
                        .accessibilityLabel("Invite a friend")
                }
            }
            .sheet(item: $invite) { InviteSheet(start: $0) }
            .confirmationDialog("Remove \(removing?.name ?? "") as a friend?",
                                isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible, presenting: removing) { friend in
                Button("Remove \(friend.name)", role: .destructive) {
                    Task { await state.attempt { try await state.removeFriend(friend) } }
                }
            } message: { _ in
                Text("You’ll stop seeing each other’s check-ins, dogs and posts.")
            }
        }
    }
}

private struct FriendRow: View {
    @Environment(AppState.self) private var state
    let friend: Person
    let remove: () -> Void

    var body: some View {
        let dogs = friend.dogIDs.compactMap(state.dog)
        HStack(spacing: 12) {
            DogStack(dogs: dogs, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.name).font(.headline)
                    if friend.isDemo {
                        Text("DEMO")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                Text(dogs.map { dog in
                    let about = dog.details.isEmpty ? dog.breedText : dog.details
                    return about.isEmpty ? dog.name : "\(dog.name): \(about)"
                }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if state.checkIn(for: friend.id) != nil {
                Text("At park")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            if !friend.isDemo {
                Menu {
                    Button(role: .destructive, action: remove) {
                        Label("Remove \(friend.name) as a friend", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(friend.name)")
            }
        }
        .padding(.vertical, 2)
    }
}

/// Make a one-time invite to share, or type in a code a friend sent you.
struct InviteSheet: View {
    enum Start: String, Identifiable {
        case share, enterCode
        var id: String { rawValue }
    }

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let start: Start
    @State private var invite: (code: String, link: URL)?
    @State private var making = false
    @State private var copied = false
    @State private var code = ""
    @State private var adding = false
    @State private var problem: String?
    @FocusState private var typingCode: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let invite {
                        VStack(spacing: 6) {
                            Text("Invite code").font(.subheadline).foregroundStyle(.secondary)
                            Text(Self.pretty(invite.code))
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(Color.accentColor)
                                .textSelection(.enabled)
                            Text("Works once, for 7 days. Only share it with people you know.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        ShareLink(item: invite.link, message: Text("Join my pack on Park Hoppers so our dogs can meet up at the park! 🐾 Tap the link, or enter code \(Self.pretty(invite.code)) on the Friends tab.")) {
                            Label("Share invite", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            UIPasteboard.general.url = invite.link
                            copied = true
                        } label: {
                            Label(copied ? "Link copied" : "Copy link", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                    } else {
                        Button {
                            Task { await make() }
                        } label: {
                            Label(making ? "Making…" : "Make an invite", systemImage: "person.badge.plus")
                        }
                        .disabled(making)
                    }
                } footer: {
                    Text("Only friends see your name, your dogs and where you check in.")
                }

                Section {
                    HStack {
                        TextField("e.g. K7P2-9QXM", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($typingCode)
                            .submitLabel(.done)
                            .onSubmit { Task { await add() } }
                        Button(adding ? "Adding…" : "Add") { Task { await add() } }
                            .disabled(adding || code.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Got a code from a friend?")
                } footer: {
                    if let problem { Text(problem).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Invite a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear { if start == .enterCode { typingCode = true } }
        }
        .presentationDetents([.medium, .large])
    }

    /// "K7P29QXM" → "K7P2-9QXM", easier to read out loud.
    static func pretty(_ code: String) -> String {
        "\(code.prefix(4))-\(code.dropFirst(4))"
    }

    private func make() async {
        making = true
        defer { making = false }
        do {
            invite = try await state.createInvite()
            problem = nil
        } catch {
            problem = state.friendly(error)
        }
    }

    private func add() async {
        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        adding = true
        defer { adding = false }
        do {
            try await state.acceptInvite(code)
            dismiss()
        } catch {
            problem = state.friendly(error)
        }
    }
}
