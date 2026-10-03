import SwiftUI
import Supabase

struct MessagesView: View {
    @State private var conversations: [ConversationSummaryRow] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                HStack {
                    Text("Messages")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.ink)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                if loading && conversations.isEmpty {
                    ProgressView()
                        .tint(Theme.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 56)
                } else if conversations.isEmpty {
                    EmptyState(
                        icon: "bubble.left.and.bubble.right",
                        title: "No messages yet",
                        text: "Start a conversation with an advisor."
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 36)
                } else {
                    ForEach(conversations) { conversation in
                        NavigationLink {
                            ChatView(
                                conversationId: conversation.conversationId,
                                otherUserId: conversation.otherUserId,
                                title: conversation.displayName
                            )
                        } label: {
                            ConversationRow(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task {
            await load()
            await listenRealtime()
        }
        .alert(
            "Unable to load messages",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func load(silently: Bool = false) async {
        if !silently {
            loading = true
        }

        defer {
            if !silently {
                loading = false
            }
        }

        do {
            conversations = try await DataService
                .conversationSummaries()
            errorMessage = nil
        } catch {
            if !silently {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func listenRealtime() async {
        let channel = await supabase.channel(
            "messages-list-\(UUID().uuidString)"
        )

        let changes = await channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "messages"
        )

        await channel.subscribe()

        defer {
            Task {
                await supabase.removeChannel(channel)
            }
        }

        for await _ in changes {
            guard !Task.isCancelled else { break }
            await load(silently: true)
        }
    }
}

private struct ConversationRow: View {
    let conversation: ConversationSummaryRow

    var body: some View {
        HStack(spacing: 12) {
            Text(conversation.displayName.prefix(2).uppercased())
                .font(.caption.bold())
                .frame(width: 50, height: 50)
                .background(Theme.blue.opacity(0.14))
                .foregroundStyle(Theme.blueSoft)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if let date = conversation.lastMessageAt {
                        Text(relativeTime(date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 7) {
                    Text(
                        conversation.lastMessage ??
                        "Start the conversation"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        conversation.unreadCount > 0
                            ? .primary
                            : .secondary
                    )
                    .fontWeight(
                        conversation.unreadCount > 0
                            ? .semibold
                            : .regular
                    )
                    .lineLimit(1)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text(
                            conversation.unreadCount > 99
                                ? "99+"
                                : "\(conversation.unreadCount)"
                        )
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 7)
                        .frame(minHeight: 20)
                        .background(Theme.blue)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func relativeTime(_ value: String) -> String {
        guard let date = AppDateParser.date(from: value) else {
            return String(value.prefix(10))
        }

        return RelativeDateTimeFormatter()
            .localizedString(
                for: date,
                relativeTo: Date()
            )
    }
}

struct ChatView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    private let pageSize = 40

    let conversationId: UUID
    let otherUserId: UUID?
    let title: String
    var showsCloseButton = false

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var loading = true
    @State private var loadingOlder = false
    @State private var hasMore = true
    @State private var reportingMessage: Message?
    @State private var errorMessage: String?
    @State private var blockedByMe = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if hasMore && !messages.isEmpty {
                            Button {
                                Task { await loadOlder() }
                            } label: {
                                if loadingOlder {
                                    ProgressView()
                                        .tint(Theme.blue)
                                } else {
                                    Label(
                                        "Load earlier messages",
                                        systemImage: "arrow.up"
                                    )
                                    .font(.caption.weight(.semibold))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 8)
                        }

                        if loading && messages.isEmpty {
                            ProgressView()
                                .tint(Theme.blue)
                                .padding(.top, 24)
                        }

                        ForEach(messages) { message in
                            Bubble(
                                message: message,
                                mine: message.senderId == auth.userId,
                                showReadReceipt: shouldShowReadReceipt(
                                    for: message
                                )
                            )
                            .id(message.id)
                            .contextMenu {
                                if message.senderId != auth.userId {
                                    Button(role: .destructive) {
                                        Task {
                                            await blockSender(
                                                message.senderId
                                            )
                                        }
                                    } label: {
                                        Label(
                                            "Block sender",
                                            systemImage:
                                                "person.crop.circle.badge.xmark"
                                        )
                                    }

                                    Button(role: .destructive) {
                                        reportingMessage = message
                                    } label: {
                                        Label(
                                            "Report message",
                                            systemImage:
                                                "exclamationmark.bubble"
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    composerFocused = false
                }
                .refreshable {
                    await loadLatest()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(
                                last.id,
                                anchor: .bottom
                            )
                        }
                    }
                }
            }

            composer
        }
        .background(Theme.pageBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        composerFocused = false
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    composerFocused = false
                }
            }
        }
        .task {
            await loadBlockState()
            await loadLatest()
            await listenRealtime()
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
        .alert(
            "Messaging error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(
                blockedByMe
                    ? "Unblock this student to send messages"
                    : "Write a message…",
                text: $draft,
                axis: .vertical
            )
            .lineLimit(1...4)
            .focused($composerFocused)
            .submitLabel(.send)
            .onSubmit {
                guard !sending,
                      !blockedByMe,
                      !draft.trimmingCharacters(
                        in: .whitespacesAndNewlines
                      ).isEmpty else {
                    return
                }

                Task { await send() }
            }
            .padding(11)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 13))

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.bold())
                    .frame(width: 42, height: 42)
                    .background(Theme.blueGradient)
                    .foregroundStyle(Theme.onAccent)
                    .clipShape(Circle())
            }
            .disabled(
                draft
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty ||
                sending ||
                blockedByMe
            )
        }
        .padding()
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.ink.opacity(0.06))
                .frame(height: 1)
        }
    }

    @MainActor
    private func loadLatest(silently: Bool = false) async {
        if !silently {
            loading = true
        }

        defer {
            if !silently {
                loading = false
            }
        }

        do {
            let rows = try await DataService.messagesPage(
                conversationId: conversationId,
                limit: pageSize
            )

            if silently && !messages.isEmpty {
                let latestIDs = Set(rows.map(\.id))
                let olderMessages = messages.filter { !latestIDs.contains($0.id) }
                messages = (olderMessages + rows).sorted {
                    if $0.createdAt == $1.createdAt {
                        return $0.id.uuidString < $1.id.uuidString
                    }
                    return $0.createdAt < $1.createdAt
                }
            } else {
                messages = rows
            }

            hasMore = silently ? hasMore : rows.count == pageSize

            try? await DataService.markConversationRead(
                conversationId: conversationId
            )

            errorMessage = nil
        } catch {
            if !silently {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func loadOlder() async {
        guard
            !loadingOlder,
            hasMore,
            let oldest = messages.first
        else {
            return
        }

        loadingOlder = true
        defer { loadingOlder = false }

        do {
            let page = try await DataService.messagesPage(
                conversationId: conversationId,
                before: oldest.createdAt,
                limit: pageSize
            )

            let existing = Set(messages.map(\.id))
            messages.insert(
                contentsOf: page.filter {
                    !existing.contains($0.id)
                },
                at: 0
            )

            hasMore = page.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadBlockState() async {
        guard let otherUserId else { return }

        let blocked =
            (try? await DataService.blockedUserIDs()) ??
            []

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
            composerFocused = false
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
            errorMessage =
                "This student is now blocked. New messages " +
                "between your accounts are disabled."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shouldShowReadReceipt(
        for message: Message
    ) -> Bool {
        guard
            message.senderId == auth.userId,
            message.readAt != nil
        else {
            return false
        }

        return messages.last {
            $0.senderId == auth.userId &&
            $0.readAt != nil
        }?.id == message.id
    }

    private func listenRealtime() async {
        let channel = await supabase.channel(
            "chat-\(conversationId.uuidString)-" +
            UUID().uuidString
        )

        let changes = await channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("conversation_id", value: conversationId.uuidString)
        )

        await channel.subscribe()

        defer {
            Task {
                await supabase.removeChannel(channel)
            }
        }

        for await _ in changes {
            guard !Task.isCancelled else { break }

            await loadLatest(silently: true)
        }
    }
}

struct Bubble: View {
    let message: Message
    let mine: Bool
    let showReadReceipt: Bool

    var body: some View {
        HStack {
            if mine {
                Spacer(minLength: 45)
            }

            VStack(
                alignment: mine ? .trailing : .leading,
                spacing: 3
            ) {
                Text(message.body)
                    .font(.body)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        mine
                            ? Theme.blue
                            : Theme.surfaceRaised
                    )
                    .foregroundStyle(Theme.ink)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )

                if showReadReceipt {
                    Text("Read")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }

            if !mine {
                Spacer(minLength: 45)
            }
        }
    }
}
