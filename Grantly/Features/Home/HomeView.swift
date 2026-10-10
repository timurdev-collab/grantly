import SwiftUI

struct HomeView: View {
    @Binding var profile: StudentProfile?
    let openProfile: () -> Void
    let openExplore: () -> Void
    let openApplications: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34

    @State private var matches: [ScholarshipMatch] = []
    @State private var upcoming: [Scholarship] = []
    @State private var hasLoadError = false
    @State private var loading = true
    @State private var unreadNotifications = 0

    private var firstName: String? {
        profile?.fullName?
            .split(separator: " ")
            .first
            .map(String.init)
    }

    private var profileNeedsSetup: Bool {
        guard let profile else { return true }
        let required = [
            profile.fullName,
            profile.nationality,
            profile.intendedMajor,
            profile.degreeLevel
        ]

        return required.contains {
            ($0 ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HomeVisualStyle.cream
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        editorialIntro
                        searchButton
                        categoryStrip
                        if hasLoadError { refreshError }
                        bestMatchHero
                        personalizedSection
                        closingSoonSection
                        advisorNudge
                    }
                    .frame(
                        width: max(proxy.size.width - 36, 0),
                        alignment: .leading
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 112)
                }
                .frame(width: proxy.size.width)
                .clipped()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(HomeVisualStyle.forest)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
            }
            .frame(width: 32, height: 32)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(HomeVisualStyle.sand)
                    .frame(width: 7, height: 7)
                    .offset(x: 1, y: -1)
            }

            Text(verbatim: "EduT")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(HomeVisualStyle.forest)

            Spacer()

            LanguageFlagMenu()

            NavigationLink {
                NotificationInboxView()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HomeVisualStyle.forest)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.58), lineWidth: 1)
                        )

                    if unreadNotifications > 0 {
                        Text(unreadNotifications > 9 ? "9+" : "\(unreadNotifications)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Theme.danger)
                            .clipShape(Circle())
                            .offset(x: 3, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
        }
    }

    private var editorialIntro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(firstName.map { "Good afternoon, \($0)" } ?? "Good afternoon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HomeVisualStyle.forest)

            Text(L10n.string("Scholarships picked\nfor your next chapter."))
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .foregroundStyle(HomeVisualStyle.ink)
                .tracking(-0.8)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchButton: some View {
        Button(action: openExplore) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HomeVisualStyle.muted)

                Text(L10n.string("Search scholarships, countries, majors"))
                    .font(.subheadline)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 32, height: 32)
                    .background(HomeVisualStyle.forest)
                    .clipShape(Circle())
            }
            .padding(.leading, 15)
            .padding(.trailing, 8)
            .frame(height: 52)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(
                color: Theme.accent.opacity(0.08),
                radius: 16,
                x: 0,
                y: 6
            )
        }
        .buttonStyle(.plain)
    }


    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                HomeFilterPill(title: "For you", selected: true, action: openExplore)
                HomeFilterPill(title: "Applications", selected: false, action: openApplications)
                NavigationLink {
                    AdvisorsView()
                } label: {
                    HomePillLabel(title: "Advisors", selected: false)
                }
                .buttonStyle(CardPressButtonStyle())
                HomeFilterPill(title: "Profile", selected: false, action: openProfile)
            }
            .padding(.vertical, 1)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .frame(maxWidth: .infinity)
    }

    private var refreshError: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to refresh", systemImage: "wifi.exclamationmark")
                .font(.subheadline.weight(.medium))
            Button("Try again") {
                Task { await load() }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .disabled(loading)
        }
        .foregroundStyle(HomeVisualStyle.forest)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(HomeVisualStyle.sage, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var bestMatchHero: some View {
        if loading && matches.isEmpty && upcoming.isEmpty {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(HomeVisualStyle.forest)
                .frame(height: 180)
                .overlay {
                    ProgressView()
                        .tint(Theme.onAccent)
                }
        } else if let match = matches.first {
            NavigationLink {
                ScholarshipDetailView(
                    scholarship: match.scholarship,
                    match: match
                )
            } label: {
                HomeEditorialHero(
                    scholarship: match.scholarship,
                    score: match.score
                )
            }
            .buttonStyle(.plain)
        } else if let scholarship = upcoming.first {
            NavigationLink {
                ScholarshipDetailView(
                    scholarship: scholarship,
                    match: nil
                )
            } label: {
                HomeEditorialHero(
                    scholarship: scholarship,
                    score: nil
                )
            }
            .buttonStyle(.plain)
        } else {
            Button(action: openExplore) {
                HomeEmptyHero()
            }
            .buttonStyle(.plain)
        }
    }

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HomeConceptSectionTitle(
                title: "Explore your way",
                trailing: "See all",
                action: openExplore
            )

            HStack(spacing: 8) {
                HomeExploreShortcut(
                    title: "Top\nmatches",
                    icon: "sparkles",
                    accent: Theme.accent,
                    action: openExplore
                )

                HomeExploreShortcut(
                    title: "Country",
                    icon: "globe",
                    accent: Theme.trustTeal,
                    action: openExplore
                )

                HomeExploreShortcut(
                    title: "Level",
                    icon: "graduationcap",
                    accent: Theme.ink,
                    action: openExplore
                )

                HomeExploreShortcut(
                    title: "Field",
                    icon: "square.grid.2x2",
                    accent: Theme.sand,
                    action: openExplore
                )
            }
        }
    }

    @ViewBuilder
    private var personalizedSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HomeConceptSectionTitle(
                title: "Picked for your goals",
                trailing: profileNeedsSetup ? "Complete profile" : "For you",
                action: profileNeedsSetup ? openProfile : openExplore
            )

            if loading && matches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        HomeRecommendationSkeleton()
                        HomeRecommendationSkeleton()
                    }
                }
                .scrollDisabled(true)
                .accessibilityHidden(true)
            } else if !matches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(matches.prefix(4)) { match in
                            NavigationLink {
                                ScholarshipDetailView(
                                    scholarship: match.scholarship,
                                    match: match
                                )
                            } label: {
                                HomeRecommendationTile(
                                    scholarship: match.scholarship,
                                    score: match.score
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(upcoming.prefix(4)) { scholarship in
                            NavigationLink {
                                ScholarshipDetailView(
                                    scholarship: scholarship,
                                    match: nil
                                )
                            } label: {
                                HomeRecommendationTile(
                                    scholarship: scholarship,
                                    score: nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var closingSoonSection: some View {
        let scholarships = Array(upcoming.prefix(3))

        if !scholarships.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HomeConceptSectionTitle(
                    title: "Closing soon",
                    trailing: "View all",
                    action: openExplore
                )

                VStack(spacing: 7) {
                    ForEach(scholarships) { scholarship in
                        NavigationLink {
                            ScholarshipDetailView(
                                scholarship: scholarship,
                                match: nil
                            )
                        } label: {
                            HomeClosingRow(
                                scholarship: scholarship,
                                urgency: daysUntil(scholarship.deadline)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var advisorNudge: some View {
        NavigationLink {
            AdvisorsView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.onAccent)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(HomeVisualStyle.forest)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("Need help choosing?"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)

                    Text(L10n.string("Ask your advisor about your next move"))
                        .font(.caption2)
                        .foregroundStyle(Theme.onAccent.opacity(0.72))
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(HomeVisualStyle.forest)
                    .frame(width: 31, height: 31)
                    .background(Theme.onAccent)
                    .clipShape(Circle())
            }
            .padding(12)
            .background(HomeVisualStyle.forest)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func daysUntil(_ value: String?) -> Int? {
        guard
            let value,
            let date = AppDateParser.date(from: value)
        else {
            return nil
        }

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents(
            [.day],
            from: start,
            to: end
        ).day
    }

    @MainActor
    private func load() async {
        loading = true
        hasLoadError = false
        defer { loading = false }

        if let notifications = try? await DataService.appNotifications(
            limit: 100
        ) {
            unreadNotifications = notifications.filter {
                $0.readAt == nil
            }.count
        }

        do {
            let scholarships = try await DataService.scholarships()

            upcoming = scholarships
                .filter {
                    $0.verificationStatus == "verified" &&
                    $0.deadline != nil
                }
                .sorted {
                    ($0.deadline ?? "9999-12-31") <
                    ($1.deadline ?? "9999-12-31")
                }

            guard profile != nil, !profileNeedsSetup else {
                matches = []
                return
            }

            do {
                matches = try await ScholarshipSearchService
                    .matches(limit: 4)
                    .matches
            } catch {
                guard let profile else {
                    matches = []
                    return
                }

                matches = Array(
                    MatchingService
                        .rank(
                            profile: profile,
                            scholarships: scholarships
                        )
                        .prefix(4)
                )
            }
        } catch {
            // Keep the last successful content visible during a failed refresh.
            hasLoadError = true
        }
    }
}


private enum HomeVisualStyle {
    static let cream = Color(
        red: 247 / 255,
        green: 243 / 255,
        blue: 232 / 255
    )

    static let forest = Color(
        red: 18 / 255,
        green: 55 / 255,
        blue: 42 / 255
    )

    static let ink = Color(
        red: 26 / 255,
        green: 31 / 255,
        blue: 28 / 255
    )

    static let muted = Color(
        red: 103 / 255,
        green: 111 / 255,
        blue: 104 / 255
    )

    static let sage = Color(
        red: 221 / 255,
        green: 235 / 255,
        blue: 227 / 255
    )

    static let sand = Color(
        red: 215 / 255,
        green: 154 / 255,
        blue: 54 / 255
    )
}

private struct HomeFilterPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HomePillLabel(title: title, selected: selected)
        }
        .buttonStyle(CardPressButtonStyle())
    }
}

private struct HomePillLabel: View {
    let title: String
    let selected: Bool

    var body: some View {
        Text(L10n.string(title))
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? Theme.onAccent : HomeVisualStyle.ink)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(selected ? Theme.accent : Theme.surface, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(selected ? Color.clear : Theme.ink.opacity(0.07), lineWidth: 1)
            }
    }
}

private struct HomeConceptSectionTitle: View {
    let title: String
    let trailing: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(HomeVisualStyle.ink)

            Spacer()

            Button(trailing, action: action)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(HomeVisualStyle.forest)
                .buttonStyle(.plain)
        }
    }
}

private struct HomeEditorialHero: View {
    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat = 318
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 29
    let scholarship: Scholarship
    let score: Int?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(
                seed: scholarship.provider + scholarship.title,
                remoteURL: scholarship.university?.campusImageUrl,
                height: heroHeight
            )
            .frame(maxWidth: .infinity)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.04),
                        Color.black.opacity(0.18),
                        Theme.accent.opacity(0.86)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text(L10n.string("BEST MATCH"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(HomeVisualStyle.forest)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    Spacer()

                    if let score {
                        Text("\(score)%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                Text(scholarship.title)
                    .font(.system(size: titleSize, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .lineSpacing(-1)

                Text("\(scholarship.provider) · \(scholarship.country)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                HStack {
                    Text(scholarship.fundingType)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(HomeVisualStyle.ink)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Theme.onAccent)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(HomeVisualStyle.ink)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(18)
        }
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(
            color: Color.black.opacity(0.10),
            radius: 18,
            x: 0,
            y: 10
        )
    }
}

private struct HomeEmptyHero: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.accent

            Circle()
                .fill(Theme.trustTeal.opacity(0.35))
                .frame(width: 180, height: 180)
                .offset(x: 245, y: -45)

            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.string("START EXPLORING"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(HomeVisualStyle.forest)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Theme.onAccent)
                    .clipShape(Capsule())

                Spacer()

                Text(L10n.string("Your next opportunity\nis waiting."))
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.onAccent)

                Text(L10n.string("Browse verified scholarships from around the world."))
                    .font(.caption)
                    .foregroundStyle(Theme.onAccent.opacity(0.75))
            }
            .padding(16)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct HomeExploreShortcut: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(HomeVisualStyle.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeRecommendationTile: View {
    let scholarship: Scholarship
    let score: Int?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(
                seed: scholarship.provider,
                remoteURL: scholarship.university?.campusImageUrl,
                height: 224
            )
            .frame(width: 270, height: 224)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.16),
                        Theme.accent.opacity(0.80)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let score {
                        Text("\(score)% match")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HomeVisualStyle.forest)
                            .padding(.horizontal, 10)
                            .frame(height: 27)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }

                Spacer()

                Text(scholarship.title)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("\(scholarship.country) · \(scholarship.fundingType)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
            .padding(14)
        }
        .frame(width: 270, height: 224)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 14,
            x: 0,
            y: 8
        )
    }
}

private struct HomeRecommendationSkeleton: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Theme.surfaceRaised)
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .redacted(reason: .placeholder)
    }
}

