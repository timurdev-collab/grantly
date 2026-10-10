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
                HStack(spacing: 8) {
                    Text("Choose a plan")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                }
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Theme.orangeGradient)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.accent.opacity(0.10))
        )
    }

    private func priceText(cents: Int, currency: String) -> String {
        String(
            format: "%@ %.2f",
            currency,
            Double(cents) / 100.0
        )
    }

    @MainActor
    private func loadAdvisorServices() async {
        do {
            advisorServices = try await DataService.availableAdvisorServices(
                advisorId: advisor.id
            )
        } catch {
            advisorServices = []
        }
    }

    @ViewBuilder
    private var linksSection: some View {
        if advisor.linkedinUrl?.nonEmpty != nil ||
            advisor.websiteUrl?.nonEmpty != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("Professional links")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                if let value = advisor.linkedinUrl,
                   let url = URL(string: value) {
                    Link(destination: url) {
                        Label(
                            "LinkedIn",
                            systemImage: "person.text.rectangle"
                        )
                    }
                }

                if let value = advisor.websiteUrl,
                   let url = URL(string: value) {
                    Link(destination: url) {
                        Label(
                            "Website",
                            systemImage: "globe"
                        )
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

private enum AdvisorLegalDocument: String, Identifiable {
    case terms
    case privacy
    case refunds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms:
            return "Terms & Conditions"
        case .privacy:
            return "Privacy Policy"
        case .refunds:
            return "Cancellation & Refund Policy"
        }
    }

    var bodyText: String {
        switch self {
        case .terms:
            return """
            Advisor services are provided by independent advisors through EduT. A consultation request does not charge you and does not guarantee a booking until payment and scheduling are confirmed.

            Prices, duration and included support are shown before you submit a request. The 6-month guidance package includes weekly one-to-one check-ins for six months and does not renew automatically.

            Advisors provide educational guidance and application support. EduT and its advisors do not guarantee admission, scholarships, visas, employment, test scores or any other outcome.

            You must provide accurate contact and scheduling information and use the service lawfully and respectfully. You may not misuse advisor contact details, recordings or materials.

            Any non-waivable rights available to you under applicable consumer law continue to apply. Material changes to these terms will require a new acceptance before a future paid request.
            """
        case .privacy:
            return """
            EduT uses your account information, selected service, email address, WhatsApp number, preferred time, topic and notes to coordinate the consultation.

            Your direct contact details stay hidden from the selected advisor until payment is recorded by EduT. EduT may retain booking, payment-status and consent records for customer support, fraud prevention, legal compliance and dispute handling.

            Only information reasonably necessary to provide the requested service should be shared. Do not place passwords, financial account details or other unnecessary sensitive information in consultation notes.

            You may exercise privacy rights available under applicable law. EduT will not treat acceptance of consultation terms as consent to unrelated marketing.
            """
        case .refunds:
            return """
            Sending a consultation request does not charge you. Payment instructions are provided separately after the request is reviewed.

            If EduT or the advisor cannot provide a confirmed paid service, any payment collected for that service will be refunded.

            For scheduled one-to-one sessions, cancellation or rescheduling requests should be made as early as possible. Eligibility for a refund can depend on how close the request is to the confirmed session time and whether the service has already started.

            For multi-session packages, any legally required cancellation or withdrawal rights remain available. Services already delivered may affect the refundable amount where permitted by law.

            Before payment, EduT will show or provide any service-specific cancellation terms that apply. Mandatory consumer rights in your jurisdiction override any conflicting policy term.
            """
        }
    }
}

private struct AdvisorLegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: AdvisorLegalDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document.bodyText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AdvisorConsultationBookingView: View {
    @Environment(\.dismiss) private var dismiss

    let advisor: AdvisorDirectoryProfile

    @State private var services: [AdvisorService] = []
    @State private var selectedServiceID: UUID?
    @State private var contactEmail = ""
    @State private var whatsappNumber = ""
    @State private var preferredStart =
        Date().addingTimeInterval(24 * 60 * 60)
    @State private var topic = ""
    @State private var notes = ""
    @State private var consent = false
    @State private var legalAcknowledgement = false
    @State private var termsAcceptanceID: UUID?
    @State private var legalDocument: AdvisorLegalDocument?
    @State private var acceptingTerms = false
    @State private var loading = true
    @State private var submitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    private let termsVersion = "2026-10-04.v1"
    private let privacyVersion = "2026-10-04.v1"
    private let refundPolicyVersion = "2026-10-04.v1"

    private var selectedService: AdvisorService? {
        services.first { $0.id == selectedServiceID }
    }

    private var canSubmit: Bool {
        selectedService != nil &&
        termsAcceptanceID != nil &&
        contactEmail.contains("@") &&
        whatsappNumber.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count >= 7 &&
        topic.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count >= 3 &&
        consent &&
        !submitting
    }

    var body: some View {
        Group {
            if submitted {
                successView
            } else if termsAcceptanceID == nil {
                legalGateView
            } else {
                formView
            }
        }
        .background(Theme.pageBackground)
        .navigationTitle("Advisor services")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $legalDocument) { document in
            AdvisorLegalDocumentView(document: document)
        }
    }

    private var legalGateView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Label(
                        "Before you choose a plan",
                        systemImage: "checkmark.shield.fill"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)

                    Text(
                        "Please review and accept the booking terms. This keeps pricing, privacy and cancellation rules clear before you select a service."
                    )
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                }

                VStack(spacing: 0) {
                    legalLink(.terms)
                    Divider()
                    legalLink(.privacy)
                    Divider()
                    legalLink(.refunds)
                }
                .padding(.horizontal, 14)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        "Important booking points",
                        systemImage: "info.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                    legalPoint("Submitting a request does not charge you.")
                    legalPoint("Prices are shown before you select and submit a plan.")
                    legalPoint("Contact details remain hidden from the advisor until payment is recorded.")
                    legalPoint("The 6-month package is a one-time purchase and does not auto-renew.")
                    legalPoint("Admission, scholarship, visa or other outcomes are not guaranteed.")
                }
                .padding(14)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    legalAcknowledgement.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 11) {
                        Image(
                            systemName:
                                legalAcknowledgement
                                ? "checkmark.square.fill"
                                : "square"
                        )
                        .font(.system(size: 22))
                        .foregroundStyle(
                            legalAcknowledgement
                                ? Theme.accent
                                : Theme.muted
                        )

                        Text(
                            "I have read and agree to the Terms & Conditions and Cancellation & Refund Policy, and I acknowledge the Privacy Policy."
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }

                Button {
                    Task { await acceptTerms() }
                } label: {
                    HStack {
                        Spacer()
                        if acceptingTerms {
                            ProgressView()
                                .tint(Theme.onAccent)
                        } else {
                            Text("Accept & continue to plans")
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                    }
                    .frame(height: 50)
                    .foregroundStyle(
                        legalAcknowledgement
                            ? Theme.onAccent
                            : Theme.muted
                    )
                    .background(
                        legalAcknowledgement
                            ? Theme.orangeGradient
                            : LinearGradient(
                                colors: [
                                    Theme.surfaceRaised,
                                    Theme.surfaceRaised
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .disabled(!legalAcknowledgement || acceptingTerms)

                Text(
                    "Terms version: \(termsVersion). Your acceptance time and policy versions are recorded for the booking process."
                )
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            }
            .padding()
            .padding(.bottom, 28)
        }
    }

    private func legalLink(
        _ document: AdvisorLegalDocument
    ) -> some View {
        Button {
            legalDocument = document
        } label: {
            HStack {
                Text(document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Spacer()

                Text("Read")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func legalPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Theme.accent)
                .padding(.top, 2)

            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    @MainActor
    private func acceptTerms() async {
        guard legalAcknowledgement, !acceptingTerms else { return }

        acceptingTerms = true
        defer { acceptingTerms = false }

        do {
            termsAcceptanceID =
                try await DataService.acceptAdvisorBookingTerms(
                    advisorId: advisor.id,
                    termsVersion: termsVersion,
                    privacyVersion: privacyVersion,
                    refundPolicyVersion: refundPolicyVersion
                )
            selectedServiceID = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(advisor.displayName ?? "EduT Advisor")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)

                    Text(
                        "Choose the support that fits you best. Introductory pricing is shown clearly before you send a request."
                    )
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose a plan")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    } else if services.isEmpty {
                        Text("No consultation services are available right now.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    } else {
                        ForEach(services) { service in
                            Button {
                                selectedServiceID = service.id
                            } label: {
                                serviceRow(service)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Contact details")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    TextField("Email address", text: $contactEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    TextField(
                        "WhatsApp number with country code",
                        text: $whatsappNumber
                    )
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)

                    Text(
                        "Example: +84 912 345 678. EduT stores these details securely and releases them to the selected advisor only after payment is recorded."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferred time")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    DatePicker(
                        "Date and time",
                        selection: $preferredStart,
                        in: Date().addingTimeInterval(15 * 60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Text(
                        L10n.format(
                            "Time zone: %@",
                            TimeZone.current.identifier
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    Text("What do you need help with?")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    TextField(
                        "Example: scholarship application strategy",
                        text: $topic,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        "Additional notes (optional)",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...7)
                    .textFieldStyle(.roundedBorder)
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                if let service = selectedService {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review before submitting")
                            .font(.headline.bold())
                            .foregroundStyle(Theme.ink)

                        HStack {
                            Text(service.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)

                            Spacer()

                            Text(priceText(service))
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.accent)
                        }

                        Text(
                            service.serviceType == "six_month_package"
                                ? "One-time purchase · weekly check-ins for 6 months · no automatic renewal"
                                : "\(service.durationMinutes)-minute one-to-one live session"
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.muted)

                        Text(
                            "Your accepted Terms, Privacy Policy and Cancellation & Refund Policy apply to this request."
                        )
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Toggle(isOn: $consent) {
                    Text(
                        "I agree that EduT may use my email and WhatsApp number to coordinate this consultation."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.ink)
                }
                .tint(Theme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        "Payment is arranged before direct contact is unlocked.",
                        systemImage: "creditcard"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                    Text(
                        "This request does not charge you. Payment instructions will be provided separately, and the advisor will receive your contact details only after payment is recorded."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                }
                .padding(14)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()

                        if submitting {
                            ProgressView()
                                .tint(Theme.onAccent)
                        } else {
                            Label(
                                "Request consultation",
                                systemImage: "calendar.badge.plus"
                            )
                        }

                        Spacer()
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(height: 50)
                    .background(
                        canSubmit
                            ? Theme.orangeGradient
                            : LinearGradient(
                                colors: [
                                    Theme.surfaceRaised,
                                    Theme.surfaceRaised
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .foregroundStyle(
                        canSubmit ? Theme.onAccent : Theme.muted
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding()
            .padding(.bottom, 28)
        }
    }

    private var successView: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(Theme.accent)

            Text("Consultation request sent")
                .font(.title2.bold())
                .foregroundStyle(Theme.ink)

            if let service = selectedService {
                Text(
                    L10n.format(
                        "%@ · %d min · %@",
                        service.title,
                        service.durationMinutes,
                        priceText(service)
                    )
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            }

            Text(
                "Your request has been sent. EduT will coordinate payment first; WhatsApp and email contact details stay hidden from the advisor until payment is recorded."
            )
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .lineSpacing(3)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)

            Spacer()
        }
        .padding(28)
    }

    private func serviceRow(
        _ service: AdvisorService
    ) -> some View {
        let selected = selectedServiceID == service.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(
                    systemName:
                        selected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.system(size: 21))
                .foregroundStyle(
                    selected ? Theme.accent : Theme.muted
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string(service.title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if service.serviceType == "six_month_package" {
                        Text("Weekly check-ins for 6 months")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text(
                            L10n.format(
                                "%d min live session",
                                service.durationMinutes
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    }
                }

                Spacer(minLength: 8)

                if service.discountPercent == 40 {
                    Text("Launch price")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.orangeGradient)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if let listPrice = service.listPriceCents,
                   listPrice > service.priceCents {
                    Text(
                        priceText(
                            cents: listPrice,
                            currency: service.currency
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .strikethrough()
                }

                Text(priceText(service))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
            }
            .padding(.leading, 33)
        }
        .padding(14)
        .background(
            selected
                ? Theme.surfaceRaised
                : Theme.surface
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    selected
                        ? Theme.accent.opacity(0.45)
                        : Theme.ink.opacity(0.05)
                )
        )
    }

    private func priceText(
        _ service: AdvisorService
    ) -> String {
        priceText(
            cents: service.priceCents,
            currency: service.currency
        )
    }

    private func priceText(
        cents: Int,
        currency: String
    ) -> String {
        String(
            format: "%@ %.2f",
            currency,
            Double(cents) / 100.0
        )
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            async let rows = DataService.availableAdvisorServices(
                advisorId: advisor.id
            )

            if contactEmail.isEmpty {
                contactEmail =
                    (try? await supabase.auth.session.user.email) ?? ""
            }

            services = try await rows
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func submit() async {
        guard let service = selectedService,
              canSubmit else {
            return
        }

        submitting = true
        defer { submitting = false }

        do {
            try await DataService.submitAdvisorConsultationRequest(
                advisorId: advisor.id,
                serviceId: service.id,
                contactEmail: contactEmail.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                whatsappNumber: whatsappNumber.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                preferredStart: preferredStart,
                timezone: TimeZone.current.identifier,
                topic: topic.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                notes: notes.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                contactConsent: consent,
                termsAcceptanceId: termsAcceptanceID!,
                termsVersion: termsVersion,
                privacyVersion: privacyVersion,
                refundPolicyVersion: refundPolicyVersion
            )
            submitted = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MyAdvisorConsultationsView: View {
    @State private var requests: [AdvisorConsultationRequest] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if loading && requests.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if requests.isEmpty {
                ContentUnavailableView(
                    "No consultation requests",
                    systemImage: "calendar.badge.clock",
                    description: Text(
                        "Your live advisor consultation requests will appear here."
                    )
                )
                .listRowBackground(Theme.pageBackground)
            } else {
                ForEach(requests) { request in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(
                                request.advisorName ??
                                L10n.string("EduT Advisor")
                            )
                            .font(.subheadline.weight(.semibold))

                            Spacer()

                            Text(
                                L10n.string(
                                    consultationStatusTitle(
                                        request.status
                                    )
                                )
                            )
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accentSoft)
                        }

                        Text(L10n.string(request.serviceTitle))
                            .font(.caption)
                            .foregroundStyle(Theme.ink)

                        Text(
                            L10n.format(
                                "%d min · %@",
                                request.durationMinutes,
                                consultationPrice(
                                    cents: request.quotedPriceCents,
                                    currency: request.currency
                                )
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)

                        if let value = request.preferredStart {
                            Text(
                                L10n.format(
                                    "Preferred: %@",
                                    consultationDate(value)
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle("My consultations")
        .refreshable { await load() }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            requests =
                try await DataService.myAdvisorConsultationRequests()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private func consultationStatusTitle(_ status: String) -> String {
    switch status {
    case "requested": return "Requested"
    case "contacted": return "Contacted"
    case "awaiting_payment": return "Awaiting payment"
    case "paid": return "Paid"
    case "confirmed": return "Confirmed"
    case "completed": return "Completed"
    case "cancelled": return "Cancelled"
    default: return status.capitalized
    }
}

private func consultationPrice(
    cents: Int,
    currency: String
) -> String {
    String(
        format: "%@ %.2f",
        currency,
        Double(cents) / 100.0
    )
}

private func consultationDate(_ value: String) -> String {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: value) else {
        return String(value.prefix(16))
    }

    return DateFormatter.localizedString(
        from: date,
        dateStyle: .medium,
        timeStyle: .short
    )
}

private struct AdvisorTagWrap: View {
    let title: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L10n.string(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)

            Text(values.prefix(8).joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
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
    @StateObject private var call = AdvisorCallController()
    @State private var recordingConsent = false
    @State private var savingConsent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        LiveKitTrackView(track: call.remoteVideoTrack)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                if call.remoteVideoTrack == nil {
                                    VStack(spacing: 10) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(Theme.accentSoft)

                                        Text(
                                            call.connected
                                                ? "Waiting for the other participant"
                                                : "Preparing secure video call"
                                        )
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    }
                                }
                            }

                        LiveKitTrackView(track: call.localVideoTrack)
                            .frame(width: 112, height: 154)
                            .background(Theme.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(
                                        Theme.ink.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                            .padding(12)
                    }
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 12) {
                        callControl(
                            icon: call.microphoneEnabled
                                ? "mic.fill"
                                : "mic.slash.fill",
                            active: call.microphoneEnabled
                        ) {
                            Task { await call.toggleMicrophone() }
                        }

                        callControl(
                            icon: call.cameraEnabled
                                ? "video.fill"
                                : "video.slash.fill",
                            active: call.cameraEnabled
                        ) {
                            Task { await call.toggleCamera() }
                        }

                        callControl(
                            icon: "rectangle.on.rectangle",
                            active: call.screenSharing
                        ) {
                            Task { await call.toggleScreenShare() }
                        }

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 52, height: 52)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                        }
                    }

                    Toggle(
                        "Allow session recording",
                        isOn: $recordingConsent
                    )
                    .tint(Theme.accent)
                    .onChange(of: recordingConsent) {
                        Task { await updateRecordingConsent() }
                    }

                    Text(
                        "Recording requires explicit consent from both the student and advisor. Screen sharing uses the iOS system capture permission."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)

                    if let message = errorMessage ?? call.errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Advisor Video Call")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await connect()
            }
        }
    }

    private func callControl(
        icon: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 52, height: 52)
                .background(
                    active
                        ? Theme.accent
                        : Theme.surfaceRaised
                )
                .foregroundStyle(
                    active
                        ? Theme.onAccent
                        : Theme.ink
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func connect() async {
        do {
            let credentials =
                try await DataService.liveKitCallCredentials(
                    callId: session.id
                )
            try await call.connect(credentials)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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

private final class AdvisorCallController:
    NSObject,
    ObservableObject,
    RoomDelegate,
    @unchecked Sendable
{
    @Published var localVideoTrack: VideoTrack?
    @Published var remoteVideoTrack: VideoTrack?
    @Published var connected = false
    @Published var cameraEnabled = false
    @Published var microphoneEnabled = false
    @Published var screenSharing = false
    @Published var errorMessage: String?

    lazy var room = Room(delegate: self)

    @MainActor
    func connect(
        _ credentials: LiveKitCallCredentials
    ) async throws {
        do {
            try await room.connect(
                url: credentials.url,
                token: credentials.token
            )

            try await room.localParticipant
                .setCamera(enabled: true)
            try await room.localParticipant
                .setMicrophone(enabled: true)

            connected = true
            cameraEnabled = true
            microphoneEnabled = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    @MainActor
    func toggleCamera() async {
        do {
            let next = !cameraEnabled
            try await room.localParticipant
                .setCamera(enabled: next)
            cameraEnabled = next
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func toggleMicrophone() async {
        do {
            let next = !microphoneEnabled
            try await room.localParticipant
                .setMicrophone(enabled: next)
            microphoneEnabled = next
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func toggleScreenShare() async {
        do {
            let next = !screenSharing
            try await room.localParticipant
                .setScreenShare(enabled: next)
            screenSharing = next
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func room(
        _: Room,
        participant _: LocalParticipant,
        didPublishTrack publication: LocalTrackPublication
    ) {
        guard let track = publication.track as? VideoTrack else {
            return
        }

        DispatchQueue.main.async {
            if publication.source == .camera {
                self.localVideoTrack = track
            }
        }
    }

    func room(
        _: Room,
        participant _: RemoteParticipant,
        didSubscribeTrack publication: RemoteTrackPublication
    ) {
        guard let track = publication.track as? VideoTrack else {
            return
        }

        DispatchQueue.main.async {
            self.remoteVideoTrack = track
        }
    }

    func room(
        _: Room,
        participant _: RemoteParticipant,
        didUnsubscribeTrack publication: RemoteTrackPublication
    ) {
        guard publication.track is VideoTrack else {
            return
        }

        DispatchQueue.main.async {
            self.remoteVideoTrack = nil
        }
    }
}

private struct LiveKitTrackView: UIViewRepresentable {
    let track: VideoTrack?

    func makeUIView(context: Context) -> VideoView {
        let view = VideoView()
        view.clipsToBounds = true
        return view
    }

    func updateUIView(
        _ uiView: VideoView,
        context: Context
    ) {
        uiView.track = track
    }
}

struct CommunityView: View {
    @State private var profiles: [CommunityProfile] = []
    @State private var blockedUserIDs: Set<UUID> = []
    @State private var query = ""
    @State private var loading = true
    @State private var chatDestination: CommunityChatDestination?
    @State private var messagingProfileID: UUID?
    @State private var messageError: String?

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

                        Text("Loading the EduT community...")
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
                            HStack(spacing: 10) {
                                NavigationLink(value: profile) {
                                    CommunityRow(profile: profile)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task {
                                        await openConversation(for: profile)
                                    }
                                } label: {
                                    if messagingProfileID == profile.id {
                                        ProgressView()
                                            .tint(Theme.blueSoft)
                                            .frame(width: 40, height: 40)
                                    } else {
                                        Image(systemName: "message.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.blueSoft)
                                            .frame(width: 40, height: 40)
                                            .background(Theme.surface)
                                            .clipShape(Circle())
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(messagingProfileID != nil)
                                .accessibilityLabel(
                                    "Message \(profile.displayName ?? "student")"
                                )
                            }
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
            "Unable to start conversation",
            isPresented: Binding(
                get: { messageError != nil },
                set: { if !$0 { messageError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(messageError ?? "")
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

private struct CommunityChatDestination: Identifiable {
    let id: UUID
    let otherUserId: UUID
    let title: String
}

struct CommunityProfileView: View {
    @Environment(AuthStore.self) private var auth

    let profile: CommunityProfile

    @State private var status = ""
    @State private var openingConversation = false
    @State private var showingReport = false
    @State private var isBlocked = false
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
                status = L10n.string("Student unblocked.")
            } else {
                try await DataService.blockUser(profile.id)
                isBlocked = true
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
