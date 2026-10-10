import SwiftUI

struct ScholarshipsView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34
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
    @State private var sort = "Verified first"

    @State private var loading = true
    @State private var loadingMore = false
    @State private var requestID = UUID()
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

    private var fullyFundedValue: String {
        filterOptions.funding.first {
            $0.lowercased().contains("fully")
        } ?? "Fully funded"
    }

    private var hasFilters: Bool {
        country != "All" ||
        degree != "All" ||
        field != "All" ||
        funding != "All"
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

                deadlineSoonQuickAction
                    .padding(.horizontal)

                studyLevelSelector
                    .padding(.horizontal)

                filters
                    .padding(.horizontal)

                resultsHeader

                if loading && scholarships.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.orange)

                        Text("Finding trusted opportunities...")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
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
                            .tint(Theme.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Theme.premiumIvoryRaised)
        .preferredColorScheme(.light)
        .navigationBarHidden(true)
        .scrollBounceBehavior(.always, axes: .vertical)
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            await refresh()
        }
        .task {
            await loadFilterOptions()
        }
        .task(id: searchKey) {
            _ = try? await Task.sleep(nanoseconds: 300_000_000)

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
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("Discover"))
                    .font(.system(size: titleSize, weight: .regular, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.premiumInk)

                Text(L10n.string("Curated, verified opportunities for your goals"))
                    .font(.caption)
                    .foregroundStyle(Theme.premiumMuted)
            }

            Spacer()

            RefreshButton(loading: loading) {
                await refresh()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var deadlineSoonQuickAction: some View {
        HStack {
            Button {
                sort = "Deadline"
            } label: {
                Label(
                    "Deadline soon",
                    systemImage: "calendar.badge.clock"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    sort == "Deadline"
                        ? Theme.onAccent
                        : Theme.ink
                )
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(
                    sort == "Deadline"
                        ? Theme.accent
                        : Theme.surface
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            sort == "Deadline"
                                ? Theme.accent.opacity(0)
                                : Theme.ink.opacity(0.06)
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var studyLevelSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Explore by study level")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(degreeOptions, id: \.self) { value in
                        let selected = degree == value

                        Button {
                            degree = value
                        } label: {
                            HStack(spacing: 6) {
                                if value != "All" {
                                    Image(systemName: "graduationcap.fill")
                                        .font(.caption2)
                                }

                                Text(value)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(
                                selected
                                    ? .white
                                    : Theme.ink.opacity(0.70)
                            )
                            .padding(.horizontal, 13)
                            .frame(height: 38)
                            .background(
                                selected
                                    ? Theme.accent
                                    : Theme.surfaceRaised
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selected
                                            ? Theme.accentSoft.opacity(0.30)
                                            : Theme.ink.opacity(0.06)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            value == "All"
                                ? "All study levels"
                                : "\(value) study level"
                        )
                        .accessibilityAddTraits(
                            selected ? .isSelected : []
                        )
                    }
                }
            }
        }
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

                if hasFilters {
                    Button {
                        clearFilters()
                    } label: {
                        Label("Clear", systemImage: "xmark")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .background(Theme.surface)
                            .foregroundStyle(Theme.muted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var resultsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    hasFilters || !query.isEmpty
                        ? "Search results"
                        : "Scholarships for you"
                )
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

                Text("Official-source opportunities, ranked by trust")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            Menu {
                Button("Best verified") { sort = "Verified first" }
                Button("Recommended") { sort = "Recommended" }
                Button("Deadline soon") { sort = "Deadline" }
            } label: {
                Label(
                    sort == "Verified first"
                        ? "Best verified"
                        : (sort == "Deadline" ? "Deadline soon" : sort),
                    systemImage: "arrow.up.arrow.down"
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
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
                .foregroundStyle(Theme.sand)
                .frame(width: 60, height: 60)
                .background(Theme.surface)
                .clipShape(Circle())

            Text("No scholarships found")
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            Text("Try another search or clear one of your filters.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            if hasFilters {
                Button("Clear filters") {
                    clearFilters()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.sand)
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
                .foregroundStyle(active ? .white : Theme.ink.opacity(0.72))
                .background(active ? Theme.accent : Theme.surfaceRaised)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.ink.opacity(active ? 0 : 0.06))
                )
        }
    }

    private func clearFilters() {
        country = "All"
        degree = "All"
        field = "All"
        funding = "All"
    }

    private func optional(_ value: String) -> String? {
        value == "All" ? nil : value
    }

    @MainActor
    private func loadFilterOptions() async {
        do {
            filterOptions = try await ScholarshipSearchService.filters()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refresh() async {
        await load(reset: true)
        await loadFilterOptions()
    }

    @MainActor
    private func load(reset: Bool) async {
        let currentRequest = UUID()
        requestID = currentRequest
        let currentSearchKey = searchKey

        if reset {
            loading = true
            loadingMore = false
        } else {
            loadingMore = true
        }

        defer {
            if requestID == currentRequest {
                loading = false
                loadingMore = false
            }
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

            guard requestID == currentRequest,
                  searchKey == currentSearchKey,
                  !Task.isCancelled else { return }

            errorMessage = nil
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

            if reset {
                let trimmedQuery = query.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                let properties = [
                    "query": trimmedQuery,
                    "country": country,
                    "degree": degree,
                    "field": field,
                    "funding": funding,
                    "source": source,
                    "sort": sort,
                    "result_count": String(page.totalCount)
                ]

                _ = try? await DataService.trackProductEvent(
                    page.totalCount == 0
                        ? "zero_result_search"
                        : "search",
                    properties: properties
                )
            }

        } catch is CancellationError {
            return
        } catch {
            guard requestID == currentRequest, !Task.isCancelled else { return }
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
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

struct PremiumScholarshipCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let scholarship: Scholarship
    var saved: Bool = false

    private var verified: Bool {
        scholarship.verificationStatus == "verified"
    }

    private var primaryDegree: String {
        scholarship.degreeLevels.first ?? "Multiple levels"
    }

    private var countryLabel: String {
        let flag = countryFlag(for: scholarship.country)
        return flag.isEmpty
            ? scholarship.country
            : "\(flag) \(scholarship.country)"
    }

    private var cardLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private var metadataLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
    }

    var body: some View {
        cardLayout {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.premiumSageSoft)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.premiumForest)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.premiumForestSoft)
                        .padding(5)
                }
            }
            .frame(width: 54, height: 54)
            .accessibilityLabel(verified ? "Verified scholarship" : "Scholarship")

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 6) {
                    Text(scholarship.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.premiumInk)
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                    Spacer(minLength: 4)

                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            saved ? Theme.premiumBrass : Theme.premiumMuted
                        )
                }

                Text(scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(Theme.premiumMuted)
                    .lineLimit(1)

                metadataLayout {
                    Text(scholarship.fundingType)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.premiumForest)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .frame(minHeight: 26)
                        .background(Theme.premiumSageSoft)
                        .clipShape(Capsule())

                    Text(primaryDegree)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.premiumMuted)
                        .lineLimit(1)
                }

                metadataLayout {
                    Text(countryLabel)
                        .font(.caption2)
                        .foregroundStyle(Theme.premiumMuted)
                        .lineLimit(1)

                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                    if let deadline = scholarship.deadline {
                        Label(
                            String(deadline.prefix(10)),
                            systemImage: "calendar"
                        )
                        .font(.caption2)
                        .foregroundStyle(Theme.premiumBrass)
                    }
                }
            }
        }
        .padding(10)
        .background(Theme.premiumIvoryRaised)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.premiumInk.opacity(0.05), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.045),
            radius: 14,
            x: 0,
            y: 7
        )
    }
}

