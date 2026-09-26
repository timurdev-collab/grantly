import SwiftUI

struct CommunityView: View {
    @State private var profiles: [CommunityProfile] = []
    @State private var blockedUserIDs: Set<UUID> = []
    @State private var query = ""
    @State private var loading = true

    private var filtered: [CommunityProfile] {
        profiles.filter { profile in
            guard !blockedUserIDs.contains(profile.id) else {
                return false
            }

            let q = query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard !q.isEmpty else {
                return true
            }

            let searchableText =
                "\(profile.displayName ?? "") " +
                "\(profile.nationality ?? "") " +
                "\(profile.major ?? "") " +
                "\(profile.targetCountries?.joined(separator: " ") ?? "")"

            return searchableText
                .lowercased()
                .contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                communityHero

                AcademicSectionHeader(
                    eyebrow: "Peer network",
                    title: "Students on the same path",
                    trailing: "\(filtered.count) profiles"
                )

                if loading {
                    ProgressView()
                        .tint(Theme.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else if filtered.isEmpty {
                    EmptyState(
                        icon: "person.3",
                        title: "No students found",
                        text: "Try a different search."
                    )
                    .padding(.top, 30)
                } else {
                    LazyVStack(spacing: 11) {
                        ForEach(filtered) { profile in
                            NavigationLink(value: profile) {
                                CommunityRow(profile: profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.pageBackground)
        .searchable(
            text: $query,
            prompt: "Name, country or field"
        )
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MessagesView()
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(Theme.orange)
                }
                .accessibilityLabel("Messages")
            }
        }
        .navigationDestination(
            for: CommunityProfile.self
        ) { profile in
            CommunityProfileView(profile: profile)
        }
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
    }

    private var communityHero: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionEyebrow(text: "Global cohort")

            Text("Meet people\napplying beyond borders.")
                .font(Theme.serifTitle(30, weight: .medium))
                .foregroundStyle(Color.white)

            Text("Connect around universities, fields and destination goals — not follower counts.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .lineSpacing(3)

            HStack {
                Label(
                    "Private by default",
                    systemImage: "lock"
                )

                Spacer()

                Label(
                    "Report & block",
                    systemImage: "hand.raised"
                )
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(20)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        async let profileRows =
            DataService.communityProfiles()

        async let blockedRows =
            DataService.blockedUserIDs()

        profiles = (try? await profileRows) ?? []
        blockedUserIDs = (try? await blockedRows) ?? []
    }
}

struct CommunityRow: View {
    let profile: CommunityProfile

    var body: some View {
        PremiumCard {
            HStack(spacing: 14) {
                CommunityMonogram(
                    name: profile.displayName ?? "Student"
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.displayName ?? "Student")
                        .font(Theme.serifTitle(18))
                        .foregroundStyle(.white)

                    Text(
                        [profile.nationality, profile.major]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))

                    if let countries = profile.targetCountries,
                       !countries.isEmpty {
                        Text(
                            countries.prefix(3)
                                .joined(separator: " · ")
                        )
                        .font(.caption2)
                        .foregroundStyle(Theme.orange)
                        .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.orange)
            }
        }
    }
}

private struct CommunityMonogram: View {
    let name: String

    var body: some View {
        Text(String(name.prefix(2)).uppercased())
            .font(.system(size: 14, weight: .semibold, design: .serif))
            .foregroundStyle(Color.white)
            .frame(width: 48, height: 48)
            .background(Theme.navy)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(Theme.orange.opacity(0.35))
            )
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
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 13) {
                    CommunityMonogram(
                        name: profile.displayName ?? "Student"
                    )
                    .scaleEffect(1.45)
                    .padding(.vertical, 10)

                    Text(profile.displayName ?? "Student")
                        .font(Theme.serifTitle(28))
                        .foregroundStyle(.white)

                    Text(
                        [profile.nationality, profile.major]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                }

                if let bio = profile.bio,
                   !bio.isEmpty {
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 9) {
                            SectionEyebrow(text: "About")
                            Text(bio)
                                .font(.body)
                                .foregroundStyle(.white)
                                .lineSpacing(4)
                        }
                    }
                }

                if let countries = profile.targetCountries,
                   !countries.isEmpty {
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionEyebrow(text: "Destination goals")

                            Text(
                                countries.joined(separator: " · ")
                            )
                            .font(Theme.serifTitle(19))
                            .foregroundStyle(.white)
                        }
                    }
                }

                Button {
                    Task {
                        await startConversation()
                    }
                } label: {
                    Label(
                        openingConversation
                            ? "Opening…"
                            : "Start conversation",
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
                        Task {
                            await toggleBlock()
                        }
                    } label: {
                        Label(
                            changingBlock
                                ? "Updating…"
                                : (
                                    isBlocked
                                        ? "Unblock student"
                                        : "Block student"
                                ),
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.orange)
                }

                if !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding()
        }
        .background(Theme.pageBackground)
        .navigationTitle("Student")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockState()
        }
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
        guard profile.id != auth.userId else {
            return
        }

        let blocked =
            (try? await DataService.blockedUserIDs()) ?? []

        isBlocked = blocked.contains(profile.id)
    }

    @MainActor
    private func startConversation() async {
        guard profile.id != auth.userId,
              !isBlocked else {
            return
        }

        openingConversation = true
        defer { openingConversation = false }

        do {
            _ = try await DataService.startDirectConversation(
                otherUser: profile.id
            )

            status =
                "Conversation created. Open Messages from Community."
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
                status =
                    "Student blocked. Messaging is disabled between your accounts."
            }
        } catch {
            status = error.localizedDescription
        }
    }
}
