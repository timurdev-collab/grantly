import SwiftUI

struct AdminView: View {
    @State private var scholarships: [Scholarship] = []
    @State private var reports: [SafetyReport] = []
    @State private var showingAdd = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Safety reports") {
                if reports.isEmpty {
                    Text("No reports")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reports) { report in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(report.reason)
                                    .font(.headline)
                                Spacer()
                                Text(report.status.capitalized)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }

                            if !report.details.isEmpty {
                                Text(report.details)
                                    .font(.subheadline)
                            }

                            HStack {
                                Text(report.messageId == nil ? "Student report" : "Message report")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Menu("Update status") {
                                    ForEach(["open", "reviewing", "resolved", "dismissed"], id: \.self) { status in
                                        Button(status.capitalized) {
                                            Task { await update(report: report, status: status) }
                                        }
                                    }
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Scholarships") {
                ForEach(scholarships) { scholarship in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scholarship.title)
                            .font(.headline)
                        Text("\(scholarship.country) · \(scholarship.fundingType)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Admin")
        .toolbar {
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddScholarshipView { Task { await load() } }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        do {
            async let scholarshipRows = DataService.scholarships()
            async let reportRows = DataService.safetyReports()

            scholarships = try await scholarshipRows
            reports = try await reportRows
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func update(report: SafetyReport, status: String) async {
        do {
            try await DataService.updateSafetyReportStatus(
                reportId: report.id,
                status: status
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AddScholarshipView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: () -> Void

    @State private var title = ""
    @State private var slug = ""
    @State private var provider = ""
    @State private var country = ""
    @State private var region = "Europe"
    @State private var funding = "Fully funded"
    @State private var degreeLevels = "Bachelor"
    @State private var fields = "All fields"
    @State private var url = ""
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Slug", text: $slug)
                TextField("Provider", text: $provider)
                TextField("Country", text: $country)

                Picker("Region", selection: $region) {
                    ForEach(["Europe", "Asia", "North America", "Middle East", "Oceania"], id: \.self) {
                        Text($0)
                    }
                }

                Picker("Funding", selection: $funding) {
                    ForEach(["Fully funded", "Full tuition", "Partial"], id: \.self) {
                        Text($0)
                    }
                }

                TextField("Degree levels, comma separated", text: $degreeLevels)
                TextField("Fields, comma separated", text: $fields)
                TextField("Official URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                if !error.isEmpty {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Add scholarship")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") { Task { await publish() } }
                }
            }
        }
    }

    @MainActor
    private func publish() async {
        struct Row: Encodable {
            let slug: String
            let title: String
            let provider: String
            let country: String
            let region: String
            let funding_type: String
            let official_url: String
            let status: String
            let degree_levels: [String]
            let fields: [String]
            let eligible_nationalities: [String]
            let verified_at: String
        }

        let row = Row(
            slug: slug,
            title: title,
            provider: provider,
            country: country,
            region: region,
            funding_type: funding,
            official_url: url,
            status: "published",
            degree_levels: degreeLevels
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) },
            fields: fields
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) },
            eligible_nationalities: ["ALL"],
            verified_at: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await supabase
                .from("scholarships")
                .insert(row)
                .execute()
            onCreated()
            dismiss()
        } catch {
            error = error.localizedDescription
        }
    }
}
