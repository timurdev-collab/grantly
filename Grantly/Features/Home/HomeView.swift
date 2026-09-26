import SwiftUI

struct HomeView: View {
    @Binding var profile: StudentProfile?
    let openProfile: () -> Void

    @State private var matches: [ScholarshipMatch] = []
    @State private var upcoming: [Scholarship] = []
    @State private var loading = true

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
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                brandHeader
                homeHero

                if profileNeedsSetup {
                    ProfileSetupCard(openProfile: openProfile)
                } else if let profile {
                    ProfileSnapshot(profile: profile)
                }

                AcademicSectionHeader(
                    eyebrow: "Personal intelligence",
                    title: profileNeedsSetup
                        ? "Build your profile"
                        : "Your strongest matches",
                    trailing: profileNeedsSetup ? nil : "Top \(min(matches.count, 4))"
                )

                if profileNeedsSetup {
                    Text("Complete your academic profile once. Grantly will use it to rank opportunities around your degree, field and destination goals.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                } else if loading {
                    ProgressView()
                        .tint(Theme.brass)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                } else if matches.isEmpty {
                    EmptyState(
                        icon: "sparkles",
                        title: "No matches yet",
                        text: "Try broadening your profile preferences."
                    )
                } else {
                    ForEach(matches.prefix(4)) { match in
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

                if !upcoming.isEmpty {
                    AcademicSectionHeader(
                        eyebrow: "Calendar",
                        title: "Deadlines to watch",
                        trailing: "Verified only"
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(upcoming.prefix(6)) { scholarship in
                                NavigationLink {
                                    ScholarshipDetailView(
                                        scholarship: scholarship,
                                        match: nil
                                    )
                                } label: {
                                    UpcomingDeadlineCard(
                                        scholarship: scholarship
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .background(Theme.pageBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            GrantlyMonogram(size: 38)

            Text("Grantly")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "bell")
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 36, height: 36)
                .background(Theme.surface)
                .clipShape(Circle())
        }
    }

    private var homeHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                GrantlyMonogram(size: 42, dark: false)

                Spacer()

                Text("YOUR GLOBAL FUTURE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.orange)
            }

            Text(greeting)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))

            Text("Your global future\nstarts here.")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(.white)

            Text("Discover scholarships, track deadlines and move every application forward.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.70))
                .lineSpacing(4)

            HStack(spacing: 8) {
                HomeSignal(
                    icon: "sparkles",
                    label: profileNeedsSetup
                        ? "Profile needed"
                        : "\(matches.count) matches"
                )

                HomeSignal(
                    icon: "calendar",
                    label: "\(upcoming.count) deadlines"
                )
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Theme.surfaceRaised, Theme.navy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.brass.opacity(0.18))
        )
    }

    private var greeting: String {
        let first = profile?.fullName?
            .split(separator: " ")
            .first
            .map(String.init)

        if let first, !first.isEmpty {
            return "Good to see you, \(first)."
        }

        return "Welcome to Grantly."
    }

    @MainActor
    private func load() async {
        defer { loading = false }

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

            guard let profile, !profileNeedsSetup else {
                matches = []
                return
            }

            matches = Array(
                MatchingService
                    .rank(
                        profile: profile,
                        scholarships: scholarships
                    )
                    .prefix(8)
            )
        } catch {
            matches = []
            upcoming = []
        }
    }
}

private struct HomeSignal: View {
    let icon: String
    let label: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08))
            .foregroundStyle(.white.opacity(0.76))
            .clipShape(Capsule())
    }
}

struct UpcomingDeadlineCard: View {
    let scholarship: Scholarship

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                InstitutionMiniMark(name: scholarship.provider)

                Spacer()

                TrustSeal(verified: true)
            }

            Text(scholarship.title)
                .font(Theme.serifTitle(18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(3)

            Text(scholarship.provider)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 2)

            if let deadline = scholarship.deadline {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT DEADLINE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)

                    Text(deadline)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.oxblood)
                }
            }
        }
        .padding(15)
        .frame(width: 230, height: 178, alignment: .leading)
        .background(Theme.paperGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06))
        )
    }
}

private struct InstitutionMiniMark: View {
    let name: String

    var body: some View {
        Text(String(name.prefix(2)).uppercased())
            .font(.caption2.bold())
            .foregroundStyle(Theme.parchment)
            .frame(width: 32, height: 32)
            .background(Theme.navy)
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct ProfileSetupCard: View {
    let openProfile: () -> Void

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(Theme.orange)
                        .frame(width: 38, height: 38)
                        .background(Theme.surfaceRaised)
                        .clipShape(Circle())

                    Spacer()

                    Text("01")
                        .font(Theme.serifTitle(19))
                        .foregroundStyle(Theme.orange)
                }

                Text("Start with your academic profile.")
                    .font(Theme.serifTitle(23))
                    .foregroundStyle(Theme.ink)

                Text("Tell us your degree, field, GPA and destinations. Your matches become useful only when the profile reflects your real goals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        SectionEyebrow(text: "Academic profile")

                        Text(profile.intendedMajor ?? "Choose a major")
                            .font(Theme.serifTitle(22))
                            .foregroundStyle(Theme.ink)
                    }

                    Spacer()

                    Text(profile.degreeLevel ?? "Student")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.surfaceRaised)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

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
                .tracking(1)
                .foregroundStyle(.secondary)

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

    private var category: String {
        if !match.eligible {
            return "Review"
        }

        if match.score >= 80 {
            return "Strong fit"
        }

        return "Possible"
    }

    private var accent: Color {
        if !match.eligible {
            return Theme.oxblood
        }

        if match.score >= 80 {
            return Theme.forest
        }

        return Theme.brass
    }

    var body: some View {
        PremiumCard {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.18), lineWidth: 6)

                    Text("\(match.score)")
                        .font(Theme.serifTitle(18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(match.scholarship.title)
                        .font(Theme.serifTitle(18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)

                    Text(
                        "\(match.scholarship.country) · " +
                        "\(match.scholarship.fundingType)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(category.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(accent)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.orange)
            }
        }
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
            guard let profile else {
                return
            }

            if let rows = try? await DataService.scholarships() {
                matches = MatchingService.rank(
                    profile: profile,
                    scholarships: rows
                )
            }
        }
    }
}
