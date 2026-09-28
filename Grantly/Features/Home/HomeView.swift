import SwiftUI

struct HomeView: View {
    @Binding var profile: StudentProfile?
    let openProfile: () -> Void
    let openExplore: () -> Void
    let openApplications: () -> Void

    @State private var matches: [ScholarshipMatch] = []
    @State private var upcoming: [Scholarship] = []
    @State private var universityApplications: [UniversityApplicationCase] = []
    @State private var scholarshipApplications: [SavedScholarshipItem] = []
    @State private var loading = true
    @State private var unreadNotifications = 0

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

    private var firstName: String? {
        profile?.fullName?
            .split(separator: " ")
            .first
            .map(String.init)
    }

    private var applicationPreviews: [HomeApplicationPreview] {
        let universityRows = universityApplications.map {
            HomeApplicationPreview(
                id: "university-\($0.id.uuidString)",
                title: $0.university.name,
                subtitle: $0.programName.isEmpty
                    ? ($0.degreeLevel ?? "University application")
                    : $0.programName,
                status: $0.applicationStatus,
                deadline: $0.deadline
            )
        }

        let activeStatuses = Set([
            "preparing",
            "applied",
            "submitted",
            "interview",
            "offer",
            "rejected",
            "withdrawn"
        ])

        let scholarshipRows = scholarshipApplications
            .filter {
                activeStatuses.contains(
                    $0.applicationStatus.lowercased()
                )
            }
            .map {
                HomeApplicationPreview(
                    id: "scholarship-\($0.scholarshipId.uuidString)",
                    title: $0.scholarship.title,
                    subtitle: $0.scholarship.provider,
                    status: $0.applicationStatus,
                    deadline:
                        $0.personalDeadline ??
                        $0.applicationDeadline ??
                        $0.scholarship.deadline
                )
            }

        return (universityRows + scholarshipRows)
            .sorted {
                ($0.deadline ?? "9999-12-31") <
                ($1.deadline ?? "9999-12-31")
            }
    }

    private var nextDeadline: HomeApplicationPreview? {
        applicationPreviews.first { preview in
            guard let deadline = preview.deadline else { return false }
            return !deadline.isEmpty
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                greetingHeader
                nextStepCard
                recommendationsSection
                deadlinesSection
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.pageBackground)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private var greetingHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(firstName.map { "Good morning, \($0)" } ?? "Good morning")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Here’s what needs your attention")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            NavigationLink {
                NotificationInboxView()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Theme.surface)
                        .frame(width: 42, height: 42)

