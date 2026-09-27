import SwiftUI

struct ScholarshipsView: View {
    private let pageSize = 20

    @State private var scholarships: [Scholarship] = []
    @State private var totalCount = 0
    @State private var savedScholarshipIDs: Set<UUID> = []
    @State private var filterOptions = ScholarshipFilterOptions(
        countries: [],
        degrees: [],
        fields: [],
        funding: []
    )

    @State private var query = ""
    @State private var country = "All"
    @State private var degree = "All"
    @State private var field = "All"
    @State private var funding = "All"
    @State private var source = "All"
    @State private var sort = "Recommended"

    @State private var loading = true
    @State private var loadingMore = false
    @State private var errorMessage: String?

    private var countryOptions: [String] {
        ["All"] + filterOptions.countries
    }

    private var degreeOptions: [String] {
        ["All"] + filterOptions.degrees
    }

    private var fieldOptions: [String] {
        ["All"] + filterOptions.fields
    }

    private var fundingOptions: [String] {
        ["All"] + filterOptions.funding
    }

    private var verifiedCount: Int {
        scholarships.filter { $0.verificationStatus == "verified" }.count
    }

    private var topPicks: [Scholarship] {
        scholarships
            .filter {
                $0.verificationStatus == "verified" &&
                (
                    $0.fundingType.lowercased().contains("fully") ||
                    $0.deadline != nil
                )
            }
            .sorted {
                let leftFully = $0.fundingType.lowercased().contains("fully")
                let rightFully = $1.fundingType.lowercased().contains("fully")

                if leftFully != rightFully {
                    return leftFully && !rightFully
                }

                return ($0.deadline ?? "9999-12-31") <
                    ($1.deadline ?? "9999-12-31")
            }
    }

    private var hasFilters: Bool {
        country != "All" ||
        degree != "All" ||
        field != "All" ||
        funding != "All" ||
        source != "All"
    }

    private var shouldShowTopPicks: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !hasFilters &&
        !topPicks.isEmpty
    }

    private var hasMore: Bool {
        scholarships.count < totalCount
    }

    private var searchKey: String {
        [
            query,
            country,
            degree,
            field,
            funding,
            source,
            sort
        ].joined(separator: "|")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                exploreHeader

                SearchField(
                    text: $query,
                    prompt: "Search scholarships, universities, countries..."
                )
                .padding(.horizontal)

                filters
                    .padding(.horizontal)

                if shouldShowTopPicks {
                    topPicksSection
                }

                resultsHeader

                if loading && scholarships.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.blue)

                        Text("Finding trusted opportunities...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
                } else if scholarships.isEmpty {
                    emptyState
                } else {
                    ForEach(scholarships) { scholarship in
                        NavigationLink {
                            ScholarshipDetailView(
                                scholarship: scholarship,
                                match: nil
                            )
                        } label: {
                            PremiumScholarshipCard(
                                scholarship: scholarship,
                                saved: savedScholarshipIDs.contains(scholarship.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .onAppear {
                            if scholarship.id == scholarships.last?.id {
                                Task { await loadMore() }
                            }
                        }
                    }

                    if loadingMore {
                        ProgressView()
                            .tint(Theme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Theme.pageBackground)
        .navigationBarHidden(true)
        .refreshable {
            await load(reset: true)
        }
        .task {
            await loadFilterOptions()
        }
        .task(id: searchKey) {
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else {
                return
            }

            await load(reset: true)
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

    private var exploreHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Explore")
                        .font(.system(size: 31, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Scholarships from universities around the world")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.56))
                }

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.blueSoft)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }

            HStack(spacing: 10) {
                ExploreSummary(
                    value: "\(totalCount)",
                    label: "Results"
                )

                ExploreSummary(
                    value: "\(verifiedCount)",
                    label: "Verified loaded"
                )

                ExploreSummary(
                    value: "\(filterOptions.countries.count)",
                    label: "Countries"
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterMenu(
                    title: country == "All" ? "Countries" : country,
                    icon: "globe",
                    active: country != "All"
                ) {
                    ForEach(countryOptions, id: \.self) { value in
                        Button(value) { country = value }
                    }
                }

                filterMenu(
                    title: degree == "All" ? "Study level" : degree,
                    icon: "graduationcap",
                    active: degree != "All"
                ) {
                    ForEach(degreeOptions, id: \.self) { value in
                        Button(value) { degree = value }
                    }
                }

                filterMenu(
                    title: field == "All" ? "Field" : field,
                    icon: "books.vertical",
                    active: field != "All"
                ) {
                    ForEach(fieldOptions, id: \.self) { value in
                        Button(value) { field = value }
                    }
                }

                filterMenu(
                    title: funding == "All" ? "Funding" : funding,
                    icon: "banknote",
                    active: funding != "All"
                ) {
                    ForEach(fundingOptions, id: \.self) { value in
                        Button(value) { funding = value }
                    }
                }

                filterMenu(
                    title: source == "All" ? "Trust" : source,
                    icon: "checkmark.seal",
                    active: source != "All"
                ) {
                    Button("All trusted") { source = "All" }
                    Button("Verified") { source = "Verified" }
                    Button("Curated") { source = "Curated" }
                }

                if hasFilters {
                    Button {
                        clearFilters()
                    } label: {
                        Label("Clear", systemImage: "xmark")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .background(Theme.surface)
                            .foregroundStyle(.white.opacity(0.74))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var topPicksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top opportunities")
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    Text("Verified scholarships worth a closer look")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.blueSoft)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(topPicks.prefix(6)) { scholarship in
                        NavigationLink {
                            ScholarshipDetailView(
                                scholarship: scholarship,
                                match: nil
                            )
                        } label: {
                            ExploreTopPickCard(scholarship: scholarship)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var resultsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    hasFilters || !query.isEmpty
                        ? "Search results"
                        : "All scholarships"
                )
                .font(.headline.bold())
                .foregroundStyle(.white)

                Text("\(totalCount) opportunities")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Menu {
                Button("Recommended") { sort = "Recommended" }
                Button("Verified first") { sort = "Verified first" }
                Button("Deadline") { sort = "Deadline" }
            } label: {
                Label(sort, systemImage: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Theme.surface)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.top, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.blueSoft)
                .frame(width: 60, height: 60)
                .background(Theme.surface)
                .clipShape(Circle())

            Text("No scholarships found")
                .font(.headline.bold())
                .foregroundStyle(.white)

            Text("Try another search or clear one of your filters.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.56))
                .multilineTextAlignment(.center)

            if hasFilters {
                Button("Clear filters") {
                    clearFilters()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.blueSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func filterMenu<Content: View>(
        title: String,
        icon: String,
        active: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu(content: content) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 38)
                .foregroundStyle(active ? .white : .white.opacity(0.72))
                .background(active ? Theme.blue : Theme.surfaceRaised)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(active ? 0 : 0.06))
                )
        }
    }

    private func clearFilters() {
        country = "All"
        degree = "All"
        field = "All"
        funding = "All"
        source = "All"
    }

    private func optional(_ value: String) -> String? {
        value == "All" ? nil : value
    }

    @MainActor
    private func loadFilterOptions() async {
        do {
            filterOptions = try await ScholarshipSearchService.filters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func load(reset: Bool) async {
        if reset {
            loading = true
        } else {
            loadingMore = true
        }

        defer {
            loading = false
            loadingMore = false
        }

        do {
            let page = try await ScholarshipSearchService.search(
                query: query
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
                    ? nil
                    : query,
                country: optional(country),
                degree: optional(degree),
                field: optional(field),
                funding: optional(funding),
                source: optional(source),
                sort: sort,
                offset: reset ? 0 : scholarships.count,
                limit: pageSize
            )

            if reset {
                scholarships = page.scholarships
                savedScholarshipIDs = page.savedScholarshipIDs
            } else {
                let existing = Set(scholarships.map(\.id))
                scholarships.append(
                    contentsOf: page.scholarships.filter {
                        !existing.contains($0.id)
                    }
                )
                savedScholarshipIDs.formUnion(page.savedScholarshipIDs)
            }

            totalCount = page.totalCount
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadMore() async {
        guard hasMore, !loading, !loadingMore else {
            return
        }

        await load(reset: false)
    }
}

private struct ExploreSummary: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.05))
        )
    }
}

private struct ExploreTopPickCard: View {
    let scholarship: Scholarship

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                UniversityPhoto(
                    seed: "top" + scholarship.provider + scholarship.title,
                    height: 126
                )

                LinearGradient(
                    colors: [Theme.navyDeep.opacity(0.10), Theme.navyDeep.opacity(0.64)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                TrustSeal(
                    verified: scholarship.verificationStatus == "verified"
                )
                .padding(10)
            }

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

                HStack {
                    Label(
                        scholarship.country,
                        systemImage: "mappin.and.ellipse"
                    )
                    .lineLimit(1)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.blueSoft)
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.66))
            }
            .padding(12)
        }
        .frame(width: 232)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19)
                .stroke(.white.opacity(0.05))
        )
    }
}

