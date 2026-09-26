import SwiftUI

struct HomeView: View {
    @Binding var profile: StudentProfile?
    let openProfile: () -> Void

    @State private var matches: [ScholarshipMatch] = []
    @State private var upcoming: [Scholarship] = []
    @State private var loading = true

    private var profileNeedsSetup: Bool {
        guard let profile else { return true }

        let requiredText = [
            profile.fullName,
            profile.nationality,
            profile.intendedMajor,
            profile.degreeLevel
        ]

        return requiredText.contains {
            ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionEyebrow(text: "Your journey")
                Text("Welcome\(profile?.fullName.map { ", \($0)" } ?? "")")
                    .font(.largeTitle.bold())

                if profileNeedsSetup {
                    ProfileSetupCard(openProfile: openProfile)
                } else if let profile {
                    ProfileSnapshot(profile: profile)
                }

                HStack {
                    Text(profileNeedsSetup ? "Explore opportunities" : "Best matches")
                        .font(.title2.bold())
                    Spacer()
                    NavigationLink("See all") { MatchListView(profile: profile) }
                        .font(.subheadline.weight(.semibold))
                }

                if profileNeedsSetup {
                    Text("Complete your profile to unlock personalized eligibility matching.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if matches.isEmpty {
                    EmptyState(
                        icon: "sparkles",
                        title: "No matches yet",
                        text: "Check the scholarship directory or update your profile."
                    )
                } else {
                    ForEach(matches.prefix(4)) { match in
                        NavigationLink {
                            ScholarshipDetailView(scholarship: match.scholarship, match: match)
                        } label: {
                            MatchCard(match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !upcoming.isEmpty {
                    HStack {
                        Text("Deadlines coming up")
                            .font(.title2.bold())

                        Spacer()

                        Text("Verified")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.green)
                    }
                    .padding(.top, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(upcoming.prefix(5)) { scholarship in
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
                    .contentMargins(.horizontal, 0)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Grantly")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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

struct UpcomingDeadlineCard: View {
    let scholarship: Scholarship

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.violet)

                Spacer()

                TrustBadge(verified: true)
            }

            Text(scholarship.title)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.ink)
                .lineLimit(2)

            Text(scholarship.provider)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let deadline = scholarship.deadline {
                Text(deadline)
                    .font(.headline)
                    .foregroundStyle(Theme.violet)
            }
        }
        .padding(14)
        .frame(width: 230, minHeight: 150, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.04))
        )
    }
}

struct ProfileSetupCard: View {
    let openProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Complete your profile", systemImage: "person.crop.circle.badge.plus")
                .font(.headline)

            Text("Tell Grantly your study goals and academic details so your scholarship matches are based on your profile.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Set up profile", action: openProfile)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct ProfileSnapshot: View {
    let profile: StudentProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(profile.intendedMajor ?? "Choose a major", systemImage: "wrench.and.screwdriver")
                Spacer()
                Text(profile.degreeLevel ?? "Student")
                    .font(.caption.bold())
                    .padding(7)
                    .background(Theme.soft)
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                SnapshotMetric(label: "GPA", value: profile.gpaValue.map { "\($0)" } ?? "—")
                SnapshotMetric(label: "IELTS", value: profile.ielts.map { "\($0)" } ?? "—")
                SnapshotMetric(label: "From", value: profile.nationality ?? "—")
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct SnapshotMetric: View {
    let label: String, value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MatchCard: View {
    let match: ScholarshipMatch

    private var category: String {
        if !match.eligible {
            return "Review eligibility"
        } else if match.score >= 80 {
            return "Strong match"
        } else {
            return "Possible"
        }
    }

    private var categoryColor: Color {
        if !match.eligible {
            return .red
        } else if match.score >= 80 {
            return Theme.green
        } else {
            return .orange
        }
    }

    private var categoryBackground: Color {
        if !match.eligible {
            return Color.red.opacity(0.10)
        } else if match.score >= 80 {
            return Theme.mint
        } else {
            return Color.orange.opacity(0.10)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 14) {

                ZStack {
                    Circle()
                        .fill(categoryBackground)

                    Text("\(match.score)%")
                        .font(.caption.bold())
                        .foregroundStyle(categoryColor)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 5) {
                    Text(match.scholarship.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text("\(match.scholarship.country) · \(match.scholarship.fundingType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Text(category)
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(categoryBackground)
                    .foregroundStyle(categoryColor)
                    .clipShape(Capsule())

                Spacer()

                if let firstReason = match.reasons.first {
                    Text(firstReason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MatchListView: View {
    let profile: StudentProfile?
    @State private var matches: [ScholarshipMatch] = []

    var body: some View {
        List(matches) { match in
            NavigationLink {
                ScholarshipDetailView(scholarship: match.scholarship, match: match)
            } label: {
                MatchCard(match: match).listRowInsets(.init())
            }
        }
        .listStyle(.plain)
        .navigationTitle("Your matches")
        .task {
            guard let profile else { return }
            if let rows = try? await DataService.scholarships() {
                matches = MatchingService.rank(profile: profile, scholarships: rows)
            }
        }
    }
}
