import SwiftUI

struct ScholarshipsView: View {
    @State private var scholarships: [Scholarship] = []
    @State private var query = ""

    @State private var region = "All"
    @State private var degree = "All"
    @State private var funding = "All"
    @State private var source = "All"
    @State private var sort = "Recommended"

    @State private var loading = true
    @State private var errorMessage: String?

    private var regionOptions: [String] {
        ["All"] + Array(Set(scholarships.map(\.region))).sorted()
    }

    private var degreeOptions: [String] {
        ["All"] + Array(Set(scholarships.flatMap(\.degreeLevels))).sorted()
    }

    private var fundingOptions: [String] {
        ["All"] + Array(Set(scholarships.map(\.fundingType))).sorted()
    }

    private var verifiedCount: Int {
        scholarships.filter { $0.verificationStatus == "verified" }.count
    }

    private var countryCount: Int {
        Set(scholarships.map(\.country)).count
    }

    private var filtered: [Scholarship] {
        let rows = scholarships.filter { scholarship in
            let q = query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let queryMatches =
                q.isEmpty ||
                scholarship.title.lowercased().contains(q) ||
                scholarship.provider.lowercased().contains(q) ||
                scholarship.country.lowercased().contains(q) ||
                scholarship.fields.joined(separator: " ").lowercased().contains(q)

            let regionMatches =
                region == "All" ||
                scholarship.region == region

            let degreeMatches =
                degree == "All" ||
                scholarship.degreeLevels.contains(degree)

            let fundingMatches =
                funding == "All" ||
                scholarship.fundingType == funding

            let verification = scholarship.verificationStatus ?? "verified"
            let sourceMatches =
                source == "All" ||
                (source == "Verified" && verification == "verified") ||
                (source == "Curated" && verification == "curated")

            return queryMatches &&
                regionMatches &&
                degreeMatches &&
                fundingMatches &&
                sourceMatches
        }

        switch sort {
        case "Deadline":
            return rows.sorted {
                switch ($0.deadline, $1.deadline) {
                case let (a?, b?):
                    return a < b
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return $0.title < $1.title
                }
            }
        case "Verified first":
            return rows.sorted {
                let left = $0.verificationStatus == "verified"
                let right = $1.verificationStatus == "verified"
                if left != right { return left && !right }
                return $0.title < $1.title
            }
        default:
            return rows.sorted {
                let left = $0.verificationStatus == "verified"
                let right = $1.verificationStatus == "verified"

                if left != right {
                    return left && !right
                }

                let leftHasDeadline = $0.deadline != nil
                let rightHasDeadline = $1.deadline != nil

                if leftHasDeadline != rightHasDeadline {
                    return leftHasDeadline && !rightHasDeadline
                }

                return $0.title < $1.title
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Explore")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(scholarships.count) trusted scholarship opportunities")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Theme.orange)
                        .frame(width: 38, height: 38)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 10)

                filters
                    .padding(.horizontal)