struct PremiumScholarshipCard: View {
    let scholarship: Scholarship
    var saved: Bool = false

    private var verified: Bool {
        scholarship.verificationStatus == "verified"
    }

    private var primaryDegree: String {
        scholarship.degreeLevels.first ?? "Multiple levels"
    }

    private var primaryField: String {
        scholarship.fields.first ?? "All fields"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                UniversityPhoto(
                    seed: scholarship.provider + scholarship.title + scholarship.country,
                    height: 164
                )

                LinearGradient(
                    colors: [.clear, Theme.navyDeep.opacity(0.92)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom) {
                    FundingBadge(text: scholarship.fundingType)

                    Spacer()

                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .font(.caption.bold())
                        .foregroundStyle(saved ? Theme.blueSoft : .white)
                        .frame(width: 34, height: 34)
                        .background(Theme.navyDeep.opacity(0.80))
                        .clipShape(Circle())
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    InstitutionBadge(name: scholarship.provider)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(scholarship.title)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(scholarship.provider)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    MetadataPill(
                        icon: "mappin.and.ellipse",
                        text: scholarship.country
                    )

                    MetadataPill(
                        icon: "graduationcap",
                        text: primaryDegree
                    )
                }

                if !primaryField.isEmpty {
                    Label(primaryField, systemImage: "books.vertical")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                }

                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 1)

                HStack(spacing: 8) {
                    TrustSeal(verified: verified)

                    Spacer()

                    if let deadline = scholarship.deadline {
                        Label(deadline, systemImage: "calendar")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.blueSoft)
                    } else {
                        Text("Deadline varies")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Theme.blueGradient)
                        .clipShape(Circle())
                }
            }
            .padding(13)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.05))
        )
    }
}

private struct InstitutionBadge: View {
    let name: String

    private var initials: String {
        let words = name.split(separator: " ")

        if words.count >= 2 {
            return (
                String(words[0].prefix(1)) +
                String(words[1].prefix(1))
            )
            .uppercased()
        }

        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(Theme.blue.opacity(0.25))
            )
    }
}

private struct MetadataPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.68))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Theme.surfaceRaised)
            .clipShape(Capsule())
            .lineLimit(1)
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