private struct HomeClosingRow: View {
    let scholarship: Scholarship
    let urgency: Int?

    private var urgencyText: String {
        guard let urgency else {
            return "Soon"
        }

        if urgency <= 0 {
            return "Today"
        }

        return "\(urgency) day\(urgency == 1 ? "" : "s") left"
    }

    private var isUrgent: Bool {
        guard let urgency else { return false }
        return urgency <= 7
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.trustTeal)
                .frame(width: 38, height: 38)
                .background(HomeVisualStyle.sage)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(scholarship.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HomeVisualStyle.ink)
                    .lineLimit(1)

                Text(scholarship.country)
                    .font(.caption2)
                    .foregroundStyle(HomeVisualStyle.muted)
            }

            Spacer(minLength: 6)

            Text(urgencyText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isUrgent ? Theme.danger : HomeVisualStyle.forest)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    (isUrgent ? Theme.danger : HomeVisualStyle.sage)
                        .opacity(isUrgent ? 0.12 : 1)
                )
                .clipShape(Capsule())
        }
        .padding(10)
        .background(Theme.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.ink.opacity(0.04), lineWidth: 1)
        )
    }
}


private struct HomeQuickAction: View {
    let title: String
    let systemImage: String?
    let avatarURL: String?
    let fallback: String?

