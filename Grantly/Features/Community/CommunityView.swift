import AVKit
import SwiftUI
import LiveKit
import UIKit
import Combine

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

                NavigationLink {
                    MyAdvisorConsultationsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.accentSoft)
                            .frame(width: 42, height: 42)
                            .background(Theme.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("My consultations")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)

                            Text("Track live advisor consultation requests")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                if loading && advisors.isEmpty {
                    ProgressView()
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Meet our advisors")
                                .font(.headline.bold())
                                .foregroundStyle(Theme.ink)

                            Spacer()

                            if !advisors.isEmpty {
                                Text(
                                    L10n.format(
                                        "%d available",
                                        advisors.count
                                    )
                                )
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }

                        Text(
                            "Open a profile to watch an introduction and learn how each advisor can help."
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.muted)

                        advisorGrid
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
                    title: destination.title,
                    showsCloseButton: true
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
                    ? L10n.string("Your advisor")
                    : L10n.string("Advisor request pending")
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

    private var advisorGrid: some View {
        let placeholderCount = max(0, 5 - advisors.count)
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(advisors) { advisor in
                NavigationLink {
                    AdvisorDetailView(advisor: advisor)
                } label: {
                    advisorGridCard(advisor)
                }
                .buttonStyle(.plain)
            }

            ForEach(0..<placeholderCount, id: \.self) { _ in
                advisorPlaceholderCard
            }
        }
    }

    private func advisorGridCard(
        _ advisor: AdvisorDirectoryProfile
    ) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Theme.orangeSoft, Theme.blueSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 60, height: 60)

                Circle()
                    .fill(Theme.surfaceRaised)
                    .frame(width: 54, height: 54)

                if let value = advisor.avatarUrl,
                   let url = URL(string: value) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 19))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.muted)
                }
            }

            Text(
                advisor.displayName ??
                L10n.string("EduT Advisor")
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .lineLimit(1)

            if let title = advisor.title,
               !title.isEmpty {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }

            if advisor.isFeatured {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.accentSoft)
                    .accessibilityLabel("Featured")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 124)
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var advisorPlaceholderCard: some View {
        VStack(spacing: 7) {
            Circle()
                .fill(Theme.surfaceRaised)
                .frame(width: 54, height: 54)
                .overlay {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Theme.muted.opacity(0.55))
                }

            Text("New advisor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)

            Text("Coming soon")
                .font(.caption2)
                .foregroundStyle(Theme.muted.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 124)
        .padding(10)
        .background(Theme.surfaceRaised.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    Theme.ink.opacity(0.06),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.string("Advisor coming soon")
        )
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


struct AdvisorDetailView: View {
    let advisor: AdvisorDirectoryProfile

    @State private var openingChat = false
    @State private var chatDestination: AdvisorChatDestination?
    @State private var advisorServices: [AdvisorService] = []
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                introductionVideo
                aboutSection
                pricingSection
                linksSection

                Button {
                    Task { await openDirectConversation() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 42, height: 42)
                            .background(Theme.orangeGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(openingChat ? "Opening chat…" : "Message advisor")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)

                            Text("Start a private conversation in EduT")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        if openingChat {
                            ProgressView()
                                .tint(Theme.accent)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.accent.opacity(0.18))
                    )
                }
                .buttonStyle(.plain)
                .disabled(openingChat)

                NavigationLink {
                    AdvisorConsultationBookingView(advisor: advisor)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 42, height: 42)
                            .background(Theme.orangeGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Book a live consultation")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)

                            Text("One-to-one session · payment arranged after request")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.accent.opacity(0.18))
                    )
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding()
            .padding(.bottom, 28)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAdvisorServices() }
        .sheet(item: $chatDestination) { destination in
            NavigationStack {
                ChatView(
                    conversationId: destination.conversationId,
                    otherUserId: destination.otherUserId,
                    title: destination.title,
                    showsCloseButton: true
                )
            }
        }
    }

    @MainActor
    private func openDirectConversation() async {
        openingChat = true
        defer { openingChat = false }

        do {
            let conversationId =
                try await DataService.ensureAdvisorDirectConversation(
                    advisorId: advisor.id
                )

            chatDestination = AdvisorChatDestination(
                conversationId: conversationId,
                otherUserId: advisor.id,
                title: advisor.displayName ?? L10n.string("EduT Advisor")
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Theme.orangeSoft, Theme.blueSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )

                    Circle()
                        .fill(Theme.surfaceRaised)
                        .padding(5)

                    if let value = advisor.avatarUrl,
                       let url = URL(string: value) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(7)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 104, height: 104)
                .clipShape(Circle())

                HStack(spacing: 18) {
                    advisorStat(
                        value: "\(advisor.specialties.count)",
                        label: "Specialties"
                    )
                    advisorStat(
                        value: "\(advisor.countries.count)",
                        label: "Countries"
                    )
                    advisorStat(
                        value: "\(advisor.languages.count)",
                        label: "Languages"
                    )
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(advisor.displayName ?? "EduT Advisor")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)

                if let title = advisor.title?.nonEmpty {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }

                if let organization = advisor.organization?.nonEmpty {
                    Text(organization)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                if let shortBio = advisor.shortBio?.nonEmpty {
                    Text(shortBio)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                }

                if let years = advisor.yearsExperience {
                    Label(
                        L10n.format(
                            "%d years experience",
                            years
                        ),
                        systemImage: "briefcase.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func advisorStat(
        value: String,
        label: String
    ) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.ink)

            Text(L10n.string(label))
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var introductionVideo: some View {
        if let value = advisor.introVideoUrl,
           let url = URL(string: value) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Introduction")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                if ["mp4", "mov", "m4v"]
                    .contains(url.pathExtension.lowercased()) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.accent)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Watch introduction")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)

                                Text("Opens the advisor's video")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(16)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            if let shortBio = advisor.shortBio?.nonEmpty {
                Text(shortBio)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }

            if let bio = advisor.bio?.nonEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
            }

            if let approach = advisor.mentoringApproach?.nonEmpty {
                Divider()

                Text("How I help")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Text(approach)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Consultation plans")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    Text("Simple pricing · no hidden fees")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Text("LAUNCH PRICE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.orangeGradient)
                    .clipShape(Capsule())
            }

            if advisorServices.isEmpty {
                Text("Consultation pricing will appear here when available.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(advisorServices) { service in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.string(service.title))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(2)

                                Text(
                                    service.serviceType == "six_month_package"
                                        ? "Weekly check-ins · 6 months"
                                        : L10n.format(
                                            "%d min live session",
                                            service.durationMinutes
                                        )
                                )
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                            }

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 2) {
                                if let listPrice = service.listPriceCents,
                                   listPrice > service.priceCents {
                                    Text(
                                        priceText(
                                            cents: listPrice,
                                            currency: service.currency
                                        )
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                                    .strikethrough()
                                }

                                Text(
                                    priceText(
                                        cents: service.priceCents,
                                        currency: service.currency
                                    )
                                )
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.accent)

                                if service.discountPercent == 40 {
                                    Text("Launch price")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.surfaceRaised.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            NavigationLink {
                AdvisorConsultationBookingView(advisor: advisor)
            } label: {
                NavigationLink {
                CommunityConnectionsView()
            } label: {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.blueSoft)
                    .frame(width: 42, height: 42)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityLabel("Friends")

        }
    }

    private var communityHero: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(
                seed: "international students university community",
                height: 190
            )

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

                Text("Connect by ID.")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text(
                    "Share your EduT ID with people you want to connect " +
                    "with. Your academic details stay private."
                )
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
    private func openConversation(
        for profile: CommunityProfile
    ) async {
        messagingProfileID = profile.id
        defer { messagingProfileID = nil }

        do {
            let conversationId = try await DataService
                .startDirectConversation(otherUser: profile.id)

            chatDestination = CommunityChatDestination(
                id: conversationId,
                otherUserId: profile.id,
                title: profile.displayName ?? L10n.string("Student")
            )
            messageError = nil
        } catch {
            messageError = error.localizedDescription
        }
    }

    @MainActor
    private func addFriend(
        from profile: CommunityProfile
    ) async {
        addingFriendProfileID = profile.id
        defer { addingFriendProfileID = nil }

        do {
            let relation = try await DataService
                .sendCommunityFriendRequest(to: profile.id)

            if relation == "outgoing" || relation == "friends" {
                friendRequestSentIDs.insert(profile.id)
            }
            messageError = nil
        } catch {
            messageError = error.localizedDescription
        }
    }

    @MainActor
    private func runSearch() async {
        let trimmed = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            profiles = []
            loading = false
            return
        }

        loading = true
        defer { loading = false }

        do {
            let results = try await DataService.searchCommunityProfiles(
                query: trimmed
            )

            guard !Task.isCancelled else { return }

            let currentQuery = query.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard currentQuery == trimmed else { return }

            profiles = results
        } catch is CancellationError {
            return
        } catch {
            // Live search runs while the user types. A transient or
            // superseded request should never interrupt typing with an alert.
            guard query.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) == trimmed else { return }

            profiles = []
        }
    }

    @MainActor
    private func loadBlockedUsers() async {
        do {
            blockedUserIDs = try await DataService.blockedUserIDs()
        } catch {
            // Keep the previous block state on a transient failure.
        }
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

                if let code = profile.communityCode {
                    Text(code)
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(Theme.blueSoft)
                }

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

private struct CommunityChatDestination: Identifiable {
    let id: UUID
    let otherUserId: UUID
    let title: String
}

struct CommunityConnectionsView: View {
    @State private var requests: [CommunityFriendRequest] = []
    @State private var friends: [CommunityFriend] = []
    @State private var loading = true
    @State private var workingID: UUID?
    @State private var chatDestination: CommunityChatDestination?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if loading && requests.isEmpty && friends.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if !requests.isEmpty {
                Section("Requests") {
                    ForEach(requests) { request in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(request.displayName ?? "Student")
                                .font(.subheadline.bold())

                            if let code = request.communityCode {
                                Text(code)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(Theme.blueSoft)
                            }

                            HStack {
                                Button("Accept") {
                                    Task { await respond(request, accept: true) }
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Decline", role: .destructive) {
                                    Task { await respond(request, accept: false) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            Section("Friends") {
                if friends.isEmpty {
                    Text(
                        requests.isEmpty
                            ? "No friends yet. Search a student and tap Add."
                            : "Accepted friends will appear here."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                } else {
                    ForEach(friends) { friend in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(friend.displayName ?? "Student")
                                    .font(.subheadline.bold())

                                if let code = friend.communityCode {
                                    Text(code)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Theme.blueSoft)
                                }
                            }

                            Spacer()

                            Button("Message") {
                                Task { await message(friend) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(workingID != nil)
                        }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $chatDestination) { destination in
            NavigationStack {
                ChatView(
                    conversationId: destination.id,
                    otherUserId: destination.otherUserId,
                    title: destination.title,
                    showsCloseButton: true
                )
            }
        }
        .alert(
            "Community error",
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
    private func load() async {
        loading = requests.isEmpty && friends.isEmpty
        defer { loading = false }

        do {
            async let requestRows = DataService.communityFriendRequests()
            async let friendRows = DataService.communityFriends()
            requests = try await requestRows
            friends = try await friendRows
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func respond(
        _ request: CommunityFriendRequest,
        accept: Bool
    ) async {
        workingID = request.id
        defer { workingID = nil }

        do {
            try await DataService.respondCommunityFriendRequest(
                requestId: request.id,
                accept: accept
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func message(_ friend: CommunityFriend) async {
        workingID = friend.id
        defer { workingID = nil }

        do {
            let conversationId = try await DataService
                .startDirectConversation(otherUser: friend.userId)
            chatDestination = CommunityChatDestination(
                id: conversationId,
                otherUserId: friend.userId,
                title: friend.displayName ?? "Student"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommunityFriendRequestsView: View {
    @State private var rows: [CommunityFriendRequest] = []
    @State private var loading = true
    @State private var workingID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if loading && rows.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if rows.isEmpty {
                ContentUnavailableView(
                    "No friend requests",
                    systemImage: "person.badge.plus",
                    description: Text(
                        "This page is only for requests other students sent to you. To send a request, search a student in Community and tap the + person button."
                    )
                )
            } else {
                ForEach(rows) { request in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            CommunityAvatar(
                                name: request.displayName ?? "Student",
                                imageURL: request.avatarUrl,
                                size: 46
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(request.displayName ?? "Student")
                                    .font(.subheadline.bold())

                                if let code = request.communityCode {
                                    Text(code)
                                        .font(
                                            .caption2.monospaced()
                                                .weight(.semibold)
                                        )
                                        .foregroundStyle(Theme.blueSoft)
                                }
                            }

                            Spacer()
                        }

                        HStack {
                            Button("Accept") {
                                Task {
                                    await respond(
                                        request,
                                        accept: true
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Decline", role: .destructive) {
                                Task {
                                    await respond(
                                        request,
                                        accept: false
                                    )
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .disabled(workingID != nil)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .navigationTitle("Friend Requests")
        .refreshable { await load() }
        .task { await load() }
        .alert(
            "Unable to update request",
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
    private func load() async {
        loading = rows.isEmpty
        defer { loading = false }

        do {
            rows = try await DataService.communityFriendRequests()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func respond(
        _ request: CommunityFriendRequest,
        accept: Bool
    ) async {
        workingID = request.id
        defer { workingID = nil }

        do {
            try await DataService.respondCommunityFriendRequest(
                requestId: request.id,
                accept: accept
            )
            rows.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommunityFriendsView: View {
    @State private var rows: [CommunityFriend] = []
    @State private var loading = true
    @State private var workingID: UUID?
    @State private var chatDestination: CommunityChatDestination?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if loading && rows.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if rows.isEmpty {
                ContentUnavailableView(
                    "No friends yet",
                    systemImage: "person.2",
                    description: Text(
                        "Search by EduT ID and send a friend request."
                    )
                )
            } else {
                ForEach(rows) { friend in
                    HStack(spacing: 12) {
                        CommunityAvatar(
                            name: friend.displayName ?? "Student",
                            imageURL: friend.avatarUrl,
                            size: 46
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(friend.displayName ?? "Student")
                                .font(.subheadline.bold())

                            if let code = friend.communityCode {
                                Text(code)
                                    .font(
                                        .caption2.monospaced()
                                            .weight(.semibold)
                                    )
                                    .foregroundStyle(Theme.blueSoft)
                            }

                            Text(
                                [friend.nationality, friend.major]
                                    .compactMap { $0 }
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · ")
                            )
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        Button {
                            Task { await message(friend) }
                        } label: {
                            Image(systemName: "message.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(workingID != nil)

                        Menu {
                            Button("Remove friend", role: .destructive) {
                                Task { await remove(friend) }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $chatDestination) { destination in
            NavigationStack {
                ChatView(
                    conversationId: destination.id,
                    otherUserId: destination.otherUserId,
                    title: destination.title,
                    showsCloseButton: true
                )
            }
        }
        .alert(
            "Community error",
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
    private func load() async {
        loading = rows.isEmpty
        defer { loading = false }

        do {
            rows = try await DataService.communityFriends()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func message(_ friend: CommunityFriend) async {
        workingID = friend.id
        defer { workingID = nil }

        do {
            let conversationId =
                try await DataService.startDirectConversation(
                    otherUser: friend.userId
                )

            chatDestination = CommunityChatDestination(
                id: conversationId,
                otherUserId: friend.userId,
                title: friend.displayName ?? "Student"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func remove(_ friend: CommunityFriend) async {
        workingID = friend.id
        defer { workingID = nil }

        do {
            try await DataService.removeCommunityFriend(friend.userId)
            rows.removeAll { $0.id == friend.id }
        } catch {
            errorMessage = error.localizedDescription
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
    @State private var friendshipStatus = "none"
    @State private var changingFriendship = false
    @State private var changingBlock = false
    @State private var chatDestination: CommunityChatDestination?

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
        .task {
            await loadRelationshipState()
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
        .sheet(item: $chatDestination) { destination in
            NavigationStack {
                ChatView(
                    conversationId: destination.id,
                    otherUserId: destination.otherUserId,
                    title: destination.title,
                    showsCloseButton: true
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

            if let code = profile.communityCode {
                Text(code)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(Theme.blueSoft)
                    .textSelection(.enabled)
            }

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
                if isBlocked {
                    Text("This student is blocked.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                } else {
                    friendshipActions
                }

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

    @ViewBuilder
    private var friendshipActions: some View {
        switch friendshipStatus {
        case "friends":
            Button {
                Task { await startConversation() }
            } label: {
                Label(
                    openingConversation ? "Opening..." : "Message friend",
                    systemImage: "message.fill"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(openingConversation)

            Button("Remove friend", role: .destructive) {
                Task { await removeFriend() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(changingFriendship)

        case "outgoing":
            Label("Friend request sent", systemImage: "clock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Cancel request") {
                Task { await cancelFriendRequest() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(changingFriendship)

        case "incoming":
            Button {
                Task { await sendFriendRequest() }
            } label: {
                Label("Accept friend request", systemImage: "person.badge.plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(changingFriendship)

        default:
            Button {
                Task { await sendFriendRequest() }
            } label: {
                Label(
                    changingFriendship ? "Sending..." : "Add friend",
                    systemImage: "person.badge.plus"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(changingFriendship)
        }
    }

    @MainActor
    private func loadRelationshipState() async {
        guard profile.id != auth.userId else { return }

        async let blocked = DataService.blockedUserIDs()
        async let relation = DataService.communityFriendshipStatus(
            with: profile.id
        )

        isBlocked = ((try? await blocked) ?? []).contains(profile.id)
        friendshipStatus = (try? await relation) ?? "none"
    }

    @MainActor
    private func sendFriendRequest() async {
        changingFriendship = true
        defer { changingFriendship = false }

        do {
            friendshipStatus = try await DataService
                .sendCommunityFriendRequest(to: profile.id)
            status = friendshipStatus == "friends"
                ? "You are now friends. Messaging is available."
                : "Friend request sent."
        } catch {
            status = error.localizedDescription
        }
    }

    @MainActor
    private func cancelFriendRequest() async {
        changingFriendship = true
        defer { changingFriendship = false }

        do {
            try await DataService.cancelCommunityFriendRequest(
                to: profile.id
            )
            friendshipStatus = "none"
            status = "Friend request cancelled."
        } catch {
            status = error.localizedDescription
        }
    }

    @MainActor
    private func removeFriend() async {
        changingFriendship = true
        defer { changingFriendship = false }

        do {
            try await DataService.removeCommunityFriend(profile.id)
            friendshipStatus = "none"
            status = "Friend removed."
        } catch {
            status = error.localizedDescription
        }
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
            let conversationId = try await DataService.startDirectConversation(
                otherUser: profile.id
            )

            chatDestination = CommunityChatDestination(
                id: conversationId,
                otherUserId: profile.id,
                title: profile.displayName ?? L10n.string("Student")
            )
            status = ""
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
                await loadRelationshipState()
                status = L10n.string("Student unblocked.")
            } else {
                try await DataService.blockUser(profile.id)
                isBlocked = true
                friendshipStatus = "blocked"
                status = L10n.string("Student blocked. Messaging is disabled between your accounts.")
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


private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
