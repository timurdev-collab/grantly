import AVFoundation
import AVKit
import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

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
    @State private var selectedCommentsPost: SocialPost?
    @State private var reportingPost: SocialPost?
    @State private var engagement: [UUID: SocialPostEngagement] = [:]
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            storiesRail

            HStack {
                Text("Community")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                NavigationLink {
                    MyContentView()
                } label: {
                    Text("Manage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)

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
                            engagement:
                                engagement[post.id] ??
                                SocialPostEngagement(),
                            isOwnPost: post.authorId == auth.userId,
                            onToggleLike: {
                                Task {
                                    await toggleLike(post)
                                }
                            },
                            onComments: {
                                selectedCommentsPost = post
                            },
                            onDelete: {
                                Task {
                                    await delete(post)
                                }
                            },
                            onReport: {
                                reportingPost = post
                            },
                            onBlock: {
                                Task {
                                    await block(post)
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
        .sheet(item: $selectedCommentsPost) { post in
            SocialCommentsView(
                post: post,
                onChanged: {
                    await refreshEngagement()
                }
            )
        }
        .sheet(item: $reportingPost) { post in
            SocialPostReportSheet(post: post) {
                reportingPost = nil
            }
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
                            SocialAvatar(
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

                                SocialAvatar(
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

        do {
            let (loadedStories, loadedPosts) = try await (
                storyRows,
                feedRows
            )
            stories = loadedStories
            posts = loadedPosts
            engagement = try await DataService.socialEngagement(
                postIds: loadedPosts.map(\.id)
            )
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshEngagement() async {
        do {
            engagement = try await DataService.socialEngagement(
                postIds: posts.map(\.id)
            )
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleLike(_ post: SocialPost) async {
        let previous =
            engagement[post.id] ??
            SocialPostEngagement()

        var updated = previous
        updated.likedByMe.toggle()
        updated.likeCount = max(
            0,
            previous.likeCount +
            (updated.likedByMe ? 1 : -1)
        )
        engagement[post.id] = updated

        do {
            try await DataService.setSocialPostLiked(
                postId: post.id,
                liked: updated.likedByMe
            )
        } catch {
            engagement[post.id] = previous
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func block(_ post: SocialPost) async {
        guard post.authorId != auth.userId else { return }

        do {
            try await DataService.blockUser(post.authorId)
            await load()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
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
    let engagement: SocialPostEngagement
    let isOwnPost: Bool
    let onToggleLike: () -> Void
    let onComments: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                SocialAvatar(
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
                            Label(
                                "Short",
                                systemImage: "play.rectangle.fill"
                            )
                        } else {
                            Text(relativeTime(post.createdAt))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                }

                Spacer()

                Menu {
                    if isOwnPost {
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    } else {
                        Button {
                            onReport()
                        } label: {
                            Label(
                                "Report post",
                                systemImage: "exclamationmark.bubble"
                            )
                        }

                        Button(role: .destructive) {
                            onBlock()
                        } label: {
                            Label(
                                "Block student",
                                systemImage:
                                    "person.crop.circle.badge.xmark"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.muted)
                        .frame(width: 34, height: 34)
                }
            }
            .padding(12)

            if let mediaURL = post.mediaUrl,
               let url = URL(string: mediaURL) {
                if post.mediaType == "video" {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(
                            height:
                                post.kind == .short
                                ? 360
                                : 260
                        )
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
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: 220
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
                }
            }

            HStack(spacing: 18) {
                Button(action: onToggleLike) {
                    Label(
                        engagement.likeCount == 0
                            ? L10n.string("Like")
                            : "\(engagement.likeCount)",
                        systemImage:
                            engagement.likedByMe
                            ? "heart.fill"
                            : "heart"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        engagement.likedByMe
                            ? Theme.danger
                            : Theme.ink
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    engagement.likedByMe
                        ? L10n.string("Unlike post")
                        : L10n.string("Like post")
                )

                Button(action: onComments) {
                    Label(
                        engagement.commentCount == 0
                            ? L10n.string("Comment")
                            : "\(engagement.commentCount)",
                        systemImage: "bubble.left"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            let caption = post.caption.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(12)
            } else {
                Spacer()
                    .frame(height: 12)
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

private struct SocialPostReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let post: SocialPost
    let onFinished: () -> Void

    @State private var reason = "Spam or misleading"
    @State private var details = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    private let reasons = [
        "Spam or misleading",
        "Harassment or bullying",
        "Hate or abusive content",
        "Unsafe or inappropriate",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(reasons, id: \.self) {
                            Text(L10n.string($0))
                        }
                    }
                }

                Section("Details") {
                    TextField(
                        "Add details (optional)",
                        text: $details,
                        axis: .vertical
                    )
                    .lineLimit(3...7)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .navigationTitle("Report post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        submitting
                            ? L10n.string("Submitting...")
                            : L10n.string("Submit report")
                    ) {
                        Task { await submit() }
                    }
                    .disabled(submitting)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        submitting = true
        defer { submitting = false }

        do {
            try await DataService.reportSocialPost(
                post: post,
                reason: reason,
                details: details.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )
            onFinished()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
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
                    SocialAvatar(
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
    @State private var mediaFileURL: URL?
    @State private var mediaType: String?
    @State private var fileExtension: String?
    @State private var previewImage: UIImage?
    @State private var loadingMedia = false
    @State private var loadingStatus: String?
    @State private var publishing = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?

    private var requiresMedia: Bool {
        kind == .story || kind == .short
    }

    private var canPublish: Bool {
        !publishing &&
        (!caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
         mediaData != nil ||
         mediaFileURL != nil) &&
        (!requiresMedia || mediaData != nil || mediaFileURL != nil)
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
                            ? L10n.string("Add a story caption...")
                            : L10n.string("Share something with students..."),
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
                                systemName:
                                    mediaData == nil && mediaFileURL == nil
                                    ? "photo.on.rectangle.angled"
                                    : "arrow.triangle.2.circlepath"
                            )

                            Text(
                                mediaData == nil && mediaFileURL == nil
                                    ? L10n.string("Add photo or video")
                                    : L10n.string("Change media")
                            )

                            Spacer()

                            if loadingMedia {
                                HStack(spacing: 6) {
                                    ProgressView()
                                    if let loadingStatus {
                                        Text(loadingStatus)
                                            .font(.caption2)
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
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
                    } else if let mediaFileURL,
                              mediaType?.hasPrefix("video/") == true {
                        VStack(alignment: .leading, spacing: 10) {
                            VideoPlayer(
                                player: AVPlayer(url: mediaFileURL)
                            )
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            Label(
                                "Video ready to publish",
                                systemImage: "video.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accentSoft)
                        }
                    }

                    if publishing && mediaFileURL != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Uploading video")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.ink)

                                Spacer()

                                Text("\(Int(uploadProgress * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Theme.muted)
                            }

                            ProgressView(value: uploadProgress)
                                .tint(Theme.accent)
                        }
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
                    Button(
                        publishing
                            ? L10n.string("Publishing...")
                            : L10n.string("Publish")
                    ) {
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
                    cleanupVideoFile()
                    mediaFileURL = nil
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
        errorMessage = nil
        uploadProgress = 0
        defer {
            loadingMedia = false
            loadingStatus = nil
        }

        cleanupVideoFile()
        mediaFileURL = nil
        mediaData = nil
        previewImage = nil

        do {
            let types = selectedItem.supportedContentTypes
            let type =
                types.first(where: { $0.conforms(to: .movie) }) ??
                types.first(where: { $0.conforms(to: .image) })

            let isVideo = type?.conforms(to: .movie) == true

            if kind == .short && !isVideo {
                errorMessage = L10n.string("Shorts require a video.")
                return
            }

            if isVideo {
                loadingStatus = L10n.string("Preparing video...")

                guard let picked = try await selectedItem.loadTransferable(
                    type: SocialPickedVideo.self
                ) else {
                    errorMessage = L10n.string("Could not read that video.")
                    return
                }

                defer {
                    try? FileManager.default.removeItem(at: picked.url)
                }

                let compressed = try await SocialVideoCompressor.compress(
                    inputURL: picked.url
                )

                let values = try compressed.resourceValues(
                    forKeys: [.fileSizeKey]
                )
                let size = values.fileSize ?? 0

                guard size <= 200 * 1024 * 1024 else {
                    try? FileManager.default.removeItem(at: compressed)
                    errorMessage = L10n.string(
                        "Please choose a video smaller than 200 MB."
                    )
                    return
                }

                mediaFileURL = compressed
                mediaType = "video/mp4"
                fileExtension = "mp4"
                errorMessage = nil
                return
            }

            guard let data = try await selectedItem.loadTransferable(
                type: Data.self
            ) else {
                errorMessage = L10n.string("Could not read that photo.")
                return
            }

            guard data.count <= 6 * 1024 * 1024 else {
                errorMessage = L10n.string(
                    "Please choose media smaller than 6 MB."
                )
                return
            }

            mediaData = data
            mediaType =
                type?.preferredMIMEType ?? "image/jpeg"
            fileExtension =
                type?.preferredFilenameExtension ?? "jpg"
            previewImage = UIImage(data: data)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func publish() async {
        guard canPublish else { return }

        publishing = true
        uploadProgress = 0
        defer { publishing = false }

        do {
            try await DataService.createSocialPost(
                kind: kind,
                caption: caption.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                mediaData: mediaData,
                mediaFileURL: mediaFileURL,
                mediaType: mediaType,
                fileExtension: fileExtension,
                uploadProgress: { value in
                    Task { @MainActor in
                        uploadProgress = value
                    }
                }
            )

            cleanupVideoFile()
            mediaFileURL = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cleanupVideoFile() {
        guard let mediaFileURL else { return }
        try? FileManager.default.removeItem(at: mediaFileURL)
    }

}


private struct SocialPickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty
                ? "mov"
                : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(
                at: received.file,
                to: copy
            )

            return SocialPickedVideo(url: copy)
        }
    }
}

private enum SocialVideoCompressor {
    static func compress(inputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)

        guard let exporter =
            AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPreset1280x720
            ) ??
            AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetMediumQuality
            )
        else {
            throw SocialVideoCompressionError.unavailable
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        try? FileManager.default.removeItem(at: outputURL)

        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        return try await withCheckedThrowingContinuation {
            continuation in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .cancelled:
                    continuation.resume(
                        throwing: CancellationError()
                    )
                default:
                    continuation.resume(
                        throwing:
                            exporter.error ??
                            SocialVideoCompressionError.failed
                    )
                }
            }
        }
    }
}

private enum SocialVideoCompressionError: LocalizedError {
    case unavailable
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "This video cannot be prepared for upload."
        case .failed:
            return "Video preparation failed. Please try another video."
        }
    }
}


private struct SocialAvatar: View {
    let name: String
    var imageURL: String?
    var size: CGFloat

    private var initials: String {
        let words = name.split(separator: " ")

        if words.count >= 2 {
            return (
                String(words[0].prefix(1)) +
                String(words[1].prefix(1))
            ).uppercased()
        }

        return name.isEmpty
            ? "G"
            : String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.surfaceRaised)

            if let imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Text(initials)
                            .font(
                                .system(
                                    size: size * 0.28,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(Theme.ink)
                    }
                }
            } else {
                Text(initials)
                    .font(
                        .system(
                            size: size * 0.28,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
