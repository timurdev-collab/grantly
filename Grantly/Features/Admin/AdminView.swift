import SwiftUI

struct AdminView: View {
    @State private var scholarships: [Scholarship] = []
    @State private var reports: [SafetyReport] = []
    @State private var analytics: AdminAnalyticsSummary?
    @State private var showingAdd = false
    @State private var auditing = false
    @State private var enrichingMedia = false
    @State private var auditMessage: String?
    @State private var mediaMessage: String?
    @State private var errorMessage: String?

    private var published: [Scholarship] {
        scholarships.filter { $0.status == "published" }
    }

    private var verifiedCount: Int {
        published.filter { $0.verificationStatus == "verified" }.count
    }

    private var curatedCount: Int {
        published.filter { $0.verificationStatus == "curated" }.count
    }

    private var reviewCount: Int {
        scholarships.filter {
            $0.status == "published" &&
            $0.verificationStatus == "needs_review"
        }.count
    }

    private var archivedCount: Int {
        scholarships.filter { $0.status == "archived" }.count
    }

    private var needsReview: [Scholarship] {
        scholarships
            .filter {
                $0.status == "published" &&
                $0.verificationStatus == "needs_review"
            }
            .prefix(30)
            .map { $0 }
    }

    var body: some View {
        List {
            if let analytics {
                Section("Product analytics · \(analytics.days) days") {
                    HStack(spacing: 12) {
                        AdminMetric(
                            value: "\(analytics.views)",
                            label: "Views"
                        )
                        AdminMetric(
                            value: "\(analytics.saves)",
                            label: "Saves"
                        )
                        AdminMetric(
                            value: "\(analytics.officialClicks)",
                            label: "Clicks"
                        )
                        AdminMetric(
                            value: "\(analytics.applications)",
                            label: "Applied"
                        )
                    }
                    .listRowInsets(
                        EdgeInsets(
                            top: 14,
                            leading: 16,
                            bottom: 14,
                            trailing: 16
                        )
                    )

                    HStack {
                        Label(
                            "\(analytics.searches) searches",
                            systemImage: "magnifyingglass"
                        )

                        Spacer()

                        Label(
                            "\(analytics.zeroResultSearches) zero results",
                            systemImage: "exclamationmark.magnifyingglass"
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Label(
                        "\(analytics.openHealthIssues) open catalog issues",
                        systemImage: "stethoscope"
                    )
                    .font(.caption.weight(.semibold))

                    if !analytics.topScholarships.isEmpty {
                        ForEach(analytics.topScholarships.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)

                                Text(item.provider)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 12) {
                                    Label(
                                        "\(item.views)",
                                        systemImage: "eye"
                                    )
                                    Label(
                                        "\(item.saves)",
                                        systemImage: "bookmark"
                                    )
                                    Label(
                                        "\(item.officialClicks)",
                                        systemImage: "arrow.up.right.square"
                                    )
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            Section("Catalog health") {
                HStack(spacing: 12) {
                    AdminMetric(
                        value: "\(verifiedCount)",
                        label: "Verified"
                    )
                    AdminMetric(
                        value: "\(curatedCount)",
                        label: "Curated"
                    )
                    AdminMetric(
                        value: "\(reviewCount)",
                        label: "Review"
                    )
                    AdminMetric(
                        value: "\(archivedCount)",
                        label: "Archived"
                    )
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 14,
                        leading: 16,
                        bottom: 14,
                        trailing: 16
                    )
                )

                Button {
                    Task { await auditNextBatch() }
                } label: {
                    Label(
                        auditing ? "Auditing links…" : "Audit next 20 listings",
                        systemImage: "checkmark.shield"
                    )
                }
                .disabled(auditing)

                if let auditMessage {
                    Text(auditMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await enrichNextMediaBatch() }
                } label: {
                    Label(
                        enrichingMedia ? "Enriching media…" : "Enrich university media",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }
                .disabled(enrichingMedia)

                if let mediaMessage {
                    Text(mediaMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("The automatic audit checks source availability, page specificity and possible deadline text. University media enrichment reads public metadata from provider websites and stores discovered icon and social-image URLs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !needsReview.isEmpty {
                Section("Needs source review") {
                    ForEach(needsReview) { scholarship in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(scholarship.title)
                                .font(.headline)

                            Text("\(scholarship.provider) · \(scholarship.country)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Text(
                                    scholarship.linkStatus?
                                        .replacingOccurrences(
                                            of: "_",
                                            with: " "
                                        )
                                        .capitalized
                                    ?? "Unchecked"
                                )
                                .font(.caption2.weight(.semibold))

                                Spacer()

                                if let candidate = scholarship.deadlineCandidate {
                                    Label(
                                        candidate,
                                        systemImage: "calendar.badge.exclamationmark"
                                    )
                                    .font(.caption2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

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
                                Text(
                                    report.messageId == nil
                                        ? "Student report"
                                        : "Message report"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Spacer()

                                Menu("Update status") {
                                    ForEach(
                                        [
                                            "open",
                                            "reviewing",
                                            "resolved",
                                            "dismissed"
                                        ],
                                        id: \.self
                                    ) { status in
                                        Button(status.capitalized) {
                                            Task {
                                                await update(
                                                    report: report,
                                                    status: status
                                                )
                                            }
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

            Section("Published catalog") {
                ForEach(published.prefix(50)) { scholarship in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scholarship.title)
                            .font(.headline)

                        Text(
                            "\(scholarship.country) · " +
                            "\(scholarship.fundingType)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if published.count > 50 {
                    Text("Showing the 50 most recently updated records.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            AddScholarshipView {
                Task { await load() }
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        do {
            async let scholarshipRows =
                DataService.allScholarshipsForAdmin()
            async let reportRows =
                DataService.safetyReports()
            async let analyticsSummary =
                DataService.adminAnalyticsSummary(days: 30)

            scholarships = try await scholarshipRows
            reports = try await reportRows
            analytics = try await analyticsSummary
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func auditNextBatch() async {
        auditing = true
        auditMessage = nil
        defer { auditing = false }

        do {
            let result = try await DataService.auditScholarships(limit: 20)

            auditMessage =
                "Audited \(result.audited): " +
                "\(result.exact) exact, " +
                "\(result.reachable) reachable, " +
                "\(result.generic) generic, " +
                "\(result.dead) unavailable. " +
                "\(result.deadlineCandidates) deadline candidates found."

            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func enrichNextMediaBatch() async {
        enrichingMedia = true
        mediaMessage = nil
        defer { enrichingMedia = false }

        do {
            let result = try await DataService.enrichUniversityMedia(limit: 10)

            mediaMessage =
                "Checked \(result.enriched): " +
                "\(result.ready) ready, " +
                "\(result.partial) partial, " +
                "\(result.failed) failed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func update(
        report: SafetyReport,
        status: String
    ) async {
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

private struct AdminMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                    ForEach(
                        [
                            "Africa",
                            "Asia",
                            "Europe",
                            "Global",
                            "Latin America",
                            "Middle East",
                            "North America",
                            "Oceania"
                        ],
                        id: \.self
                    ) {
                        Text($0)
                    }
                }

                Picker("Funding", selection: $funding) {
                    ForEach(
                        [
                            "Fully funded",
                            "Full tuition",
                            "Partial",
                            "Varies"
                        ],
                        id: \.self
                    ) {
                        Text($0)
                    }
                }

                TextField(
                    "Degree levels, comma separated",
                    text: $degreeLevels
                )

                TextField(
                    "Fields, comma separated",
                    text: $fields
                )

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
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        Task { await publish() }
                    }
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
            let verification_status: String
            let link_status: String
            let last_checked_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

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
                .map {
                    $0.trimmingCharacters(
                        in: .whitespaces
                    )
                },
            fields: fields
                .split(separator: ",")
                .map {
                    $0.trimmingCharacters(
                        in: .whitespaces
                    )
                },
            eligible_nationalities: ["ALL"],
            verified_at: now,
            verification_status: "verified",
            link_status: "exact",
            last_checked_at: now
        )

        do {
            let duplicates = try await DataService
                .scholarshipDuplicateCandidates(
                    title: title,
                    provider: provider,
                    country: country
                )

            if let duplicate = duplicates.first,
               duplicate.similarityScore >= 90 {
                error =
                    "Possible duplicate: \(duplicate.title) · " +
                    "\(duplicate.provider). Please review the existing " +
                    "record before publishing."
                return
            }

            try await supabase
                .from("scholarships")
                .insert(row)
                .execute()

            onCreated()
            dismiss()
        } catch let err {
            error = err.localizedDescription
        }
    }
}
