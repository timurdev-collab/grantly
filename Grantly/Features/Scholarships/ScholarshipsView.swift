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

    private var filtered: [Scholarship] {
        let rows = scholarships.filter { scholarship in
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let queryMatches =
                q.isEmpty ||
                scholarship.title.lowercased().contains(q) ||
                scholarship.provider.lowercased().contains(q) ||
                scholarship.country.lowercased().contains(q) ||
                scholarship.fields.joined(separator: " ").lowercased().contains(q)

            let regionMatches = region == "All" || scholarship.region == region
            let degreeMatches = degree == "All" || scholarship.degreeLevels.contains(degree)
            let fundingMatches = funding == "All" || scholarship.fundingType == funding

            let verification = scholarship.verificationStatus ?? "verified"
            let sourceMatches =
                source == "All" ||
                (source == "Verified" && verification == "verified") ||
                (source == "Curated" && verification == "curated")

            return queryMatches && regionMatches && degreeMatches && fundingMatches && sourceMatches
        }

        switch sort {
        case "Deadline":
            return rows.sorted {
                switch ($0.deadline, $1.deadline) {
                case let (a?, b?): return a < b
                case (_?, nil): return true
                case (nil, _?): return false
                default: return $0.title < $1.title
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
                if left != right { return left && !right }
                return $0.title < $1.title
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                HStack {
                    Text("Explore")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                SearchField(text: $query, prompt: "Search scholarships...")
                    .padding(.horizontal)

                filters
                    .padding(.horizontal)

                HStack {
                    Text("\(filtered.count) scholarships found")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))

                    Spacer()

                    Menu {
                        Button("Recommended") { sort = "Recommended" }
                        Button("Verified first") { sort = "Verified first" }
                        Button("Deadline") { sort = "Deadline" }
                    } label: {
                        HStack(spacing: 5) {
                            Text("Sort")
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 2)

                if loading && scholarships.isEmpty {
                    ProgressView()
                        .tint(Theme.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if filtered.isEmpty {
                    EmptyState(
                        icon: "magnifyingglass",
                        title: "No scholarships found",
                        text: "Try another search or clear a filter."
                    )
                    .padding(.top, 36)
                } else {
                    ForEach(filtered) { scholarship in
                        NavigationLink {
                            ScholarshipDetailView(scholarship: scholarship, match: nil)
                        } label: {
                            PremiumScholarshipCard(scholarship: scholarship)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .background(Theme.pageBackground)
        .navigationBarHidden(true)
        .refreshable { await load() }
        .task { await load() }
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
            HStack(spacing: 8) {
                filterMenu(title: region == "All" ? "Countries" : region) {
                    ForEach(regionOptions, id: \.self) { value in
                        Button(value) { region = value }
                    }
                }

                filterMenu(title: degree == "All" ? "Study level" : degree) {
                    ForEach(degreeOptions, id: \.self) { value in
                        Button(value) { degree = value }
                    }
                }

                filterMenu(title: funding == "All" ? "Funding" : funding) {
                    ForEach(fundingOptions, id: \.self) { value in
                        Button(value) { funding = value }
                    }
                }

                filterMenu(title: source == "All" ? "Type" : source) {
                    Button("All trusted") { source = "All" }
                    Button("Verified") { source = "Verified" }
                    Button("Curated") { source = "Curated" }
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
                            .frame(width: 34, height: 34)
                            .background(Theme.surfaceRaised)
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var hasFilters: Bool {
        region != "All" || degree != "All" || funding != "All" || source != "All"
    }

    private func filterMenu<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu(content: content) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(Theme.surfaceRaised)
                .clipShape(Capsule())
        }
    }

    @MainActor
    private func load() async {
        let initial = scholarships.isEmpty
        if initial { loading = true }
        defer { if initial { loading = false } }

        do {
            scholarships = try await DataService.scholarships()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PremiumScholarshipCard: View {
    let scholarship: Scholarship

    private var verified: Bool {
        scholarship.verificationStatus == "verified"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                UniversityPhoto(
                    seed: scholarship.provider + scholarship.title + scholarship.country,
                    height: 145
                )

                Button {} label: {
                    Image(systemName: "bookmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Theme.navyDeep.opacity(0.84))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(10)

                VStack {
                    Spacer()
                    HStack {
                        FundingBadge(text: scholarship.fundingType)
                        Spacer()
                    }
                    .padding(11)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(scholarship.title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(scholarship.provider)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(scholarship.country, systemImage: "mappin.and.ellipse")
                    if let degree = scholarship.degreeLevels.first {
                        Label(degree, systemImage: "graduationcap")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))

                HStack {
                    TrustSeal(verified: verified)

                    Spacer()

                    if let deadline = scholarship.deadline {
                        Label(deadline, systemImage: "calendar")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Theme.blue)
                        .clipShape(Circle())
                }
            }
            .padding(13)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.05))
        )
    }
}

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
            .padding(.vertical, 9)
            .background(Theme.surfaceRaised)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
