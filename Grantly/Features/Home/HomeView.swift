import SwiftUI

struct HomeView: View {
    @Binding var profile: StudentProfile?
    let openProfile: () -> Void

    @State private var matches: [ScholarshipMatch] = []
    @State private var upcoming: [Scholarship] = []
    @State private var loading = true
    @State private var query = ""
    @State private var unreadNotifications = 0

    private var profileNeedsSetup: Bool {
        guard let profile else { return true }
        let required = [profile.fullName, profile.nationality, profile.intendedMajor, profile.degreeLevel]
        return required.contains {
            ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var firstName: String? {
        profile?.fullName?
            .split(separator: " ")
            .first
            .map(String.init)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                brandHeader
                SearchField(
                    text: $query,
                    prompt: "Search scholarships, countries, universities..."
                )

                homeHero
                quickStats
                categoryRow

                if profileNeedsSetup {
                    ProfileSetupCard(openProfile: openProfile)
                }

                matchesSection

                if let profile, !profileNeedsSetup {
                    ProfileSnapshot(profile: profile)
                }

                deadlinesSection
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .background(Theme.pageBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var brandHeader: some View {
        HStack(spacing: 11) {
            GrantlyMonogram(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Grantly")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text(firstName.map { "Welcome back, \($0)" } ?? "Find your next opportunity")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.54))
            }

            Spacer()

            NavigationLink {
                NotificationInboxView()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Theme.surface)
                        .frame(width: 40, height: 40)

                    Image(systemName: unreadNotifications > 0 ? "bell.fill" : "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .frame(width: 40, height: 40)

                    if unreadNotifications > 0 {
                        Text(unreadNotifications > 9 ? "9+" : "\(unreadNotifications)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Theme.danger)
                            .clipShape(Circle())
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var homeHero: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(seed: "Grantly premium global university campus", height: 222)

            LinearGradient(
                colors: [
                    .clear,
                    Theme.navyDeep.opacity(0.28),
                    Theme.navyDeep.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Theme.blue.opacity(0.20), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR GLOBAL FUTURE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.blueSoft)

                Text("The right scholarship\ncan change everything.")
                    .font(.system(size: 27, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(.white)

                Text("Discover trusted opportunities from universities around the world.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineSpacing(3)
                    .frame(maxWidth: 270, alignment: .leading)
            }
            .padding(18)

            HStack {
                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.blueGradient)
                    .clipShape(Circle())
                    .shadow(color: Theme.blue.opacity(0.28), radius: 10, y: 5)
                    .padding(16)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 222)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.07))
        )
    }

    private var quickStats: some View {
        HStack(spacing: 10) {
            HomeStat(
                value: profileNeedsSetup ? "—" : "\(matches.count)",
                label: "Matches",
                icon: "sparkles"
            )

            HomeStat(
                value: "\(upcoming.count)",
                label: "Deadlines",
                icon: "calendar"
            )

            HomeStat(
                value: "60+",
                label: "Countries",
                icon: "globe"
            )
        }
    }

    private var categoryRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore by study level")
                .font(.headline.bold())
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    HomeCategory(icon: "square.grid.2x2.fill", title: "All", active: true)
                    HomeCategory(icon: "graduationcap", title: "Undergraduate")
                    HomeCategory(icon: "graduationcap.fill", title: "Master's")
                    HomeCategory(icon: "doc.text.magnifyingglass", title: "PhD")
                    HomeCategory(icon: "books.vertical", title: "Research")
                }
            }
        }
    }

    @ViewBuilder
    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profileNeedsSetup ? "Featured scholarships" : "Best matches for you")
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    Text(
                        profileNeedsSetup
                            ? "Trusted opportunities selected by Grantly"
                            : "Based on your academic profile"
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.blueSoft)
            }

            if loading {
                ProgressView()
                    .tint(Theme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
            } else if !matches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(matches.prefix(5)) { match in
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
            } else if !upcoming.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(upcoming.prefix(5)) { scholarship in
                            NavigationLink {
                                ScholarshipDetailView(
                                    scholarship: scholarship,
                                    match: nil
                                )
                            } label: {
                                FeaturedScholarshipCard(scholarship: scholarship)
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
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deadlines to watch")
                            .font(.headline.bold())
                            .foregroundStyle(.white)

                        Text("Verified opportunities closing soon")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                    }

                    Spacer()

                    Label("Verified", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.green)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(upcoming.prefix(6)) { scholarship in
                            NavigationLink {
                                ScholarshipDetailView(
                                    scholarship: scholarship,
                                    match: nil
                                )
                            } label: {
                                UpcomingDeadlineCard(scholarship: scholarship)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func load() async {
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
                    .matches(limit: 8)
                    .matches
            } catch {
                guard let profile else {
                    matches = []
                    return
                }

                matches = Array(
                    MatchingService
                        .rank(profile: profile, scholarships: scholarships)
                        .prefix(8)
                )
            }
        } catch {
            matches = []
            upcoming = []
        }
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
                    .foregroundStyle(Theme.blueSoft)

                Spacer()
            }

            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.50))
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.05))
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
        .foregroundStyle(active ? .white : .white.opacity(0.70))
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(active ? Theme.blue : Theme.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(active ? 0 : 0.06))
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Theme.blue.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(9)
            }

            VStack(alignment: .leading, spacing: 7) {
                FundingBadge(text: match.scholarship.fundingType)

                Text(match.scholarship.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)

                Text(match.scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)

                Label(
                    match.scholarship.country,
                    systemImage: "mappin.and.ellipse"
                )
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.66))
            }
            .padding(12)
        }
        .frame(width: 228)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19)
                .stroke(.white.opacity(0.05))
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
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)

                Text(scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)

                Label(
                    scholarship.country,
                    systemImage: "mappin.and.ellipse"
                )
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.66))
            }
            .padding(12)
        }
        .frame(width: 228)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19)
                .stroke(.white.opacity(0.05))
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
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)

                Text(scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)

                if let deadline = scholarship.deadline {
                    Label(deadline, systemImage: "calendar")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.blueSoft)
                }
            }
            .padding(12)
        }
        .frame(width: 212)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.05))
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
                        .foregroundStyle(Theme.blueSoft)

                    Spacer()

                    Text("1 min")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.50))
                }

                Text("Unlock personalised matches")
                    .font(.headline.bold())
                    .foregroundStyle(.white)

                Text("Add your degree, field, GPA and destination goals so Grantly can rank scholarships around you.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
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
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.blueSoft)
                }

                Text(profile.intendedMajor ?? "Your study plan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))

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
                .foregroundStyle(.white.opacity(0.42))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(match.scholarship.country)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.60))

                HStack {
                    FundingBadge(text: match.scholarship.fundingType)
                    Spacer()
                    Text("\(match.score)%")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.blueSoft)
                }
            }
        }
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.05))
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

            if let rows = try? await DataService.scholarships() {
                matches = MatchingService.rank(
                    profile: profile,
                    scholarships: rows
                )
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
                                            ? Theme.blueSoft
                                            : .white.opacity(0.42)
                                    )
                                    .frame(width: 34, height: 34)
                                    .background(Theme.surfaceRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(notification.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)

                                        Spacer()

                                        if notification.readAt == nil {
                                            Circle()
                                                .fill(Theme.blue)
                                                .frame(width: 7, height: 7)
                                        }
                                    }

                                    Text(notification.body)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.58))
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)

                                    Text(relativeTime(notification.createdAt))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.36))
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
