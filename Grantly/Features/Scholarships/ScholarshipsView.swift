import SwiftUI

struct ScholarshipsView: View {
    @State private var scholarships: [Scholarship] = []
    @State private var query = ""

    @State private var region = "All"
    @State private var degree = "All"
    @State private var funding = "All"

    @State private var loading = true

    private var filtered: [Scholarship] {
        scholarships.filter { scholarship in

            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

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

            return queryMatches &&
                   regionMatches &&
                   degreeMatches &&
                   fundingMatches
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
                            Button("All") { region = "All" }
                            Button("Europe") { region = "Europe" }
                            Button("Asia") { region = "Asia" }
                            Button("North America") { region = "North America" }
                            Button("Middle East") { region = "Middle East" }
                            Button("Oceania") { region = "Oceania" }
                        } label: {
                            FilterChip(
                                icon: "globe",
                                title: region == "All" ? "Region" : region
                            )
                        }

                        Menu {
                            Button("All") { degree = "All" }
                            Button("Bachelor") { degree = "Bachelor" }
                            Button("Master") { degree = "Master" }
                            Button("PhD") { degree = "PhD" }
                        } label: {
                            FilterChip(
                                icon: "graduationcap",
                                title: degree == "All" ? "Degree" : degree
                            )
                        }

                        Menu {
                            Button("All") { funding = "All" }
                            Button("Fully funded") { funding = "Fully funded" }
                            Button("Full tuition") { funding = "Full tuition" }
                            Button("Partial") { funding = "Partial" }
                        } label: {
                            FilterChip(
                                icon: "banknote",
                                title: funding == "All" ? "Funding" : funding
                            )
                        }

                        if region != "All" ||
                           degree != "All" ||
                           funding != "All" {

                            Button {
                                region = "All"
                                degree = "All"
                                funding = "All"
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
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        scholarships =
            (try? await DataService.scholarships()) ?? []
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
