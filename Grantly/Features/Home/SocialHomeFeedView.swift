import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct SocialHomeFeedView: View {
    @Environment(AuthStore.self) private var auth

    let currentAvatarURL: String?
    let currentName: String?
    let onChanged: () async -> Void

    @State private var stories: [SocialPost] = []
    @State private var posts: [SocialPost] = []
    @State private var loading = true
    @State private var showingComposer = false
    @State private var selectedStory: SocialPost?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            storiesRail

            HStack {
                Text("Community")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Button {
                    showingComposer = true
                } label: {
                    Label("Create", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(Theme.surfaceRaised)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if loading && posts.isEmpty {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if posts.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.accentSoft)

                    Text("No community posts yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)

                    Text("Share a photo, video or short with other students.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)

                    Button("Create post") {
                        showingComposer = true
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(posts) { post in
                        SocialPostCard(
                            post: post,
                            canDelete: post.authorId == auth.userId,
                            onDelete: {
                                Task {
                                    await delete(post)
                                }
                            }
                        )
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingComposer, onDismiss: {
            Task { await load() }
        }) {
            SocialPostComposer()
        }
        .sheet(item: $selectedStory) { story in
            SocialStoryViewer(story: story)
        }
    }

    private var storiesRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Button {
                    showingComposer = true
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottomTrailing) {
                            CommunityAvatar(
                                name: currentName ?? "You",
                                imageURL: currentAvatarURL,
                                size: 62
                            )

                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                                .frame(width: 22, height: 22)
                                .background(Theme.accent)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Theme.surface, lineWidth: 2)
                                )
                        }

                        Text("Your story")
                            .font(.caption2)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .frame(width: 68)
                    }
                }
                .buttonStyle(.plain)

                ForEach(stories) { story in
                    Button {
                        selectedStory = story
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Theme.orangeSoft,
                                                Theme.accentSoft
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 66, height: 66)

                                CommunityAvatar(
                                    name: story.author?.displayName ?? "Student",
                                    imageURL: story.author?.avatarUrl,
                                    size: 58
                                )
                            }

                            Text(story.author?.displayName ?? "Student")
                                .font(.caption2)
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .frame(width: 68)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        async let storyRows = DataService.socialStories(limit: 24)
        async let feedRows = DataService.socialFeed(limit: 30)

        stories = (try? await storyRows) ?? []
        posts = (try? await feedRows) ?? []
    }

    @MainActor
    private func delete(_ post: SocialPost) async {
        do {
            try await DataService.deleteSocialPost(post)
            withAnimation(.easeInOut(duration: 0.18)) {
                posts.removeAll { $0.id == post.id }
            }
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SocialPostCard: View {
    let post: SocialPost
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                CommunityAvatar(
                    name: post.author?.displayName ?? "Student",
                    imageURL: post.author?.avatarUrl,
                    size: 38
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.displayName ?? "Student")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)

                    HStack(spacing: 5) {
                        if post.kind == .short {
                            Label("Short", systemImage: "play.rectangle.fill")
                        } else {
                            Text(relativeTime(post.createdAt))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                }

                Spacer()

                if canDelete {
                    Menu {
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.muted)
                            .frame(width: 34, height: 34)
                    }
                }
            }
            .padding(12)

            if let mediaURL = post.mediaUrl,
               let url = URL(string: mediaURL) {
                if post.mediaType == "video" {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: post.kind == .short ? 360 : 260)
                        .background(Color.black)
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            mediaPlaceholder
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 220)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
                }
            }

            let caption = post.caption.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var mediaPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 28))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(Theme.surfaceRaised)
    }

    private func relativeTime(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            return String(value.prefix(10))
        }

        return RelativeDateTimeFormatter()
            .localizedString(for: date, relativeTo: Date())
    }
}

private struct SocialStoryViewer: View {
    @Environment(\.dismiss) private var dismiss

    let story: SocialPost

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    CommunityAvatar(
                        name: story.author?.displayName ?? "Student",
                        imageURL: story.author?.avatarUrl,
                        size: 36
                    )

