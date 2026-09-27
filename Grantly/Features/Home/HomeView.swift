import SwiftUI

struct HomeView: View {
    @Binding var profile: StudentProfile?
    let openProfile: () -> Void

    @State private var matches: [ScholarshipMatch] = []
    @State private var upcoming: [Scholarship] = []
    @State private var loading = true
    @State private var query = ""

    private var profileNeedsSetup: Bool {
        guard let profile else { return true }
        let required = [profile.fullName, profile.nationality, profile.intendedMajor, profile.degreeLevel]
        return required.contains {
            ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                brandHeader
                SearchField(text: $query, prompt: "Search scholarships, countries, universities...")
                homeHero
                categoryRow

                HStack {
                    Text("Featured scholarships")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Text("See all")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                }

                if profileNeedsSetup {
                    ProfileSetupCard(openProfile: openProfile)
                } else if loading {
                    ProgressView()
                        .tint(Theme.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                } else if !matches.isEmpty {
                    ForEach(matches.prefix(4)) { match in
                        NavigationLink {
                            ScholarshipDetailView(scholarship: match.scholarship, match: match)
                        } label: {
                            MatchCard(match: match)
                        }
                        .buttonStyle(.plain)
                    }
                } else if !upcoming.isEmpty {
                    ForEach(upcoming.prefix(4)) { scholarship in
                        NavigationLink {
                            ScholarshipDetailView(scholarship: scholarship, match: nil)
                        } label: {
                            FeaturedScholarshipCard(scholarship: scholarship)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let profile, !profileNeedsSetup {
                    ProfileSnapshot(profile: profile)
                }

                if !upcoming.isEmpty {
                    HStack {
                        Text("Deadlines to watch")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Verified")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.green)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(upcoming.prefix(6)) { scholarship in
                                NavigationLink {
                                    ScholarshipDetailView(scholarship: scholarship, match: nil)
                                } label: {
                                    UpcomingDeadlineCard(scholarship: scholarship)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(Theme.pageBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            GrantlyMonogram(size: 38)
            Text("Grantly")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 27))
                .foregroundStyle(Theme.blueSoft)
        }
    }

    private var homeHero: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(seed: "Grantly global campus", height: 180)

            LinearGradient(
                colors: [.clear, Theme.navyDeep.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("Your global")
                Text("future starts here")
            }
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .padding(16)

            HStack {
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Theme.blue)
                    .clipShape(Circle())
                    .padding(14)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.06))
        )
    }

    private var categoryRow: some View {
        HStack(spacing: 10) {
            HomeCategory(icon: "square.grid.2x2.fill", title: "All", active: true)
            HomeCategory(icon: "graduationcap", title: "Undergrad")
            HomeCategory(icon: "graduationcap.fill", title: "Master's")
            HomeCategory(icon: "doc.text.magnifyingglass", title: "PhD")
            HomeCategory(icon: "books.vertical", title: "Research")
        }
    }

    @MainActor
    private func load() async {
        defer { loading = false }

        do {
            let scholarships = try await DataService.scholarships()
            upcoming = scholarships
                .filter { $0.verificationStatus == "verified" && $0.deadline != nil }
                .sorted { ($0.deadline ?? "9999-12-31") < ($1.deadline ?? "9999-12-31") }

            guard let profile, !profileNeedsSetup else {
                matches = []
                return
            }

            matches = Array(
                MatchingService.rank(profile: profile, scholarships: scholarships).prefix(8)
            )
        } catch {
            matches = []
            upcoming = []
        }
    }
}

private struct HomeCategory: View {
    let icon: String
    let title: String
    var active: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(active ? Theme.blue : Theme.surface)
                .foregroundStyle(active ? .white : .white.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 13))

            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(active ? Theme.blueSoft : .white.opacity(0.65))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FeaturedScholarshipCard: View {
    let scholarship: Scholarship

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(seed: scholarship.provider + scholarship.title, height: 150)

            LinearGradient(
                colors: [.clear, Theme.navyDeep.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                FundingBadge(text: scholarship.fundingType)
                Text(scholarship.title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(scholarship.country)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(14)

            HStack {
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.blue)
                    .clipShape(Circle())
                    .padding(12)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct UpcomingDeadlineCard: View {
    let scholarship: Scholarship

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            UniversityPhoto(seed: scholarship.provider, height: 96)

            VStack(alignment: .leading, spacing: 7) {
                Text(scholarship.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(1)

                if let deadline = scholarship.deadline {
                    Label(deadline, systemImage: "calendar")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.blueSoft)
                }
            }
            .padding(12)
        }
        .frame(width: 220)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.06))
        )
    }
}

struct ProfileSetupCard: View {
    let openProfile: () -> Void

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Complete your student profile", systemImage: "graduationcap.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Add your degree, field, GPA and destinations to unlock personalised scholarship matches.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineSpacing(3)

                Button("Build my profile", action: openProfile)
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
                Text("Your profile")
                    .font(.headline.bold())
                    .foregroundStyle(.white)

                HStack(spacing: 0) {
                    SnapshotMetric(label: "GPA", value: profile.gpaValue.map { "\($0)" } ?? "—")
                    SnapshotMetric(label: "IELTS", value: profile.ielts.map { "\($0)" } ?? "—")
                    SnapshotMetric(label: "FROM", value: profile.nationality ?? "—")
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
                .foregroundStyle(.white.opacity(0.46))
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
                        ScholarshipDetailView(scholarship: match.scholarship, match: match)
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
                matches = MatchingService.rank(profile: profile, scholarships: rows)
            }
        }
    }
}