                if loading && scholarships.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.brass)

                        Text("Curating opportunities…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else if filtered.isEmpty {
                    EmptyState(
                        icon: "books.vertical",
                        title: "No opportunities found",
                        text: "Try another search or clear a filter."
                    )
                    .padding(.top, 38)
                } else {
                    HStack {
                        Text("\(filtered.count) scholarships found")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))

                        Spacer()

                        Menu {
                        Spacer()

                        Menu {
                            Button("Recommended") {
                                sort = "Recommended"
                            }
                            Button("Verified first") {
                                sort = "Verified first"
                            }
                            Button("Deadline") {
                                sort = "Deadline"
                            }
                        } label: {
                            Label(sort, systemImage: "arrow.up.arrow.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal)

                    ForEach(filtered) { scholarship in
                        NavigationLink {
                            ScholarshipDetailView(
                                scholarship: scholarship,
                                match: nil
                            )
                        } label: {
                            PremiumScholarshipCard(
                                scholarship: scholarship
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(Theme.pageBackground)
        .searchable(
            text: $query,
            prompt: "Search university, country, field"
        )
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
        .alert(
            "Unable to refresh",
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

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                filterMenu(
                    title: region == "All" ? "Region" : region,
                    icon: "globe.europe.africa"
                ) {
                    ForEach(regionOptions, id: \.self) { value in
                        Button(value) {
                            region = value
                        }
                    }
                }

                filterMenu(
                    title: degree == "All" ? "Degree" : degree,
                    icon: "graduationcap"
                ) {
                    ForEach(degreeOptions, id: \.self) { value in
                        Button(value) {
                            degree = value
                        }
                    }
                }

                filterMenu(
                    title: funding == "All" ? "Funding" : funding,
                    icon: "banknote"
                ) {
                    ForEach(fundingOptions, id: \.self) { value in
                        Button(value) {
                            funding = value
                        }
                    }
                }

                filterMenu(
                    title: source == "All" ? "Trust" : source,
                    icon: "seal"
                ) {
                    Button("All trusted") {
                        source = "All"
                    }
                    Button("Verified") {
                        source = "Verified"
                    }
                    Button("Curated") {
                        source = "Curated"
                    }
                }

                if hasFilters {
                    Button {
                        region = "All"
                        degree = "All"
                        funding = "All"
                        source = "All"
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .frame(width: 36, height: 36)
                            .background(Theme.oxblood.opacity(0.08))
                            .foregroundStyle(Theme.oxblood)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var hasFilters: Bool {
        region != "All" ||
        degree != "All" ||
        funding != "All" ||
        source != "All"
    }

    private func filterMenu<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu(content: content) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(Theme.surfaceRaised)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.07))
                )
        }
    }

    @MainActor
    private func load() async {
        let initial = scholarships.isEmpty

        if initial {
            loading = true
        }

        defer {
            if initial {
                loading = false
            }
        }

        do {
            let refreshed = try await DataService.scholarships()
            scholarships = refreshed
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ExploreHero: View {
    let total: Int
    let verified: Int
    let countries: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionEyebrow(text: "The Grantly index")

                    Text("Scholarships,\nwithout the noise.")
                        .font(Theme.serifTitle(34, weight: .medium))
                        .tracking(-0.7)
                        .foregroundStyle(Theme.parchment)

                    Text("A curated catalogue built around source quality, not volume alone.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineSpacing(3)
                }

                Spacer()

                GrantlyMonogram(size: 48, dark: false)
            }

            Rectangle()
                .fill(Theme.brass.opacity(0.50))
                .frame(height: 1)

            HStack(spacing: 0) {
                ExploreMetric(value: "\(total)", label: "trusted")
                ExploreMetric(value: "\(verified)", label: "verified")
                ExploreMetric(value: "\(countries)", label: "countries")
            }
        }
        .padding(20)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.brass.opacity(0.18))
        )
    }
}

private struct ExploreMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Theme.serifTitle(24, weight: .semibold))
                .foregroundStyle(Theme.parchment)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PremiumScholarshipCard: View {
    let scholarship: Scholarship

    private var verified: Bool {
        scholarship.verificationStatus == "verified"
    }

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    InstitutionTile(
                        name: scholarship.provider,
                        country: scholarship.country
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(scholarship.title)
                            .font(Theme.serifTitle(20, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)

                        Text(scholarship.provider)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    TrustSeal(verified: verified)
                    FundingBadge(text: scholarship.fundingType)
                }

                HStack(spacing: 10) {
                    Label(
                        scholarship.country,
                        systemImage: "mappin"
                    )

                    if let degree = scholarship.degreeLevels.first {
                        Label(
                            degree,
                            systemImage: "graduationcap"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Rectangle()
                    .fill(Theme.navy.opacity(0.07))
                    .frame(height: 1)

                HStack {
                    if let deadline = scholarship.deadline {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT DEADLINE")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.1)
                                .foregroundStyle(.secondary)

                            Text(deadline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.oxblood)
                        }
                    } else {
                        Text("Deadline varies or to be announced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.brass)
                        .frame(width: 30, height: 30)
                        .background(Theme.orange)
                        .clipShape(Circle())
                }
            }
        }
    }
}

private struct InstitutionTile: View {
    let name: String
    let country: String

    private var initials: String {
        let words = name
            .split(separator: " ")
            .filter { !$0.isEmpty }

        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }

        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(initials)
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(Theme.parchment)

            Rectangle()
                .fill(Theme.brass)
                .frame(width: 14, height: 1)
        }
        .frame(width: 46, height: 46)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("\(name), \(country)")
    }
}

// Kept for compatibility with views that already refer to these types.
typealias ScholarshipCard = PremiumScholarshipCard

struct TrustBadge: View {
    let verified: Bool

    var body: some View {
        TrustSeal(verified: verified)
    }
}

struct FilterChip: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Theme.navy.opacity(0.09))
            )
    }
}
