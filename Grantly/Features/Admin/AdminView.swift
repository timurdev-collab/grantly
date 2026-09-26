import SwiftUI

struct AdminView: View {
    @State private var scholarships: [Scholarship] = []
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(scholarships) { scholarship in
                VStack(alignment: .leading, spacing: 4) {
                    Text(scholarship.title).font(.headline)
                    Text("\(scholarship.country) · \(scholarship.fundingType)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Admin")
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) {
            AddScholarshipView { Task { await load() } }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        scholarships = (try? await DataService.scholarships()) ?? []
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
                    ForEach(["Europe","Asia","North America","Middle East","Oceania"], id:\.self) { Text($0) }
                }
                Picker("Funding", selection: $funding) {
                    ForEach(["Fully funded","Full tuition","Partial"], id:\.self) { Text($0) }
                }
                TextField("Degree levels, comma separated", text: $degreeLevels)
                TextField("Fields, comma separated", text: $fields)
                TextField("Official URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                if !error.isEmpty { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle("Add scholarship")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Publish") { Task { await publish() } } }
            }
        }
    }

    @MainActor
    private func publish() async {
        struct Row: Encodable {
            let slug, title, provider, country, region, funding_type, official_url, status: String
            let degree_levels, fields, eligible_nationalities: [String]
            let verified_at: String
        }
        let row = Row(
            slug: slug, title: title, provider: provider, country: country, region: region,
            funding_type: funding, official_url: url, status: "published",
            degree_levels: degreeLevels.split(separator:",").map{$0.trimmingCharacters(in:.whitespaces)},
            fields: fields.split(separator:",").map{$0.trimmingCharacters(in:.whitespaces)},
            eligible_nationalities: ["ALL"],
            verified_at: ISO8601DateFormatter().string(from: Date())
        )
        do {
            try await supabase.from("scholarships").insert(row).execute()
            onCreated()
            dismiss()
        } catch let err {
            error = err.localizedDescription
        }
    }
}
