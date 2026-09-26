import SwiftUI

struct ConversationSummary: Identifiable {
    let id: UUID
}

struct MessagesView: View {
    @Environment(AuthStore.self) private var auth
    @State private var conversations: [ConversationSummary] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if conversations.isEmpty {
                EmptyState(icon: "bubble.left.and.bubble.right", title: "No messages yet", text: "Start a conversation from the Community tab.")
            } else {
                List(conversations) { conversation in
                    NavigationLink {
                        ChatView(conversationId: conversation.id)
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.fill")
                                .frame(width: 42, height: 42)
                                .background(Theme.violet.opacity(0.1))
                                .foregroundStyle(Theme.violet)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading) {
                                Text("Conversation").font(.headline)
                                Text(conversation.id.uuidString.prefix(8))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Messages")
        .refreshable { await load() }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        defer { loading = false }
        guard let userId = auth.userId else { return }
        let rows = (try? await DataService.conversationMemberships(userId: userId)) ?? []
        conversations = rows.map { ConversationSummary(id: $0.conversationId) }
    }
}

struct ChatView: View {
    @Environment(AuthStore.self) private var auth
    let conversationId: UUID
    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var reportingMessage: Message?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            Bubble(message: message, mine: message.senderId == auth.userId)
                                .id(message.id)
                                .contextMenu {
                                    if message.senderId != auth.userId {
                                        Button(role: .destructive) {
                                            reportingMessage = message
                                        } label: {
                                            Label("Report message", systemImage: "exclamationmark.bubble")
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .refreshable { await load() }
                .onChange(of: messages.count) {
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(spacing: 10) {
                TextField("Write a message…", text: $draft, axis: .vertical)
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
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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
    }

    @MainActor
    private func load() async {
        messages = (try? await DataService.messages(conversationId: conversationId)) ?? []
    }

    @MainActor
    private func send() async {
        guard let userId = auth.userId else { return }
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        sending = true
        draft = ""
        defer { sending = false }
        do {
            try await DataService.sendMessage(conversationId: conversationId, senderId: userId, body: body)
            await load()
        } catch {}
    }
}

struct Bubble: View {
    let message: Message
    let mine: Bool

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 45) }
            Text(message.body)
                .font(.body)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(mine ? Theme.violet : Color(.secondarySystemBackground))
                .foregroundStyle(mine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !mine { Spacer(minLength: 45) }
        }
    }
}
