import SwiftUI

struct MyScholarshipsView: View {
    @State private var items: [SavedScholarshipItem] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading saved scholarships…")
            } else if items.isEmpty {
                ContentUnavailableView(
                    "No saved scholarships",
                    systemImage: "bookmark",
                    description: Text("Save scholarships from Explore to track your applications here.")
                )
            } else {
                List {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.scholarship.title)
                                .font(.headline)

                            Text("\(item.scholarship.provider) · \(item.scholarship.country)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Menu {
                                ForEach(
                                    ["Planning", "Applied", "Interview", "Result"],
                                    id: \.self
                                ) { status in
                                    Button(status) {
                                        Task {
                                            await updateStatus(
                                                item: item,
                                                status: status
                                            )
                                        }
                                    }
                                }
                            } label: {
                                Label(
                                    item.applicationStatus,
                                    systemImage: "checklist"
                                )
                                .font(.subheadline.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .refreshable {
                    await load()
                }
            }
        }
        .navigationTitle("My Scholarships")
        .task {
            await load()
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            items = try await DataService.savedScholarshipItems()
        } catch {
            print("Failed to load saved scholarships:", error)
        }
    }

    @MainActor
private func updateStatus(
    item: SavedScholarshipItem,
    status: String
) async {
    do {
        try await DataService.updateApplicationStatus(
            scholarshipId: item.scholarship.id,
            status: status
        )

        if let index = items.firstIndex(where: {
            $0.scholarshipId == item.scholarshipId
        }) {
            items[index] = SavedScholarshipItem(
                scholarshipId: item.scholarshipId,
                applicationStatus: status,
                notes: item.notes,
                scholarship: item.scholarship
            )
        }

    } catch {
        print("Failed to update status:", error)
    }
}}
