import SwiftUI

struct AdvisorsView: View {
    @State private var advisors: [AdvisorDirectoryProfile] = []
    @State private var registration: AdvisorRegistration?
    @State private var loading = true
    @State private var requestingAdvisorID: UUID?
    @State private var errorMessage: String?
    @State private var chatDestination: AdvisorChatDestination?
    @State private var callSession: AdvisorCallSession?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Advisors")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.ink)

                    Text(
                        "Choose a verified advisor to support your study plans"
                    )
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                }

                if let registration {
                    currentRegistrationCard(registration)
                }

                if loading && advisors.isEmpty {
                    ProgressView()
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                } else if advisors.isEmpty {
                    EmptyState(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "No advisors available yet",
                        text:
                            "Approved counselors will appear here once they are available."
                    )
                    .padding(.vertical, 24)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available advisors")
                            .font(.headline.bold())
                            .foregroundStyle(Theme.ink)

                        ForEach(advisors) { advisor in
                            advisorCard(advisor)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationBarHidden(true)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $chatDestination) { destination in
            NavigationStack {
                ChatView(
                    conversationId: destination.conversationId,
                    otherUserId: destination.otherUserId,
                    title: destination.title
                )
            }
        }
        .sheet(item: $callSession) { session in
            AdvisorCallPreparationView(session: session)
        }
    }

    private func currentRegistrationCard(
        _ registration: AdvisorRegistration
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(
                registration.status == "active"
                    ? "Your advisor"
                    : "Advisor request pending"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accentSoft)

            Text(registration.advisorName)
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            if let title = registration.advisorTitle,
               !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            if registration.status == "active" {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await openConversation(registration)
                        }
                    } label: {
                        Label(
                            "Message",
                            systemImage: "bubble.left.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.orangeGradient)
                        .foregroundStyle(Theme.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await prepareVideoCall(registration)
                        }
                    } label: {
                        Label(
                            "Video",
                            systemImage: "video.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.surface)
                        .foregroundStyle(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(
                    "The advisor can accept your registration from their Advisor Portal."
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func advisorCard(
        _ advisor: AdvisorDirectoryProfile
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(Theme.surfaceRaised)
                        .frame(width: 58, height: 58)

                    if let value = advisor.avatarUrl,
                       let url = URL(string: value) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Theme.muted)
                        }
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Theme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(advisor.displayName ?? "Grantly Advisor")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    if let title = advisor.title,
                       !title.isEmpty {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accentSoft)
                    }

                    let detail = (
                        advisor.specialties +
                        advisor.countries
                    )
                    .prefix(3)
                    .joined(separator: " · ")

                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            if let bio = advisor.bio,
               !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(4)
            }

            Button {
                Task { await request(advisor) }
            } label: {
                Label(
                    requestingAdvisorID == advisor.id
                        ? "Sending request…"
                        : buttonTitle(for: advisor),
                    systemImage: "person.badge.plus"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.orangeGradient)
                .foregroundStyle(Theme.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(
                requestingAdvisorID != nil ||
                registration?.status == "active" ||
                registration?.advisorId == advisor.id
            )
            .opacity(
                registration?.status == "active" ||
                registration?.advisorId == advisor.id
                    ? 0.55
                    : 1
            )
        }
        .padding(17)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private func buttonTitle(
        for advisor: AdvisorDirectoryProfile
    ) -> String {
        if let registration {
            if registration.advisorId == advisor.id {
                return registration.status == "active"
                    ? "Your advisor"
                    : "Request sent"
            }

            if registration.status == "active" {
                return "Already registered"
            }
        }

        return "Register with advisor"
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            async let directoryRows = DataService.availableAdvisors()
            async let currentRegistration =
                DataService.myAdvisorRegistration()

            advisors = try await directoryRows
            registration = try await currentRegistration
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openConversation(
        _ registration: AdvisorRegistration
    ) async {
        do {
            let conversationId =
                try await DataService.ensureAdvisorConversation(
                    assignmentId: registration.assignmentId
                )

            chatDestination = AdvisorChatDestination(
                conversationId: conversationId,
                otherUserId: registration.advisorId,
                title: registration.advisorName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func prepareVideoCall(
        _ registration: AdvisorRegistration
    ) async {
        do {
            callSession =
                try await DataService.createAdvisorCallSession(
                    assignmentId: registration.assignmentId
                )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func request(
        _ advisor: AdvisorDirectoryProfile
    ) async {
        requestingAdvisorID = advisor.id
        defer { requestingAdvisorID = nil }

        do {
            try await DataService.requestAdvisor(
                advisorId: advisor.id
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


struct AdvisorChatDestination: Identifiable {
    let conversationId: UUID
    let otherUserId: UUID
    let title: String

    var id: UUID { conversationId }
}

struct AdvisorCallPreparationView: View {
    @Environment(\.dismiss) private var dismiss
    @State var session: AdvisorCallSession
    @State private var recordingConsent = false
    @State private var savingConsent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label(
                    "Secure advisor video session",
                    systemImage: "video.fill"
                )
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)

                Text(
                    "The Grantly relationship and room are ready. Camera, microphone and screen sharing connect through the configured realtime media service."
                )
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

                Toggle(
                    "Allow this session to be recorded",
                    isOn: $recordingConsent
                )
                .tint(Theme.accent)
                .onChange(of: recordingConsent) {
                    Task { await updateRecordingConsent() }
                }

                Text(
                    "Recording only becomes available after both the student and advisor explicitly consent."
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)

                Label(
                    "Screen sharing is allowed for this session",
                    systemImage: "rectangle.on.rectangle"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.surfaceRaised)
                .foregroundStyle(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(Theme.pageBackground)
            .navigationTitle("Video Call")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func updateRecordingConsent() async {
        savingConsent = true
        defer { savingConsent = false }

        do {
            session =
                try await DataService
                    .setAdvisorCallRecordingConsent(
                        callId: session.id,
                        consent: recordingConsent
                    )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

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

    private var featured: [CommunityProfile] {
        Array(filtered.prefix(8))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                SearchField(
                    text: $query,
                    prompt: "Search students, countries or fields..."
                )

                communityHero

                if loading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.blue)

                        Text("Loading the Grantly community...")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else if filtered.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.3")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Theme.blueSoft)
                            .frame(width: 62, height: 62)
                            .background(Theme.surface)
                            .clipShape(Circle())

                        Text("No students found")
                            .font(.headline.bold())
                            .foregroundStyle(Theme.ink)

                        Text("Try another name, country or study field.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Students to connect with")
                                .font(.headline.bold())
                                .foregroundStyle(Theme.ink)

                            Text("\(filtered.count) visible community profiles")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        Image(systemName: "globe.americas.fill")
                            .foregroundStyle(Theme.blueSoft)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(featured) { profile in
                            NavigationLink(value: profile) {
                                CommunityRow(profile: profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationBarHidden(true)
        .navigationDestination(for: CommunityProfile.self) { profile in
            CommunityProfileView(profile: profile)
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Community")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Meet students pursuing opportunities worldwide")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            NavigationLink {
                MessagesView()
            } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.blueSoft)
                    .frame(width: 42, height: 42)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityLabel("Messages")
        }
    }

    private var communityHero: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(seed: "international students university community", height: 190)

            LinearGradient(
                colors: [
                    Theme.navyDeep.opacity(0.06),
                    Theme.navyDeep.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("GLOBAL COHORT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.blueSoft)

                Text("You are not applying\nalone.")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Connect around study goals, countries and universities while keeping sensitive academic details private.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .frame(maxWidth: 290, alignment: .leading)

                HStack(spacing: 14) {
                    Label("Private profile", systemImage: "lock.fill")
                    Label("Report & block", systemImage: "hand.raised.fill")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            }
            .padding(16)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 22))
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

    private var destinations: String {
        let values = profile.targetCountries ?? []
        return values.isEmpty
            ? "Open to global opportunities"
            : values.prefix(3).joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 13) {
            CommunityAvatar(
                name: profile.displayName ?? "Student",
                imageURL: profile.avatarUrl,
                size: 54
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.displayName ?? "Student")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.ink)

                Text(
                    [profile.nationality, profile.major]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)

                Label(destinations, systemImage: "airplane")
                    .font(.caption2)
                    .foregroundStyle(Theme.blueSoft)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.ink.opacity(0.35))
        }
        .padding(13)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct CommunityAvatar: View {
    let name: String
    var imageURL: String? = nil
    var size: CGFloat = 54

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return (
                String(words[0].prefix(1)) +
                String(words[1].prefix(1))
            ).uppercased()
        }

        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.blueSoft.opacity(0.95), Theme.blue.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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
                            .font(.system(size: size * 0.27, weight: .bold))
                            .foregroundStyle(Theme.ink)
                    }
                }
            } else {
                Text(initials)
                    .font(.system(size: size * 0.27, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Theme.ink.opacity(0.12))
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                profileHeader

                if let bio = profile.bio,
                   !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ProfileInfoCard(
                        title: "About",
                        icon: "person.text.rectangle"
                    ) {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(4)
                    }
                }

                if let countries = profile.targetCountries,
                   !countries.isEmpty {
                    ProfileInfoCard(
                        title: "Destination goals",
                        icon: "airplane"
                    ) {
                        FlowingText(values: countries)
                    }
                }

                if let regions = profile.targetRegions,
                   !regions.isEmpty {
                    ProfileInfoCard(
                        title: "Target regions",
                        icon: "globe"
                    ) {
                        FlowingText(values: regions)
                    }
                }

                actions

                if !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
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

    private var profileHeader: some View {
        VStack(spacing: 12) {
            CommunityAvatar(
                name: profile.displayName ?? "Student",
                imageURL: profile.avatarUrl,
                size: 86
            )
            .padding(.top, 8)

            Text(profile.displayName ?? "Student")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(
                [profile.nationality, profile.major]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            )
            .font(.subheadline)
            .foregroundStyle(Theme.muted)

            HStack(spacing: 8) {
                Label("Community profile", systemImage: "person.2.fill")
                Label("Sensitive data hidden", systemImage: "lock.fill")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.blueSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Theme.surfaceRaised, Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if profile.id != auth.userId {
                Button {
                    Task { await startConversation() }
                } label: {
                    Label(
                        openingConversation
                            ? "Opening..."
                            : "Start conversation",
                        systemImage: "message.fill"
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(openingConversation || isBlocked)

                Button {
                    Task { await toggleBlock() }
                } label: {
                    Label(
                        changingBlock
                            ? "Updating..."
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                Text("This is your public community profile.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    @MainActor
    private func loadBlockState() async {
        guard profile.id != auth.userId else {
            return
        }

        let blocked = (try? await DataService.blockedUserIDs()) ?? []
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

            status = "Conversation created. Open Messages from Community."
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

private struct ProfileInfoCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.blueSoft)
                    .frame(width: 32, height: 32)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            content
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct FlowingText: View {
    let values: [String]

    var body: some View {
        Text(values.joined(separator: " · "))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.blueSoft)
            .lineSpacing(3)
    }
}