private func countryFlag(for countryName: String) -> String {
    let normalized = countryName
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    let aliases: [String: String] = [
        "south korea": "KR",
        "korea": "KR",
        "republic of korea": "KR",
        "north korea": "KP",
        "united states": "US",
        "united states of america": "US",
        "usa": "US",
        "u.s.a.": "US",
        "united kingdom": "GB",
        "uk": "GB",
        "u.k.": "GB",
        "russia": "RU",
        "czech republic": "CZ",
        "vietnam": "VN",
        "viet nam": "VN",
        "taiwan": "TW",
        "hong kong": "HK"
    ]

    let code: String? = aliases[normalized] ?? Locale.Region.isoRegions.first {
        guard let name = Locale(identifier: "en_US")
            .localizedString(forRegionCode: $0.identifier)?
            .lowercased() else {
            return false
        }

        return name == normalized
    }?.identifier

    guard let code, code.count == 2 else {
        return ""
    }

    let base: UInt32 = 127397
    let scalars = code.uppercased().unicodeScalars.compactMap {
        UnicodeScalar(base + $0.value)
    }

    return String(String.UnicodeScalarView(scalars))
}

struct ReliabilityBadge: View {
    let score: Int

    private var label: String {
        if score >= 85 { return L10n.string("High reliability") }
        if score >= 70 { return L10n.string("Reliable") }
        if score >= 55 { return L10n.string("Moderate") }
        return L10n.string("Limited")
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.checkered")
            Text("\(score)")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(
            score >= 70
                ? Theme.green
                : Theme.orangeSoft
        )
        .accessibilityLabel("\(label), score \(score) out of 100")
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
            .foregroundStyle(Theme.ink)
            .frame(width: 38, height: 38)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(Theme.orange.opacity(0.25))
            )
    }
}

private struct MetadataPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.muted)
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
            .foregroundStyle(Theme.ink)
            .clipShape(Capsule())
    }
}
