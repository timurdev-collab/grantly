import SwiftUI

struct SocialCommentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var auth

    let post: SocialPost
    let onChanged: () async -> Void

    @State private var comments: [SocialComment] = []
    @State private var draft = ""
    @State private var loading = true
    @State private var sending = false
    @State private var errorMessage: String?

    private var canSend: Bool {
        !sending &&
        !draft.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if loading && comments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    ContentUnavailableView(
                        "No comments yet",
                        systemImage: "bubble.left",
                        description: Text(
                            "Be the first to start the conversation."
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(comments) { comment in
                                    commentRow(comment)
                                        .id(comment.id)
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: comments.count) {
                            guard let last = comments.last else { return }
                            withAnimation {
                                proxy.scrollTo(
                                    last.id,
                                    anchor: .bottom
                                )
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }

                Divider()
                    .overlay(Theme.ink.opacity(0.06))

                composer
            }
            .background(Theme.pageBackground)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task { await load() }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                "Add a comment...",
                text: $draft,
                axis: .vertical
            )
            .lineLimit(1...4)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                Task { await send() }
            } label: {
                if sending {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 31))
                        .foregroundStyle(
                            canSend ? Theme.accent : Theme.muted
                        )
                        .frame(width: 36, height: 36)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Post comment")
        }
        .padding(12)
        .background(Theme.surface)
    }

    private func commentRow(
        _ comment: SocialComment
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SocialCommentAvatar(
                name: comment.author?.displayName ?? "Student",
                imageURL: comment.author?.avatarUrl
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.author?.displayName ?? "Student")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)

                    Text(relativeTime(comment.createdAt))
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)

                    Spacer()

                    if comment.authorId == auth.userId {
                        Menu {
                            Button(
                                "Delete comment",
                                role: .destructive
                            ) {
                                Task {
                                    await remove(comment)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .frame(width: 30, height: 30)
                        }
                    }
                }

                Text(comment.body)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            comments = try await DataService.socialComments(
                postId: post.id
            )
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func send() async {
        let body = draft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !body.isEmpty else { return }

        sending = true
        defer { sending = false }

        do {
            try await DataService.addSocialComment(
                postId: post.id,
                body: body
            )
            draft = ""
            comments = try await DataService.socialComments(
                postId: post.id
            )
            await onChanged()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func remove(
        _ comment: SocialComment
    ) async {
        do {
            try await DataService.deleteSocialComment(
                commentId: comment.id
            )
            withAnimation(.easeInOut(duration: 0.18)) {
                comments.removeAll { $0.id == comment.id }
            }
            await onChanged()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func relativeTime(
        _ value: String
    ) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            return String(value.prefix(10))
        }

        return RelativeDateTimeFormatter()
            .localizedString(for: date, relativeTo: Date())
    }
}

private struct SocialCommentAvatar: View {
    let name: String
    let imageURL: String?

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
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.ink)
                    }
                }
            } else {
                Text(initials)
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }
}
