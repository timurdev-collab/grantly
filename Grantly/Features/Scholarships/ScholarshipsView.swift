import SwiftUI

struct ScholarshipsView: View {
    @State private var scholarships: [Scholarship] = []
    @State private var query = ""

    @State private var region = "All"
    @State private var degree = "All"
    @State private var funding = "All"
    @State private var source = "All"

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
        scholarships.filter { scholarship in
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
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Explore")
                            .font(.largeTitle.bold())

                        Text("\(filtered.count) of \(scholarships.count) scholarships")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
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
                            Button("All") { source = "All" }
                            Button("Verified") { source = "Verified" }
                            Button("Curated") { source = "Curated" }
                        } label: {
                            FilterChip(
                                icon: "checkmark.shield",
                                title: source == "All" ? "Source" : source
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
                                Label("Clear", systemImage: "xmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            if loading {
                Spacer()
                ProgressView("Loading scholarships…")
                Spacer()
            } else if filtered.isEmpty {
                EmptyState(
                    icon: "magnifyingglass",
                    title: "No scholarships found",
                    text: "Try changing your search or filters."
                )
            } else {
                List(filtered) { scholarship in
                    NavigationLink {
                        ScholarshipDetailView(
                            scholarship: scholarship,
                            match: nil
                        )
                    } label: {
                        ScholarshipRow(
                            scholarship: scholarship
                        )
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await load()
                }
            }
        }
        .searchable(
            text: $query,
            prompt: "Scholarship, country, university or major"
        )
        .navigationBarTitleDisplayMode(.inline)
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

struct FilterChip: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(Capsule())
    }
}

struct ScholarshipRow: View {
    let scholarship: Scholarship

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(scholarship.title)
                        .font(.headline)

                    Text("\(scholarship.provider) · \(scholarship.country)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                FundingBadge(
                    text: scholarship.fundingType
                )
            }

            HStack(spacing: 10) {
                ForEach(
                    scholarship.degreeLevels.prefix(3),
                    id: \.self
                ) { level in
                    Label(level, systemImage: "graduationcap")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if scholarship.verificationStatus == "verified" {
                    Label("Verified", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.green)
                } else if scholarship.verificationStatus == "curated" {
                    Label("Curated", systemImage: "checkmark.circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let deadline = scholarship.deadline {
                Label(
                    "Deadline: \(deadline)",
                    systemImage: "calendar"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