                    Image(
                        systemName:
                            unreadNotifications > 0
                            ? "bell.fill"
                            : "bell"
                    )
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.84))
                    .frame(width: 42, height: 42)

                    if unreadNotifications > 0 {
                        Text(
                            unreadNotifications > 9
                                ? "9+"
                                : "\(unreadNotifications)"
                        )
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Theme.orange)
                        .clipShape(Circle())
                        .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var nextStepCard: some View {
        let content = nextStepContent

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("NEXT STEP")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.orangeSoft)

                Spacer()

                Image(systemName: content.icon)
                    .font(.headline)
                    .foregroundStyle(Theme.orangeSoft)
            }

            Text(content.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(content.message)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)

            Button(content.buttonTitle) {
                content.action()
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.orangeGradient)
            .foregroundStyle(Theme.onAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Theme.surfaceRaised, Theme.navy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.ink.opacity(0.06))
        )
    }

    private var nextStepContent: HomeNextStep {
        if profileNeedsSetup {
            return HomeNextStep(
                title: "Complete your profile",
                message:
                    "Add your study level, intended major and background so Grantly can improve your recommendations.",
                buttonTitle: "Complete profile",
                icon: "person.crop.circle.badge.plus",
                action: openProfile
            )
        }

        if applicationPreviews.isEmpty {
            return HomeNextStep(
                title: "Find your first opportunity",
                message:
                    "Explore verified scholarships and save the ones you want to consider.",
                buttonTitle: "Explore scholarships",
                icon: "magnifyingglass",
                action: openExplore
            )
        }

        if let nextDeadline {
            return HomeNextStep(
                title: "Deadline coming up",
                message:
                    "\(nextDeadline.title) · \(displayDeadline(nextDeadline.deadline))",
                buttonTitle: "Open applications",
                icon: "calendar.badge.exclamationmark",
                action: openApplications
            )
        }

        return HomeNextStep(
            title: "Continue your applications",
            message:
                "You have \(applicationPreviews.count) application\(applicationPreviews.count == 1 ? "" : "s") in progress.",
            buttonTitle: "Open applications",
            icon: "checklist",
            action: openApplications
        )
    }

    @ViewBuilder
    private var applicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(
                title: "Your applications",
                subtitle: applicationPreviews.isEmpty
                    ? "Applications you start will appear here"
                    : "\(applicationPreviews.count) application\(applicationPreviews.count == 1 ? "" : "s") to track",
                actionTitle: applicationPreviews.isEmpty ? nil : "View all",
                action: openApplications
            )

            if loading && applicationPreviews.isEmpty {
                ProgressView()
                    .tint(Theme.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if applicationPreviews.isEmpty {
                Button {
                    openExplore()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.orangeSoft)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("No applications yet")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.ink)

                            Text("Find a scholarship or university to get started.")
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
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 9) {
                    ForEach(applicationPreviews.prefix(3)) { preview in
                        Button {
                            openApplications()
                        } label: {
                            HomeApplicationRow(preview: preview)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(
                title: "Recommended for you",
                subtitle: profileNeedsSetup
                    ? "A few trusted opportunities to start with"
                    : "Based on your current profile",
                actionTitle: "Explore more",
                action: openExplore
            )

            if loading {
                ProgressView()
                    .tint(Theme.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if !matches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(matches.prefix(3)) { match in
                            NavigationLink {
                                ScholarshipDetailView(
                                    scholarship: match.scholarship,
                                    match: match
                                )
                            } label: {
                                HomeMatchCard(match: match)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(upcoming.prefix(3)) { scholarship in
                            NavigationLink {
                                ScholarshipDetailView(
                                    scholarship: scholarship,
                                    match: nil
                                )
                            } label: {
                                FeaturedScholarshipCard(
                                    scholarship: scholarship
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deadlinesSection: some View {
        if !allDeadlineItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Upcoming deadlines")
                            .font(.headline.bold())
                            .foregroundStyle(Theme.ink)

                        Text("The next dates worth checking")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()

                    NavigationLink {
                        UpcomingDeadlinesView(items: allDeadlineItems)
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.orangeSoft)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    ForEach(Array(allDeadlineItems.prefix(3))) { item in
                        HomeDeadlineRow(
                            title: item.title,
                            deadline: displayDeadline(item.deadline),
                            status: item.status
                        )

                        if item.id != allDeadlineItems.prefix(3).last?.id {
                            Divider()
                                .overlay(Theme.ink.opacity(0.06))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var allDeadlineItems: [HomeDeadlineItem] {
        let applicationItems = applicationPreviews.compactMap { preview in
            guard let deadline = preview.deadline, !deadline.isEmpty else {
                return nil
            }

            return HomeDeadlineItem(
                id: preview.id,
                title: preview.title,
                status: preview.status,
                deadline: deadline,
                scholarship: nil
            )
        }

        let scholarshipItems = upcoming.compactMap { scholarship in
            guard let deadline = scholarship.deadline, !deadline.isEmpty else {
                return nil
            }

            return HomeDeadlineItem(
                id: "catalog-\(scholarship.id.uuidString)",
                title: scholarship.title,
                status: scholarship.provider,
                deadline: deadline,
                scholarship: scholarship
            )
        }

        return (applicationItems + scholarshipItems).sorted {
            $0.deadline < $1.deadline
        }
    }

    private func displayDeadline(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "Deadline not set"
        }

        return String(value.prefix(10))
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        async let caseRows = DataService.universityApplicationCases()
        async let savedRows = DataService.savedScholarshipItems()

        universityApplications = (try? await caseRows) ?? []
        scholarshipApplications = (try? await savedRows) ?? []

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
                    .matches(limit: 3)
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
                        .prefix(3)
                )
            }
        } catch {
            matches = []
            upcoming = []
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
                    .foregroundStyle(Theme.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
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
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                Text(preview.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text(preview.status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.orangeSoft)

                    if let deadline = preview.deadline {
                        Text("·")
                            .foregroundStyle(Theme.muted)

                        Label(
                            String(deadline.prefix(10)),
                            systemImage: "calendar"
                        )
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.muted)
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
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)

                Text(item.status)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
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
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                Text(status)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
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
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
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
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                UniversityPhoto(
                    seed: match.scholarship.provider + match.scholarship.title,
                    remoteURL: match.scholarship.university?.campusImageUrl,
                    height: 122
                )

                Text("\(match.score)% match")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Theme.orange.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(9)
            }

            VStack(alignment: .leading, spacing: 7) {
                FundingBadge(text: match.scholarship.fundingType)

                Text(match.scholarship.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)

                Text(match.scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)

                Label(
                    match.scholarship.country,
                    systemImage: "mappin.and.ellipse"
                )
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            }
            .padding(12)
        }
        .frame(width: 228)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct FeaturedScholarshipCard: View {
    let scholarship: Scholarship

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            UniversityPhoto(
                seed: scholarship.provider + scholarship.title,
                remoteURL: scholarship.university?.campusImageUrl,
                height: 122
            )

            VStack(alignment: .leading, spacing: 7) {
                FundingBadge(text: scholarship.fundingType)

                Text(scholarship.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)

                Text(scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)

                Label(
                    scholarship.country,
                    systemImage: "mappin.and.ellipse"
                )
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            }
            .padding(12)
        }
        .frame(width: 228)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19)
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
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)

                Text(scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
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
                        .foregroundStyle(Theme.muted)
                }

                Text("Unlock personalised matches")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Text("Add your degree, field, GPA and destination goals so Grantly can rank scholarships around you.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
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
                        .foregroundStyle(Theme.ink)

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.orangeSoft)
                }

                Text(profile.intendedMajor ?? "Your study plan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)

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
                .foregroundStyle(Theme.muted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
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
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)

                Text(match.scholarship.country)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)

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
                                            .foregroundStyle(Theme.ink)

                                        Spacer()

                                        if notification.readAt == nil {
                                            Circle()
                                                .fill(Theme.blue)
                                                .frame(width: 7, height: 7)
                                        }
                                    }

                                    Text(notification.body)
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
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
        guard let date = ISO8601DateFormatter().date(from: value) else {
            return String(value.prefix(10))
        }

        return RelativeDateTimeFormatter()
            .localizedString(
                for: date,
                relativeTo: Date()
            )
    }
}
