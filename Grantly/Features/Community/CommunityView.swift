import AVKit
import SwiftUI
import LiveKit
import UIKit
import Combine

struct AdvisorsView: View {
    @Environment(\.colorScheme) private var editorialScheme
    private var actionInk: Color { editorialScheme == .dark ? Theme.editorialCream : Theme.premiumForest }

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? Theme.editorialCream : Theme.premiumInk }
    private var textSecondary: Color { isDark ? Theme.editorialSecondary : Theme.premiumMuted }
    @State private var advisors: [AdvisorDirectoryProfile] = []
    @State private var registration: AdvisorRegistration?
    @State private var loading = true
    @State private var requestingAdvisorID: UUID?
    @State private var errorMessage: String?
    @State private var chatDestination: AdvisorChatDestination?
    @State private var callSession: AdvisorCallSession?
    @State private var search = ""

    private var filteredAdvisors: [AdvisorDirectoryProfile] {
        let needle = search
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !needle.isEmpty else { return advisors }

        return advisors.filter { advisor in
            [
                advisor.displayName,
                advisor.title,
                advisor.organization,
                advisor.shortBio
            ]
            .compactMap { $0 }
            .contains {
                $0.localizedCaseInsensitiveContains(needle)
            } ||
            advisor.specialties.contains {
                $0.localizedCaseInsensitiveContains(needle)
            } ||
            advisor.countries.contains {
                $0.localizedCaseInsensitiveContains(needle)
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string("Find an advisor"))
                            .font(
                                .system(
                                    size: 34,
                                    weight: .regular,
                                    design: .serif
                                )
                            )
                            .tracking(-0.8)
                            .foregroundStyle(textPrimary)

                        Text(
                            L10n.string(
                                "Verified experts for applications, scholarships and study plans"
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                    }

                    Spacer()

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(actionInk)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(textSecondary)

                    TextField(
                        L10n.string("Search expertise or country"),
                        text: $search
                    )
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(.ultraThinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                    .stroke(
                        Color.white.opacity(0.68),
                        lineWidth: 1
                    )
                )

                if let registration {
                    currentRegistrationCard(registration)
                }

                NavigationLink {
                    MyAdvisorConsultationsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(actionInk)
                            .frame(width: 40, height: 40)
                            .background(Theme.premiumSageSoft)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 13,
                                    style: .continuous
                                )
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.string("My consultations"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(textPrimary)

                            Text(
                                L10n.string(
                                    "Track upcoming advisor sessions"
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(textSecondary)
                    }
                    .padding(12)
                    .background(Theme.premiumIvoryRaised)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                        .stroke(
                            Theme.premiumInk.opacity(0.05),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)

                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.string("Experts for your goals"))
                        .font(
                            .system(
                                size: 20,
                                weight: .regular,
                                design: .serif
                            )
                        )
                        .foregroundStyle(textPrimary)

                    Spacer()

                    if !advisors.isEmpty {
                        Text(
                            L10n.format(
                                "%d available",
                                filteredAdvisors.count
                            )
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(actionInk)
                    }
                }

                if loading && advisors.isEmpty {
                    ProgressView()
                        .tint(Theme.premiumForest)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if filteredAdvisors.isEmpty {
                    EmptyState(
                        icon: "person.2",
                        title: "No advisors found",
                        text: "Try a different expertise or country."
                    )
                    .padding(.vertical, 30)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        alignment: .center,
                        spacing: 10
                    ) {
                        ForEach(filteredAdvisors) { advisor in
                            advisorGridCard(advisor)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .background(isDark ? Theme.editorialBackground : Theme.premiumIvoryRaised)
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
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        registration.status == "active"
                            ? L10n.string("Your advisor")
                            : L10n.string("Advisor request pending")
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(actionInk)

                    Text(registration.advisorName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(textPrimary)

                    if let title = registration.advisorTitle,
                       !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                    }
                }

                Spacer()

                Image(
                    systemName:
                        registration.status == "active"
                            ? "checkmark.seal.fill"
                            : "clock.fill"
                )
                .foregroundStyle(actionInk)
            }

            if registration.status == "active" {
                HStack(spacing: 9) {
                    Button {
                        Task {
                            await openConversation(registration)
                        }
                    } label: {
                        Label(
                            L10n.string("Message"),
                            systemImage: "bubble.left.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Theme.premiumForest)
                        .foregroundStyle(Theme.premiumIvory)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 13,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await prepareVideoCall(registration)
                        }
                    } label: {
                        Label(
                            L10n.string("Video"),
                            systemImage: "video.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Theme.premiumSageSoft)
                        .foregroundStyle(actionInk)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 13,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Theme.premiumSageSoft)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func advisorGridCard(_ advisor: AdvisorDirectoryProfile) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 5) {
                ZStack {
                    Circle().fill(isDark ? Theme.editorialCard : Theme.premiumSageSoft)
                    if let value = advisor.avatarUrl,
                       let url = URL(string: value) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().scaledToFit()
                                    .foregroundStyle(actionInk)
                                    .padding(18)
                            }
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit()
                            .foregroundStyle(actionInk)
                            .padding(18)
                    }
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())
                .overlay(Circle().stroke((isDark ? Theme.editorialCream : .white).opacity(0.45), lineWidth: 1))

                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 5) {
                    Label(L10n.string("Verified"), systemImage: "checkmark.seal.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(actionInk)
                    if let years = advisor.yearsExperience {
                        Text("\(years)+ years")
                            .font(.system(size: 10))
                            .foregroundStyle(textSecondary)
                    }
                }
            }

            NavigationLink {
                AdvisorDetailView(advisor: advisor)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(advisor.displayName ?? "EduT Advisor")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(textPrimary)
                        .lineLimit(2)
                    Text(advisor.title?.nonEmpty ?? "Study abroad advisor")
                        .font(.system(size: 11))
                        .foregroundStyle(textSecondary)
                        .lineLimit(2)
                    Text(advisor.organization?.nonEmpty ?? "Education specialist")
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 67, alignment: .topLeading)
            }
            .buttonStyle(.plain)

            if let specialty = advisor.specialties.first {
                Text(specialty)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle((isDark ? Theme.editorialCream : Theme.premiumForest))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(isDark ? Theme.editorialCard : Theme.premiumSageSoft, in: Capsule())
            }

            NavigationLink {
                AdvisorConsultationBookingView(advisor: advisor)
            } label: {
                Label(L10n.string("Book consultation"), systemImage: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.premiumInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Theme.editorialCream, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isDark ? Theme.editorialCard : Theme.premiumIvoryRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(isDark ? Theme.editorialCream.opacity(0.13) : Theme.premiumInk.opacity(0.06), lineWidth: 1))
    }

    private func advisorListCard(
        _ advisor: AdvisorDirectoryProfile
    ) -> some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Theme.premiumSage)

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
                                .font(.system(size: 20))
                                .foregroundStyle(actionInk)
                        }
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(actionInk)
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        Color.white.opacity(0.8),
                        lineWidth: 1
                    )
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(
                        advisor.displayName ??
                        L10n.string("EduT Advisor")
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)

                    if advisor.isFeatured {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.premiumBrass)
                    }
                }

                if let title = advisor.title?.nonEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    ForEach(
                        Array(advisor.specialties.prefix(2)),
                        id: \.self
                    ) { value in
                        Text(value)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(textSecondary)
                            .padding(.horizontal, 8)
                            .frame(height: 23)
                            .background(Theme.premiumSageSoft)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(actionInk)
        }
        .padding(12)
        .background(Theme.premiumIvoryRaised)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Theme.premiumInk.opacity(0.05),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(0.035),
            radius: 12,
            x: 0,
            y: 6
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
            VStack(alignment: .leading, spacing: 18) {
                header
                introductionVideo
                aboutSection
                pricingSection
                linksSection

                HStack(spacing: 10) {
                    Button {
                        Task { await openDirectConversation() }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "bubble.left.fill")
                            Text(
                                openingChat
                                    ? L10n.string("Opening chat…")
                                    : L10n.string("Message")
                            )
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.premiumSageSoft)
                        .foregroundStyle(Theme.premiumForest)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 17,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(openingChat)

                    NavigationLink {
                        AdvisorConsultationBookingView(advisor: advisor)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "calendar")
                            Text(L10n.string("Book a session"))
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.premiumForest)
                        .foregroundStyle(Theme.premiumIvory)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 17,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.premiumIvoryRaised)
        .preferredColorScheme(.light)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.premiumSage)

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
                                    .foregroundStyle(Theme.premiumForest)
                            }
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.premiumForest)
                    }
                }
                .frame(width: 98, height: 98)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            Color.white.opacity(0.82),
                            lineWidth: 2
                        )
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(
                            advisor.displayName ??
                            L10n.string("EduT Advisor")
                        )
                        .font(
                            .system(
                                size: 25,
                                weight: .regular,
                                design: .serif
                            )
                        )
                        .foregroundStyle(Theme.premiumInk)
                        .lineLimit(2)

                        if advisor.isFeatured {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.premiumForest)
                        }
                    }

                    if let title = advisor.title?.nonEmpty {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.premiumInk)
                    }

                    if let organization = advisor.organization?.nonEmpty {
                        Text(organization)
                            .font(.caption)
                            .foregroundStyle(Theme.premiumMuted)
                    }

                    if let years = advisor.yearsExperience {
                        Label(
                            L10n.format(
                                "%d years experience",
                                years
                            ),
                            systemImage: "briefcase.fill"
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.premiumForest)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
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

            if let shortBio = advisor.shortBio?.nonEmpty {
                Text(shortBio)
                    .font(.subheadline)
                    .foregroundStyle(Theme.premiumMuted)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(Theme.premiumIvoryRaised)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                Theme.premiumInk.opacity(0.05),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(0.035),
            radius: 14,
            x: 0,
            y: 7
        )
    }

    private func advisorStat(
        value: String,
        label: String
    ) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.premiumForest)

            Text(L10n.string(label))
                .font(.caption2)
                .foregroundStyle(Theme.premiumMuted)
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
                    .foregroundStyle(Theme.premiumInk)

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
                                    .foregroundStyle(Theme.premiumInk)

                                Text("Opens the advisor's video")
                                    .font(.caption)
                                    .foregroundStyle(Theme.premiumMuted)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(Theme.premiumMuted)
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
                .foregroundStyle(Theme.premiumInk)

            if let shortBio = advisor.shortBio?.nonEmpty {
                Text(shortBio)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.premiumInk)
            }

            if let bio = advisor.bio?.nonEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(Theme.premiumMuted)
                    .lineSpacing(3)
            }

            if let approach = advisor.mentoringApproach?.nonEmpty {
                Divider()

                Text("How I help")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.premiumInk)

                Text(approach)
                    .font(.subheadline)
                    .foregroundStyle(Theme.premiumMuted)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(Theme.premiumIvoryRaised)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Consultation plans")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.premiumInk)

                    Text("Simple pricing · no hidden fees")
                        .font(.caption2)
                        .foregroundStyle(Theme.premiumMuted)
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
                    .foregroundStyle(Theme.premiumMuted)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(advisorServices) { service in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.string(service.title))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.premiumInk)
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
                                .foregroundStyle(Theme.premiumMuted)
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
                                    .foregroundStyle(Theme.premiumMuted)
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
                    .foregroundStyle(Theme.premiumInk)

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
                    .foregroundStyle(Theme.premiumInk)
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
                    .foregroundStyle(Theme.premiumInk)

                    Text(
                        "Please review and accept the booking terms. This keeps pricing, privacy and cancellation rules clear before you select a service."
                    )
                    .font(.subheadline)
                    .foregroundStyle(Theme.premiumMuted)
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
                    .foregroundStyle(Theme.premiumInk)

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
                        .foregroundStyle(Theme.premiumInk)
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
                .foregroundStyle(Theme.premiumMuted)
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
                    .foregroundStyle(Theme.premiumInk)

                Spacer()

                Text("Read")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.premiumMuted)
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
                .foregroundStyle(Theme.premiumMuted)
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
                        .foregroundStyle(Theme.premiumInk)

                    Text(
                        "Choose the support that fits you best. Introductory pricing is shown clearly before you send a request."
                    )
                    .font(.subheadline)
                    .foregroundStyle(Theme.premiumMuted)
                    .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose a plan")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.premiumInk)

                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    } else if services.isEmpty {
                        Text("No consultation services are available right now.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.premiumMuted)
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
                        .foregroundStyle(Theme.premiumInk)

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
                    .foregroundStyle(Theme.premiumMuted)
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferred time")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.premiumInk)

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
                    .foregroundStyle(Theme.premiumMuted)
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    Text("What do you need help with?")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.premiumInk)

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
                            .foregroundStyle(Theme.premiumInk)

                        HStack {
                            Text(service.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.premiumInk)

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
                        .foregroundStyle(Theme.premiumMuted)

                        Text(
                            "Your accepted Terms, Privacy Policy and Cancellation & Refund Policy apply to this request."
                        )
                        .font(.caption2)
                        .foregroundStyle(Theme.premiumMuted)
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
                    .foregroundStyle(Theme.premiumInk)
                }
                .tint(Theme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        "Payment is arranged before direct contact is unlocked.",
                        systemImage: "creditcard"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.premiumInk)

                    Text(
                        "This request does not charge you. Payment instructions will be provided separately, and the advisor will receive your contact details only after payment is recorded."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.premiumMuted)
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
                .foregroundStyle(Theme.premiumInk)

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
                .foregroundStyle(Theme.premiumInk)
            }

            Text(
                "Your request has been sent. EduT will coordinate payment first; WhatsApp and email contact details stay hidden from the advisor until payment is recorded."
            )
            .font(.subheadline)
            .foregroundStyle(Theme.premiumMuted)
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
                        .foregroundStyle(Theme.premiumInk)
                        .fixedSize(horizontal: false, vertical: true)

                    if service.serviceType == "six_month_package" {
                        Text("Weekly check-ins for 6 months")
                            .font(.caption)
                            .foregroundStyle(Theme.premiumMuted)
                    } else {
                        Text(
                            L10n.format(
                                "%d min live session",
                                service.durationMinutes
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.premiumMuted)
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
                    .foregroundStyle(Theme.premiumMuted)
                    .strikethrough()
                }

                Text(priceText(service))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.premiumInk)
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
                            .foregroundStyle(Theme.premiumInk)

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
                        .foregroundStyle(Theme.premiumMuted)

                        if let value = request.preferredStart {
                            Text(
                                L10n.format(
                                    "Preferred: %@",
                                    consultationDate(value)
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(Theme.premiumMuted)
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
                .foregroundStyle(Theme.premiumMuted)

            Text(values.prefix(8).joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.premiumInk)
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
                                        .foregroundStyle(Theme.premiumInk)
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
                    .foregroundStyle(Theme.premiumMuted)

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
    @Environment(AuthStore.self) private var auth

    @State private var profiles: [CommunityProfile] = []
    @State private var blockedUserIDs: Set<UUID> = []
    @State private var query = ""
    @State private var loading = false
    @State private var chatDestination: CommunityChatDestination?
    @State private var messagingProfileID: UUID?
    @State private var addingFriendProfileID: UUID?
    @State private var friendRequestSentIDs: Set<UUID> = []
    @State private var messageError: String?

    private var visibleResults: [CommunityProfile] {
        profiles.filter { !blockedUserIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 10) {
                    Image(
                        systemName:
                            "person.crop.circle.badge.magnifyingglass"
                    )
                    .foregroundStyle(Theme.premiumMuted)

                    TextField(
                        L10n.string("EduT ID or student name"),
                        text: $query
                    )
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .foregroundStyle(Theme.premiumInk)

                    if !query.isEmpty {
                        Button {
                            query = ""
                            profiles = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.premiumMuted)
                        }
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.ink.opacity(0.05))
                )

                Text(
                    L10n.string("Search by the full EduT ID, ID suffix, or student name.")
                )
                .font(.caption2)
                .foregroundStyle(Theme.premiumMuted)

                communityHero

                if loading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.blue)

                        Text(L10n.string("Searching..."))
                            .font(.caption)
                            .foregroundStyle(Theme.premiumMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 42)
                } else if query
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    VStack(spacing: 14) {
                        Image(
                            systemName:
                                "person.crop.circle.badge.magnifyingglass"
                        )
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.blueSoft)
                        .frame(width: 62, height: 62)
                        .background(Theme.surface)
                        .clipShape(Circle())

                        Text(L10n.string("Find a student"))
                            .font(.headline.bold())
                            .foregroundStyle(Theme.premiumInk)

                        Text(
                            L10n.string("Enter their EduT ID or name. ") +
                            "Students are not listed publicly by default."
                        )
                        .font(.subheadline)
                        .foregroundStyle(Theme.premiumMuted)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                } else if visibleResults.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.3")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Theme.blueSoft)
                            .frame(width: 62, height: 62)
                            .background(Theme.surface)
                            .clipShape(Circle())

                        Text("No students found")
                            .font(.headline.bold())
                            .foregroundStyle(Theme.premiumInk)

                        Text(L10n.string("Check the EduT ID or try the student's name."))
                            .font(.subheadline)
                            .foregroundStyle(Theme.premiumMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.string("Search results"))
                                .font(.headline.bold())
                                .foregroundStyle(Theme.premiumInk)

                            Text(
                                "\(visibleResults.count) matching profile" +
                                (visibleResults.count == 1 ? "" : "s")
                            )
                            .font(.caption)
                            .foregroundStyle(Theme.premiumMuted)
                        }

                        Spacer()

                        Image(systemName: "globe.americas.fill")
                            .foregroundStyle(Theme.blueSoft)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(visibleResults) { profile in
                            HStack(spacing: 10) {
                                NavigationLink(value: profile) {
                                    CommunityRow(profile: profile)
                                }
                                .buttonStyle(.plain)

                                if profile.id != auth.userId {
                                    Button {
                                        Task {
                                            await addFriend(from: profile)
                                        }
                                    } label: {
                                        if addingFriendProfileID == profile.id {
                                            ProgressView()
                                                .frame(width: 40, height: 40)
                                        } else {
                                            Image(
                                                systemName:
                                                    friendRequestSentIDs.contains(
                                                        profile.id
                                                    )
                                                    ? "checkmark.circle.fill"
                                                    : "person.badge.plus"
                                            )
                                                .font(
                                                    .system(
                                                        size: 15,
                                                        weight: .semibold
                                                    )
                                                )
                                                .foregroundStyle(Theme.blueSoft)
                                                .frame(width: 40, height: 40)
                                                .background(Theme.surface)
                                                .clipShape(Circle())
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(
                                        addingFriendProfileID != nil ||
                                        friendRequestSentIDs.contains(profile.id)
                                    )
                                    .accessibilityLabel(
                                        L10n.string("Add ") +
                                        (profile.displayName ?? "student") +
                                        " as friend"
                                    )
                                }
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
            L10n.string("Unable to start conversation"),
            isPresented: Binding(
                get: { messageError != nil },
                set: { if !$0 { messageError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(messageError ?? "")
        }
        .task {
            await loadBlockedUsers()
        }
        .task(id: query) {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await runSearch()
        }
        .refreshable {
            await loadBlockedUsers()
            await runSearch()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Community")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.premiumInk)

                Text(L10n.string("Find students by EduT ID or name"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.premiumMuted)
            }

            Spacer()

            HStack(spacing: 8) {
                NavigationLink {
                    CommunityFriendsView()
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.blueSoft)
                        .frame(width: 40, height: 40)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel(L10n.string("Friends"))

                NavigationLink {
                    CommunityFriendRequestsView()
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.blueSoft)
                        .frame(width: 40, height: 40)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel(L10n.string("Friend requests"))

                NavigationLink {
                    MessagesView()
                } label: {
                    Image(
                        systemName:
                            "bubble.left.and.bubble.right.fill"
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.blueSoft)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Messages")
            }
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

                Text(L10n.string("Connect by ID."))
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Theme.premiumInk)

                Text(
                    L10n.string("Share your EduT ID with people you want to connect ") +
                    "with. Your academic details stay private."
                )
                .font(.caption)
                .foregroundStyle(Theme.premiumMuted)
                .lineSpacing(3)
                .frame(maxWidth: 290, alignment: .leading)

                HStack(spacing: 14) {
                    Label("Private profile", systemImage: "lock.fill")
                    Label("Report & block", systemImage: "hand.raised.fill")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.premiumMuted)
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
            profiles = try await DataService.searchCommunityProfiles(
                query: trimmed
            )
        } catch {
            messageError = error.localizedDescription
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
                    .foregroundStyle(Theme.premiumInk)

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
                .foregroundStyle(Theme.premiumMuted)
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
                            .foregroundStyle(Theme.premiumInk)
                    }
                }
            } else {
                Text(initials)
                    .font(.system(size: size * 0.27, weight: .bold))
                    .foregroundStyle(Theme.premiumInk)
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
                    L10n.string("No friend requests"),
                    systemImage: "person.badge.plus",
                    description: Text(
                        L10n.string("This page is only for requests other students sent to you. To send a request, search a student in Community and tap the + person button.")
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
        .navigationTitle(L10n.string("Friend Requests"))
        .refreshable { await load() }
        .task { await load() }
        .alert(
            L10n.string("Unable to update request"),
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
                    L10n.string("No friends yet"),
                    systemImage: "person.2",
                    description: Text(
                        L10n.string("Search by EduT ID and send a friend request.")
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
                            .foregroundStyle(Theme.premiumMuted)
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
                            Button(L10n.string("Remove friend"), role: .destructive) {
                                Task { await remove(friend) }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.string("Friends"))
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
            L10n.string("Community error"),
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
                            .foregroundStyle(Theme.premiumMuted)
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
                        .foregroundStyle(Theme.premiumMuted)
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
                .foregroundStyle(Theme.premiumInk)

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
            .foregroundStyle(Theme.premiumMuted)

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
                    Text(L10n.string("This student is blocked."))
                        .font(.caption)
                        .foregroundStyle(Theme.premiumMuted)
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
                    .foregroundStyle(Theme.premiumMuted)
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

            Button(L10n.string("Remove friend"), role: .destructive) {
                Task { await removeFriend() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(changingFriendship)

        case "outgoing":
            Label(L10n.string("Friend request sent"), systemImage: "clock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.premiumMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(L10n.string("Cancel request")) {
                Task { await cancelFriendRequest() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(changingFriendship)

        case "incoming":
            Button {
                Task { await sendFriendRequest() }
            } label: {
                Label(L10n.string("Accept friend request"), systemImage: "person.badge.plus")
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
                    .foregroundStyle(Theme.premiumInk)

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
