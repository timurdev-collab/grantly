import SwiftUI

struct ConversationSummary: Identifiable {
    let id: UUID
    let otherUserId: UUID?
    let displayName: String
}

struct MessagesView: View {
    @Environment(AuthStore.self) private var auth

    @State private var conversations: [ConversationSummary] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if conversations.isEmpty {
                EmptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "No messages yet",
                    text: "Start a conversation from the Community tab."
                )
            } else {
                List(conversations) { conversation in
                    NavigationLink {
                        ChatView(
                            conversationId: conversation.id,
                            otherUserId: conversation.otherUserId,
                            title: conversation.displayName
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Text(conversation.displayName.prefix(2).uppercased())
                                .font(.caption.bold())
                                .frame(width: 42, height: 42)
                                .background(Theme.violet.opacity(0.1))
                                .foregroundStyle(Theme.violet)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(conversation.displayName)
                                    .font(.headline)

                                Text("Tap to open conversation")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Messages")
        .refreshable { await load() }
        .task { await load() }
        .alert("Unable to load messages", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        guard let userId = auth.userId else { return }

        do {
            let memberships = try await DataService.conversationMemberships(
                userId: userId
            )

            var summaries: [ConversationSummary] = []

            for membership in memberships {
                let members = try await DataService.conversationMembers(
                    conversationId: membership.conversationId
                )

                let otherUserId = members
                    .map(\.userId)
                    .first { $0 != userId }

                var name = "Student"

                if let otherUserId,
                   let profile = try? await DataService.currentCommunityProfile(
                    userId: otherUserId
                   ) {
                    let candidate = profile.displayName?
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if let candidate, !candidate.isEmpty {
                        name = candidate
                    }
                }

                summaries.append(
                    ConversationSummary(
                        id: membership.conversationId,
                        otherUserId: otherUserId,
                        displayName: name
                    )
                )
            }

            conversations = summaries
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ChatView: View {
    @Environment(AuthStore.self) private var auth

    let conversationId: UUID
    let otherUserId: UUID?
    let title: String

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var reportingMessage: Message?
    @State private var errorMessage: String?
    @State private var blockedByMe = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            Bubble(
                                message: message,
                                mine: message.senderId == auth.userId
                            )
                            .id(message.id)
                            .contextMenu {
                                if message.senderId != auth.userId {
                                    Button(role: .destructive) {
                                        Task {
                                            await blockSender(message.senderId)
                                        }
                                    } label: {
                                        Label(
                                            "Block sender",
                                            systemImage: "person.crop.circle.badge.xmark"
                                        )
                                    }

                                    Button(role: .destructive) {
                                        reportingMessage = message
                                    } label: {
                                        Label(
                                            "Report message",
                                            systemImage: "exclamationmark.bubble"
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .refreshable { await load() }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(
                    blockedByMe ? "Unblock this student to send messages" : "Write a message…",
                    text: $draft,
                    axis: .vertical
                )
                    .lineLimit(1...4)
                    .padding(11)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.bold())
                        .frame(width: 42, height: 42)
                        .background(Theme.violet)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .disabled(
                    draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    sending ||
                    blockedByMe
                )
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockState()
            await load()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await load(silently: true)
            }
        }
        .sheet(item: $reportingMessage) { message in
            ReportSheet(subject: "message") { reason, details in
                try await DataService.submitSafetyReport(
                    reportedUserId: message.senderId,
                    messageId: message.id,
                    reason: reason,
                    details: details
                )
            }
        }
        .alert("Messaging error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func load(silently: Bool = false) async {
        do {
            messages = try await DataService.messages(
                conversationId: conversationId
            )
        } catch {
            if !silently {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func loadBlockState() async {
        guard let otherUserId else { return }
        let blocked = (try? await DataService.blockedUserIDs()) ?? []
        blockedByMe = blocked.contains(otherUserId)
    }

    @MainActor
    private func send() async {
        guard let userId = auth.userId else { return }

        let body = draft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !body.isEmpty else { return }

        sending = true
        defer { sending = false }

        do {
            try await DataService.sendMessage(
                conversationId: conversationId,
                senderId: userId,
                body: body
            )
            draft = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func blockSender(_ userId: UUID) async {
        do {
            try await DataService.blockUser(userId)
            blockedByMe = true
            draft = ""
            errorMessage = "This student is now blocked. New messages between your accounts are disabled."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct Bubble: View {
    let message: Message
    let mine: Bool

    var body: some View {
        HStack {
            if mine {
                Spacer(minLength: 45)
            }

            Text(message.body)
                .font(.body)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    mine
                        ? Theme.violet
                        : Color(.secondarySystemBackground)
                )
                .foregroundStyle(mine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !mine {
                Spacer(minLength: 45)
            }
        }
    }
}
