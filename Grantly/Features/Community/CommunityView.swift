import SwiftUI

struct CommunityView: View {
    @State private var profiles: [CommunityProfile] = []
    @State private var blockedUserIDs: Set<UUID> = []
    @State private var query = ""
    @State private var loading = true

    private var filtered: [CommunityProfile] {
        profiles.filter { profile in
            guard !blockedUserIDs.contains(profile.id) else { return false }

            let q = query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard !q.isEmpty else { return true }

            return "\(profile.displayName ?? "") \(profile.nationality ?? "") \(profile.major ?? "") \(profile.targetCountries?.joined(separator: " ") ?? "")"
                .lowercased()
                .contains(q)
        }
    }

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if filtered.isEmpty {
                EmptyState(
                    icon: "person.3",
                    title: "No students found",
                    text: "Try a different search."
                )
            } else {
                List(filtered) { profile in
                    NavigationLink(value: profile) {
                        CommunityRow(profile: profile)
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .searchable(text: $query, prompt: "Name, country, major")
        .navigationTitle("Community")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MessagesView()
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
                .accessibilityLabel("Messages")
            }
        }
        .navigationDestination(for: CommunityProfile.self) { profile in
            CommunityProfileView(profile: profile)
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        async let profileRows = DataService.communityProfiles()
        async let blockedRows = DataService.blockedUserIDs()

        profiles = (try? await profileRows) ?? []
        blockedUserIDs = (try? await blockedRows) ?? []
    }
}

struct CommunityRow: View {
    let profile: CommunityProfile

    var body: some View {
        HStack(spacing: 12) {
            Text((profile.displayName ?? "?").prefix(2).uppercased())
                .font(.caption.bold())
                .frame(width: 44, height: 44)
                .background(Theme.violet.opacity(0.12))
                .foregroundStyle(Theme.violet)
                .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName ?? "Student")
                    .font(.headline)

                Text([profile.nationality, profile.major].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CommunityProfileView: View {
    @Environment(AuthStore.self) private var auth

    let profile: CommunityProfile

    @State private var status = ""
    @State private var openingConversation = false
    @State private var showingReport = false
    @State private var isBlocked = false
    @State private var changingBlock = false

    var body: some View {
        VStack(spacing: 20) {
            Text((profile.displayName ?? "?").prefix(2).uppercased())
                .font(.title.bold())
                .frame(width: 82, height: 82)
                .background(Theme.violet.opacity(0.12))
                .foregroundStyle(Theme.violet)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            Text(profile.displayName ?? "Student")
                .font(.title2.bold())

            Text([profile.nationality, profile.major].compactMap { $0 }.joined(separator: " · "))
                .foregroundStyle(.secondary)

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .multilineTextAlignment(.center)
            }

            if let countries = profile.targetCountries, !countries.isEmpty {
                VStack {
                    Text("Target countries")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(countries.joined(separator: " · "))
                        .font(.subheadline.bold())
                }
            }

            Button {
                Task { await startConversation() }
            } label: {
                Label(
                    openingConversation ? "Opening…" : "Start conversation",
                    systemImage: "message.fill"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(
                profile.id == auth.userId ||
                openingConversation ||
                isBlocked
            )

            if profile.id != auth.userId {
                Button {
                    Task { await toggleBlock() }
                } label: {
                    Label(
                        changingBlock
                            ? "Updating…"
                            : (isBlocked ? "Unblock student" : "Block student"),
                        systemImage: isBlocked
                            ? "person.crop.circle.badge.checkmark"
                            : "person.crop.circle.badge.xmark"
                    )
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(changingBlock)

                Button {
                    showingReport = true
                } label: {
                    Label(
                        "Report student",
                        systemImage: "exclamationmark.bubble"
                    )
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Student")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBlockState() }
        .sheet(isPresented: $showingReport) {
            ReportSheet(
                subject: profile.displayName ?? "student"
            ) { reason, details in
                try await DataService.submitSafetyReport(
                    reportedUserId: profile.id,
                    reason: reason,
                    details: details
                )
            }
        }
    }

    @MainActor
    private func loadBlockState() async {
        guard profile.id != auth.userId else { return }
        let blocked = (try? await DataService.blockedUserIDs()) ?? []
        isBlocked = blocked.contains(profile.id)
    }

    @MainActor
    private func startConversation() async {
        guard profile.id != auth.userId, !isBlocked else { return }

        openingConversation = true
        defer { openingConversation = false }

        do {
            _ = try await DataService.startDirectConversation(
                otherUser: profile.id
            )
            status = "Conversation created. Tap the messages icon in Community."
        } catch {
            status = error.localizedDescription
        }
    }

    @MainActor
    private func toggleBlock() async {
        changingBlock = true
        defer { changingBlock = false }

        do {
            if isBlocked {
                try await DataService.unblockUser(profile.id)
                isBlocked = false
                status = "Student unblocked."
            } else {
                try await DataService.blockUser(profile.id)
                isBlocked = true
                status = "Student blocked. Messaging is disabled between your accounts."
            }
        } catch {
            status = error.localizedDescription
        }
    }
}