    var body: some View {
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
                    .frame(width: 66, height: 66)

                Circle()
                    .fill(Theme.pageBackground)
                    .frame(width: 60, height: 60)

                if let avatarURL,
                   let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            quickFallback
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(HomeVisualStyle.ink)
                } else {
                    quickFallback
                }
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(HomeVisualStyle.ink)
                .lineLimit(1)
                .frame(width: 72)
        }
    }

    @ViewBuilder
    private var quickFallback: some View {
        if let fallback, !fallback.isEmpty {
            Text(fallback.uppercased())
                .font(.headline.bold())
                .foregroundStyle(HomeVisualStyle.ink)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(HomeVisualStyle.muted)
        }
    }
}

private struct HomeNextStep {
    let title: String
    let message: String
    let buttonTitle: String
    let icon: String
    let action: () -> Void
}

private struct HomeApplicationPreview: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let status: String
    let deadline: String?
}

private struct HomeSectionHeader: View {
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(HomeVisualStyle.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(HomeVisualStyle.muted)
            }

            Spacer()

            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.orangeSoft)
                    .buttonStyle(.plain)
            }
        }
    }
}

private struct HomeApplicationRow: View {
    let preview: HomeApplicationPreview

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.orangeSoft)
                .frame(width: 40, height: 40)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(preview.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(HomeVisualStyle.ink)
                    .lineLimit(1)

                Text(preview.subtitle)
                    .font(.caption)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text(preview.status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.orangeSoft)

                    if let deadline = preview.deadline {
                        Text("·")
                            .foregroundStyle(HomeVisualStyle.muted)

                        Label(
                            String(deadline.prefix(10)),
                            systemImage: "calendar"
                        )
                        .font(.caption2)
                        .foregroundStyle(HomeVisualStyle.muted)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(HomeVisualStyle.muted)
        }
        .padding(13)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(
            RoundedRectangle(cornerRadius: 17)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct HomeDeadlineItem: Identifiable {
    let id: String
    let title: String
    let status: String
    let deadline: String
    let scholarship: Scholarship?
}

private struct UpcomingDeadlinesView: View {
    let items: [HomeDeadlineItem]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    if let scholarship = item.scholarship {
                        NavigationLink {
                            ScholarshipDetailView(
                                scholarship: scholarship,
                                match: nil
                            )
                        } label: {
                            deadlineCard(item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        deadlineCard(item)
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Upcoming Deadlines")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deadlineCard(_ item: HomeDeadlineItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.orangeSoft)
                .frame(width: 42, height: 42)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(HomeVisualStyle.ink)
                    .lineLimit(2)

                Text(item.status)
                    .font(.caption)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(String(item.deadline.prefix(10)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.orangeSoft)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(
            RoundedRectangle(cornerRadius: 17)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct HomeDeadlineRow: View {
    let title: String
    let deadline: String
    let status: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HomeVisualStyle.ink)
                    .lineLimit(1)

                Text(status)
                    .font(.caption2)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(deadline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.orangeSoft)
        }
        .padding(.vertical, 12)
    }
}

private struct HomeStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.orangeSoft)

                Spacer()
            }

            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(HomeVisualStyle.ink)

            Text(label)
                .font(.caption2)
                .foregroundStyle(HomeVisualStyle.muted)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct HomeCategory: View {
    let icon: String
    let title: String
    var active: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(active ? .white : Theme.ink.opacity(0.70))
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(active ? Theme.blue : Theme.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.ink.opacity(active ? 0 : 0.06))
        )
    }
}

private struct HomeMatchCard: View {
    let match: ScholarshipMatch

    var body: some View {
        HStack(spacing: 12) {
            UniversityLogo(
                university: match.scholarship.university,
                fallbackName: match.scholarship.provider,
                size: 46
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(match.scholarship.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HomeVisualStyle.ink)
                    .lineLimit(2)

                Text(match.scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    FundingBadge(text: match.scholarship.fundingType)

                    Text("\(match.score)% match")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.orangeSoft)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(HomeVisualStyle.muted)
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct FeaturedScholarshipCard: View {
    let scholarship: Scholarship

    var body: some View {
        HStack(spacing: 12) {
            UniversityLogo(
                university: scholarship.university,
                fallbackName: scholarship.provider,
                size: 46
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(scholarship.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HomeVisualStyle.ink)
                    .lineLimit(2)

                Text(scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    FundingBadge(text: scholarship.fundingType)

                    Label(
                        scholarship.country,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption2)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(HomeVisualStyle.muted)
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

struct UpcomingDeadlineCard: View {
    let scholarship: Scholarship

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            UniversityPhoto(
                seed: scholarship.provider,
                remoteURL: scholarship.university?.campusImageUrl,
                height: 92
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(scholarship.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(HomeVisualStyle.ink)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)

                Text(scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineLimit(1)

                if let deadline = scholarship.deadline {
                    Label(deadline, systemImage: "calendar")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.orangeSoft)
                }
            }
            .padding(12)
        }
        .frame(width: 212)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

struct ProfileSetupCard: View {
    let openProfile: () -> Void

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title3)
                        .foregroundStyle(Theme.orangeSoft)

                    Spacer()

                    Text("1 min")
                        .font(.caption2.bold())
                        .foregroundStyle(HomeVisualStyle.muted)
                }

                Text("Unlock personalised matches")
                    .font(.headline.bold())
                    .foregroundStyle(HomeVisualStyle.ink)

                Text("Add your degree, field, GPA and destination goals so EduT can rank scholarships around you.")
                    .font(.subheadline)
                    .foregroundStyle(HomeVisualStyle.muted)
                    .lineSpacing(3)

                Button("Complete my profile", action: openProfile)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

struct ProfileSnapshot: View {
    let profile: StudentProfile

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Academic snapshot")
                        .font(.headline.bold())
                        .foregroundStyle(HomeVisualStyle.ink)

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.orangeSoft)
                }

                Text(profile.intendedMajor ?? "Your study plan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HomeVisualStyle.muted)

                HStack(spacing: 0) {
                    SnapshotMetric(
                        label: "GPA",
                        value: profile.gpaValue.map { "\($0)" } ?? "—"
                    )

                    SnapshotMetric(
                        label: "IELTS",
                        value: profile.ielts.map { "\($0)" } ?? "—"
                    )

                    SnapshotMetric(
                        label: "FROM",
                        value: profile.nationality ?? "—"
                    )
                }
            }
        }
    }
}

struct SnapshotMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(HomeVisualStyle.muted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HomeVisualStyle.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MatchCard: View {
    let match: ScholarshipMatch

    var body: some View {
        HStack(spacing: 12) {
            UniversityPhoto(
                seed: match.scholarship.provider + match.scholarship.title,
                remoteURL: match.scholarship.university?.campusImageUrl,
                height: 88
            )
            .frame(width: 104)
            .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 6) {
                Text(match.scholarship.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(HomeVisualStyle.ink)
                    .lineLimit(2)

                Text(match.scholarship.country)
                    .font(.caption)
                    .foregroundStyle(HomeVisualStyle.muted)

                HStack {
                    FundingBadge(text: match.scholarship.fundingType)
                    Spacer()
                    Text("\(match.score)%")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.orangeSoft)
                }
            }
        }
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

struct MatchListView: View {
    let profile: StudentProfile?
    @State private var matches: [ScholarshipMatch] = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(matches) { match in
                    NavigationLink {
                        ScholarshipDetailView(
                            scholarship: match.scholarship,
                            match: match
                        )
                    } label: {
                        MatchCard(match: match)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Theme.pageBackground)
        .navigationTitle("Your Matches")
        .task {
            guard let profile else { return }

            do {
                matches = try await ScholarshipSearchService
                    .matches(limit: 50)
                    .matches
            } catch {
                if let rows = try? await DataService.scholarships() {
                    matches = MatchingService.rank(
                        profile: profile,
                        scholarships: rows
                    )
                }
            }
        }
    }
}


struct NotificationInboxView: View {
    @State private var notifications: [AppNotification] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loading && notifications.isEmpty {
                ProgressView()
                    .tint(Theme.blue)
            } else if notifications.isEmpty {
                EmptyState(
                    icon: "bell",
                    title: "No notifications yet",
                    text: "Deadline reminders, application tasks and message updates will appear here."
                )
                .padding()
            } else {
                List {
                    ForEach(notifications) { notification in
                        Button {
                            Task {
                                await markRead(notification)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: icon(for: notification.kind))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(
                                        notification.readAt == nil
                                            ? Theme.orangeSoft
                                            : Theme.ink.opacity(0.42)
                                    )
                                    .frame(width: 34, height: 34)
                                    .background(Theme.surfaceRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(notification.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(HomeVisualStyle.ink)

                                        Spacer()

                                        if notification.readAt == nil {
                                            Circle()
                                                .fill(Theme.blue)
                                                .frame(width: 7, height: 7)
                                        }
                                    }

                                    Text(notification.body)
                                        .font(.caption)
                                        .foregroundStyle(HomeVisualStyle.muted)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)

                                    Text(relativeTime(notification.createdAt))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.ink.opacity(0.36))
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .background(Theme.pageBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if notifications.contains(where: { $0.readAt == nil }) {
                Button("Mark all read") {
                    Task { await markAllRead() }
                }
                .font(.caption)
            }
        }
        .task { await load() }
        .alert(
            "Unable to update notifications",
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
        loading = true
        defer { loading = false }

        do {
            notifications = try await DataService.appNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func markRead(_ notification: AppNotification) async {
        guard notification.readAt == nil else { return }

        do {
            try await DataService.markNotificationRead(
                notificationId: notification.id
            )

            try? await DataService.trackProductEvent(
                "notification_open",
                scholarshipId: notification.scholarshipId,
                properties: [
                    "kind": notification.kind
                ]
            )

            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func markAllRead() async {
        do {
            try await DataService.markAllNotificationsRead()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "deadline":
            return "calendar.badge.exclamationmark"
        case "task":
            return "checklist"
        case "message":
            return "message.fill"
        case "new_match":
            return "sparkles"
        case "scholarship_update":
            return "arrow.triangle.2.circlepath"
        default:
            return "bell.fill"
        }
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