                    Text(story.author?.displayName ?? "Student")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding()

                Spacer()

                if let mediaURL = story.mediaUrl,
                   let url = URL(string: mediaURL) {
                    if story.mediaType == "video" {
                        VideoPlayer(player: AVPlayer(url: url))
                            .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    } else {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            default:
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }
                }

                if !story.caption.isEmpty {
                    Text(story.caption)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }

                Spacer()
            }
        }
    }
}

private struct SocialPostComposer: View {
    @Environment(\.dismiss) private var dismiss

    @State private var kind: SocialPostKind = .post
    @State private var caption = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var mediaData: Data?
    @State private var mediaType: String?
    @State private var fileExtension: String?
    @State private var previewImage: UIImage?
    @State private var loadingMedia = false
    @State private var publishing = false
    @State private var errorMessage: String?

    private var requiresMedia: Bool {
        kind == .story || kind == .short
    }

    private var canPublish: Bool {
        !publishing &&
        (!caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
         mediaData != nil) &&
        (!requiresMedia || mediaData != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Type", selection: $kind) {
                        Text("Post").tag(SocialPostKind.post)
                        Text("Story").tag(SocialPostKind.story)
                        Text("Short").tag(SocialPostKind.short)
                    }
                    .pickerStyle(.segmented)

                    TextField(
                        kind == .story
                            ? "Add a story caption..."
                            : "Share something with students...",
                        text: $caption,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .padding(12)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        HStack(spacing: 10) {
                            Image(
                                systemName: mediaData == nil
                                    ? "photo.on.rectangle.angled"
                                    : "arrow.triangle.2.circlepath"
                            )

                            Text(
                                mediaData == nil
                                    ? "Add photo or video"
                                    : "Change media"
                            )

                            Spacer()

                            if loadingMedia {
                                ProgressView()
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(14)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 340)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else if mediaData != nil,
                              mediaType?.hasPrefix("video/") == true {
                        Label(
                            "Video ready to publish",
                            systemImage: "video.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentSoft)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if kind == .story {
                        Text("Stories disappear after 24 hours.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    } else if kind == .short {
                        Text("Shorts are vertical video posts. Choose a video for the best result.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(publishing ? "Publishing..." : "Publish") {
                        Task { await publish() }
                    }
                    .disabled(!canPublish)
                }
            }
            .onChange(of: selectedItem) {
                Task { await loadMedia() }
            }
            .onChange(of: kind) {
                if kind == .short,
                   mediaType?.hasPrefix("video/") == false {
                    selectedItem = nil
                    mediaData = nil
                    mediaType = nil
                    fileExtension = nil
                    previewImage = nil
                }
            }
        }
    }

    @MainActor
    private func loadMedia() async {
        guard let selectedItem else { return }

        loadingMedia = true
        defer { loadingMedia = false }

        do {
            guard let data = try await selectedItem.loadTransferable(
                type: Data.self
            ) else {
                errorMessage = L10n.string("Could not read that photo.")
                return
            }

            guard data.count <= 50 * 1024 * 1024 else {
                errorMessage = "Please choose media smaller than 50 MB."
                return
            }

            let types = selectedItem.supportedContentTypes
            let type =
                types.first(where: { $0.conforms(to: .movie) }) ??
                types.first(where: { $0.conforms(to: .image) })

            let isVideo = type?.conforms(to: .movie) == true

            if kind == .short && !isVideo {
                errorMessage = "Shorts require a video."
                return
            }

            mediaData = data
            mediaType =
                type?.preferredMIMEType ??
                (isVideo ? "video/mp4" : "image/jpeg")
            fileExtension =
                type?.preferredFilenameExtension ??
                (isVideo ? "mp4" : "jpg")
            previewImage = isVideo ? nil : UIImage(data: data)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func publish() async {
        guard canPublish else { return }

        publishing = true
        defer { publishing = false }

        do {
            try await DataService.createSocialPost(
                kind: kind,
                caption: caption.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                mediaData: mediaData,
                mediaType: mediaType,
                fileExtension: fileExtension
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
