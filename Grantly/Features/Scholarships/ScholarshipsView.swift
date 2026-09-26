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
                if left != right { return left && !right }

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
            LazyVStack(spacing: 14) {
                CatalogHeroCard(
                    total: scholarships.count,
                    verified: verifiedCount,
                    countries: countryCount
                )
                .padding(.horizontal)
                .padding(.top, 8)

                filterBar
                    .padding(.horizontal)

                if loading {
                    ProgressView("Loading trusted scholarships…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else if filtered.isEmpty {
                    EmptyState(
                        icon: "magnifyingglass",
                        title: "No scholarships found",
                        text: "Try another search or clear a filter."
                    )
                    .padding(.top, 40)
                } else {
                    HStack {
                        Text("\(filtered.count) opportunities")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Menu {
                            Button("Recommended") { sort = "Recommended" }
                            Button("Verified first") { sort = "Verified first" }
                            Button("Deadline") { sort = "Deadline" }
                        } label: {
                            Label(sort, systemImage: "arrow.up.arrow.down")
                                .font(.subheadline.weight(.semibold))
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
                            ScholarshipCard(scholarship: scholarship)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(
            text: $query,
            prompt: "Scholarship, university, country or field"
        )
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
        .alert("Unable to load scholarships", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                Menu {
                    ForEach(regionOptions, id: \.self) { value in
                        Button(value) { region = value }
                    }
                } label: {
                    FilterChip(
                        icon: "globe",
                        title: region == "All" ? "Region" : region
                    )
                }

                Menu {
                    ForEach(degreeOptions, id: \.self) { value in
                        Button(value) { degree = value }
                    }
                } label: {
                    FilterChip(
                        icon: "graduationcap",
                        title: degree == "All" ? "Degree" : degree
                    )
                }

                Menu {
                    ForEach(fundingOptions, id: \.self) { value in
                        Button(value) { funding = value }
                    }
                } label: {
                    FilterChip(
                        icon: "banknote",
                        title: funding == "All" ? "Funding" : funding
                    )
                }

                Menu {
                    Button("All trusted") { source = "All" }
                    Button("Verified") { source = "Verified" }
                    Button("Curated") { source = "Curated" }
                } label: {
                    FilterChip(
                        icon: "checkmark.shield",
                        title: source == "All" ? "Trust" : source
                    )
                }

                if region != "All" ||
                    degree != "All" ||
                    funding != "All" ||
                    source != "All" {
                    Button {
                        region = "All"
                        degree = "All"
                        funding = "All"
                        source = "All"
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .frame(width: 34, height: 34)
                            .background(.white)
                            .foregroundStyle(.red)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                    }
                }
            }
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            scholarships = try await DataService.scholarships()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CatalogHeroCard: View {
    let total: Int
    let verified: Int
    let countries: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scholarships you can trust")
                        .font(.title2.bold())

                    Text("Low-confidence listings are removed from Explore until their source is checked.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Image(systemName: "checkmark.shield.fill")
                    .font(.title)
                    .foregroundStyle(Theme.green)
                    .padding(12)
                    .background(Theme.mint)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 10) {
                CatalogMetric(value: "\(total)", label: "trusted")
                CatalogMetric(value: "\(verified)", label: "verified")
                CatalogMetric(value: "\(countries)", label: "countries")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    .white,
                    Theme.violet.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.black.opacity(0.04))
        )
    }
}

struct CatalogMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FilterChip: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white)
            .foregroundStyle(.primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.06))
            )
    }
}

struct ScholarshipCard: View {
    let scholarship: Scholarship

    private var isVerified: Bool {
        scholarship.verificationStatus == "verified"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(scholarship.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)

                    Text(scholarship.provider)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label(
                        "\(scholarship.country) · \(scholarship.region)",
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                FundingBadge(text: scholarship.fundingType)
            }

            HStack(spacing: 8) {
                TrustBadge(verified: isVerified)

                ForEach(
                    scholarship.degreeLevels.prefix(2),
                    id: \.self
                ) { level in
                    Text(level)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.soft)
                        .clipShape(Capsule())
                }
            }

            Divider()

            HStack {
                if let deadline = scholarship.deadline {
                    Label("Next deadline \(deadline)", systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Label("Deadline varies / TBA", systemImage: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.04))
        )
        .shadow(color: .black.opacity(0.035), radius: 12, y: 6)
    }
}

struct TrustBadge: View {
    let verified: Bool

    var body: some View {
        Label(
            verified ? "Verified" : "Curated",
            systemImage: verified ? "checkmark.seal.fill" : "checkmark.circle"
        )
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(verified ? Theme.mint : Theme.soft)
        .foregroundStyle(verified ? Theme.green : .secondary)
        .clipShape(Capsule())
    }
}
