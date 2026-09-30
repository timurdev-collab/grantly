import AVKit
import SwiftUI

struct MyContentView: View {
    @State private var posts: [SocialPost] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var editingPost: SocialPost?
    @State private var deletePost: SocialPost?
    @State private var filter: SocialContentFilter = .all

    private var filteredPosts: [SocialPost] {
        switch filter {
        case .all:
            return posts
        case .posts:
            return posts.filter { $0.kind == .post }
        case .stories:
            return posts.filter { $0.kind == .story }
        case .shorts:
            return posts.filter { $0.kind == .short }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Picker("Content", selection: $filter) {
                    ForEach(SocialContentFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if loading && posts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                } else if filteredPosts.isEmpty {
                    ContentUnavailableView(
                        "No content yet",
                        systemImage: "rectangle.stack",
                        description: Text(
                            "Posts, stories and shorts you publish will appear here."
                        )
                    )
                    .padding(.vertical, 36)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPosts) { post in
                            MyContentCard(
                                post: post,
                                onEdit: {
                                    editingPost = post
                                },
                                onDelete: {
                                    deletePost = post
                                }
                            )
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationTitle("My content")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editingPost) { post in
            EditSocialPostSheet(
                post: post,
                onSaved: {
                    await load()
                }
            )
        }
        .alert(
            "Delete this content?",
            isPresented: Binding(
                get: { deletePost != nil },
                set: { if !$0 { deletePost = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let post = deletePost else { return }
                Task { await remove(post) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            posts = try await DataService.mySocialPosts()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func remove(_ post: SocialPost) async {
        do {
            try await DataService.deleteSocialPost(post)
            withAnimation(.easeInOut(duration: 0.18)) {
                posts.removeAll { $0.id == post.id }
            }
            deletePost = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum SocialContentFilter: String, CaseIterable, Identifiable {
    case all
    case posts
    case stories
    case shorts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.string("All")
        case .posts:
            return L10n.string("Posts")
        case .stories:
            return L10n.string("Stories")
        case .shorts:
            return L10n.string("Shorts")
        }
    }
}

private struct MyContentCard: View {
    let post: SocialPost
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(kindTitle, systemImage: kindIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Spacer()

                Text(String(post.createdAt.prefix(10)))
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit caption", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.muted)
                        .frame(width: 34, height: 34)
                }
            }

            if let mediaURL = post.mediaUrl,
               let url = URL(string: mediaURL) {
                if post.mediaType == "video" {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            ZStack {
                                Theme.surfaceRaised
                                ProgressView()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if !post.caption.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.surfaceRaised)
                        .foregroundStyle(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.danger.opacity(0.08))
                        .foregroundStyle(Theme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var kindTitle: String {
        switch post.kind {
        case .post:
            return L10n.string("Post")
        case .story:
            return L10n.string("Story")
        case .short:
            return L10n.string("Short")
        }
    }

    private var kindIcon: String {
        switch post.kind {
        case .post:
            return "square.grid.2x2"
        case .story:
            return "circle.dashed"
        case .short:
            return "play.rectangle.fill"
        }
    }
}

private struct EditSocialPostSheet: View {
    @Environment(\.dismiss) private var dismiss

    let post: SocialPost
    let onSaved: () async -> Void

    @State private var caption: String
    @State private var saving = false
    @State private var errorMessage: String?

    init(
        post: SocialPost,
        onSaved: @escaping () async -> Void
    ) {
        self.post = post
        self.onSaved = onSaved
        _caption = State(initialValue: post.caption)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Caption") {
                    TextField(
                        "Write a caption...",
                        text: $caption,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .navigationTitle("Edit content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        saving
                            ? L10n.string("Saving...")
                            : L10n.string("Save")
                    ) {
                        Task { await save() }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        saving = true
        defer { saving = false }

        do {
            try await DataService.updateSocialPostCaption(
                postId: post.id,
                caption: caption.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
