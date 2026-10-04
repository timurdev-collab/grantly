import SwiftUI

struct AdminView: View {
    @State private var scholarships: [Scholarship] = []
    @State private var reports: [SafetyReport] = []
    @State private var detectedChanges: [ScholarshipDetectedChange] = []
    @State private var healthIssues: [CatalogHealthIssue] = []
    @State private var sourceCandidates: [ScholarshipSourceCandidate] = []
    @State private var auditObservations: [ScholarshipAuditObservation] = []
    @State private var analytics: AdminAnalyticsSummary?
    @State private var systemHealth: AdminSystemHealth?
    @State private var actionLogs: [AdminActionLog] = []
    @State private var showingAdd = false
    @State private var showingImport = false
    @State private var selectedDraft: Scholarship?
    @State private var importBatches: [ScholarshipImportBatch] = []
    @State private var auditing = false
    @State private var enrichingMedia = false
    @State private var bulkOperating = false
    @State private var auditMessage: String?
    @State private var mediaMessage: String?
    @State private var bulkMessage: String?
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

    private var draftScholarships: [Scholarship] {
        scholarships.filter { $0.status == "draft" }
    }

    private var pendingDeadlineChanges: Int {
        detectedChanges.filter { $0.fieldName == "deadline" }.count
    }

    private var pendingCycleChanges: Int {
        detectedChanges.filter {
            $0.fieldName == "application_cycle" ||
            $0.fieldName == "cycle_status"
        }.count
    }

    private var expiredIssueCount: Int {
        healthIssues.filter { $0.issueType == "expired_deadline" }.count
    }

    private var brokenLinkIssueCount: Int {
        healthIssues.filter { $0.issueType == "dead_link" }.count
    }

    private var staleIssueCount: Int {
        healthIssues.filter { $0.issueType == "stale_source_check" }.count
    }

    private var recentAuditFailures: Int {
        auditObservations.filter { $0.outcome != "success" }.count
    }

    private var recentAmbiguousDeadlines: Int {
        auditObservations.filter { $0.deadlineAmbiguous }.count
    }

    private var recentSourceChanges: Int {
        auditObservations.filter { $0.sourceChanged }.count
    }

    private func scholarshipTitle(for id: UUID) -> String {
        scholarships.first(where: { $0.id == id })?.title
            ?? "Scholarship"
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
            Section("People & access") {
                NavigationLink {
                    AdminPeopleView()
                } label: {
                    Label(
                        "Students & advisors",
                        systemImage: "person.2.badge.gearshape"
                    )
                }

                Text("Manage student access and review advisor applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

            if let systemHealth {
                Section("System health") {
                    HStack(spacing: 12) {
                        AdminMetric(
                            value: "\(systemHealth.activeCronJobs)",
                            label: "Cron jobs"
                        )
                        AdminMetric(
                            value: "\(systemHealth.pendingPushNotifications)",
                            label: "Push pending"
                        )
                        AdminMetric(
                            value: "\(systemHealth.failedPushNotifications)",
                            label: "Push failed"
                        )
                        AdminMetric(
                            value: "\(systemHealth.openBackendErrors)",
                            label: "Errors"
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

                    Label(
                        "\(systemHealth.openCatalogIssues) open catalog issues",
                        systemImage: "waveform.path.ecg"
                    )
                    .font(.caption.weight(.semibold))

                    ForEach(systemHealth.cronJobs) { job in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(job.name)
                                    .font(.caption.weight(.semibold))

                                Text(job.schedule)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(
                                systemName: job.active
                                    ? "checkmark.circle.fill"
                                    : "pause.circle.fill"
                            )
                            .foregroundStyle(
                                job.active
                                    ? .green
                                    : .orange
                            )
                        }
                    }
                }
            }

            Section("Bulk catalog actions") {
                Button {
                    Task {
                        await bulkUpdate(
                            ids: needsReview.map(\.id),
                            action: "verify"
                        )
                    }
                } label: {
                    Label(
                        bulkOperating
                            ? "Working…"
                            : "Verify all review items",
                        systemImage: "checkmark.seal"
                    )
                }
                .disabled(bulkOperating || needsReview.isEmpty)

                Button {
                    Task {
                        await bulkUpdate(
                            ids: published
                                .filter { $0.deadline != nil && ($0.deadline ?? "") < todayString }
                                .map(\.id),
                            action: "archive"
                        )
                    }
                } label: {
                    Label(
                        "Archive expired published items",
                        systemImage: "archivebox"
                    )
                }
                .disabled(bulkOperating)

                if let bulkMessage {
                    Text(bulkMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Catalog imports") {
                Button {
                    showingImport = true
                } label: {
                    Label(
                        "Import CSV or JSON",
                        systemImage: "square.and.arrow.down"
                    )
                }

                if importBatches.isEmpty {
                    Text("No import batches yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(importBatches.prefix(8)) { batch in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(batch.sourceLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)

                                Spacer()

                                Text(batch.status.capitalized)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Label("\(batch.insertCount)", systemImage: "plus.circle")
                                Label("\(batch.updateCount)", systemImage: "arrow.triangle.2.circlepath")
                                Label("\(batch.skipCount)", systemImage: "forward")
                                Label("\(batch.errorCount)", systemImage: "exclamationmark.triangle")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            HStack {
                                if batch.status == "staged" {
                                    Button("Commit") {
                                        Task { await commitImport(batch) }
                                    }
                                    .font(.caption.weight(.semibold))
                                }

                                if batch.status == "committed" {
                                    Button("Rollback", role: .destructive) {
                                        Task { await rollbackImport(batch) }
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("Draft scholarship review") {
                if draftScholarships.isEmpty {
                    Text("No scholarship drafts waiting for review.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draftScholarships.prefix(20)) { draft in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(draft.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)

                            HStack(spacing: 10) {
                                Label(
                                    draft.provider,
                                    systemImage: "building.columns"
                                )
                                .lineLimit(1)

                                if let linkStatus = draft.linkStatus {
                                    Label(
                                        linkStatus.capitalized,
                                        systemImage: "link"
                                    )
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            Button("Review & publish") {
                                selectedDraft = draft
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("Data reliability queue") {
                HStack(spacing: 12) {
                    AdminMetric(
                        value: "\(pendingDeadlineChanges)",
                        label: "Deadline"
                    )
                    AdminMetric(
                        value: "\(pendingCycleChanges)",
                        label: "Cycle"
                    )
                    AdminMetric(
                        value: "\(brokenLinkIssueCount)",
                        label: "Broken"
                    )
                    AdminMetric(
                        value: "\(staleIssueCount)",
                        label: "Stale"
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

                if expiredIssueCount > 0 {
                    Label(
                        "\(expiredIssueCount) expired deadline issue(s)",
                        systemImage: "calendar.badge.exclamationmark"
                    )
                    .font(.caption.weight(.semibold))
                }

                if detectedChanges.isEmpty {
                    Text("No detected changes waiting for review.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detectedChanges.prefix(20)) { change in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(scholarshipTitle(for: change.scholarshipId))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)

                            HStack {
                                Text(
                                    change.fieldName
                                        .replacingOccurrences(
                                            of: "_",
                                            with: " "
                                        )
                                        .capitalized
                                )
                                .font(.caption.weight(.semibold))

                                Spacer()

                                if let confidence = change.confidence {
                                    Text("\(confidence)% confidence")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if change.oldValue != change.detectedValue {
                                Text(
                                    "\(change.oldValue ?? "Not set") → " +
                                    "\(change.detectedValue ?? "Not detected")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            if let url = URL(string: change.sourceUrl) {
                                Link(destination: url) {
                                    Label(
                                        "Open official source",
                                        systemImage: "arrow.up.right.square"
                                    )
                                    .font(.caption)
                                }
                            }

                            HStack {
                                Button("Accept") {
                                    Task {
                                        await reviewDetectedChange(
                                            change,
                                            accept: true
                                        )
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))

                                Button("Reject", role: .destructive) {
                                    Task {
                                        await reviewDetectedChange(
                                            change,
                                            accept: false
                                        )
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !healthIssues.isEmpty {
                    DisclosureGroup("Open catalog health issues") {
                        ForEach(healthIssues.prefix(20)) { issue in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scholarshipTitle(for: issue.scholarshipId))
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(2)

                                Text(
                                    issue.issueType
                                        .replacingOccurrences(
                                            of: "_",
                                            with: " "
                                        )
                                        .capitalized
                                )
                                .font(.caption2.weight(.semibold))

                                Text(issue.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            Section("Recent source observations") {
                HStack(spacing: 12) {
                    AdminMetric(
                        value: "\(auditObservations.count)",
                        label: "Checks"
                    )
                    AdminMetric(
                        value: "\(recentAuditFailures)",
                        label: "Failures"
                    )
                    AdminMetric(
                        value: "\(recentSourceChanges)",
                        label: "Changes"
                    )
                    AdminMetric(
                        value: "\(recentAmbiguousDeadlines)",
                        label: "Ambiguous"
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

                if auditObservations.isEmpty {
                    Text("No audit observations recorded yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(auditObservations.prefix(20)) { observation in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(
                                    scholarshipTitle(
                                        for: observation.scholarshipId
                                    )
                                )
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)

                                Spacer()

                                Text(
                                    observation.outcome
                                        .replacingOccurrences(
                                            of: "_",
                                            with: " "
                                        )
                                        .capitalized
                                )
                                .font(.caption2.weight(.semibold))
                            }

                            HStack(spacing: 10) {
                                if let status = observation.httpStatus {
                                    Text("HTTP \(status)")
                                }

                                if observation.sourceChanged {
                                    Label(
                                        "Source changed",
                                        systemImage: "arrow.triangle.2.circlepath"
                                    )
                                }

                                if observation.deadlineAmbiguous {
                                    Label(
                                        "Multiple deadlines",
                                        systemImage: "calendar.badge.exclamationmark"
                                    )
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            if let error = observation.auditError,
                               !error.isEmpty {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            if let url = observation.finalUrl,
                               let sourceURL = URL(string: url) {
                                Link("Open checked source", destination: sourceURL)
                                    .font(.caption2.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("Official source discoveries") {
                if sourceCandidates.isEmpty {
                    Text("No new official-source links waiting for review.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sourceCandidates.prefix(20)) { candidate in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(
                                candidate.candidateTitle?
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                    .nonEmpty
                                    ?? candidate.source?.displayName
                                    ?? "Official source candidate"
                            )
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)

                            HStack {
                                Text(
                                    candidate.source?.host
                                        ?? "Official source"
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                                Spacer()

                                Text("\(candidate.relevanceScore)% relevance")
                                    .font(.caption2.weight(.semibold))
                            }

                            if let url = URL(
                                string: candidate.candidateUrl
                            ) {
                                Link(destination: url) {
                                    Label(
                                        "Open discovered page",
                                        systemImage: "arrow.up.right.square"
                                    )
                                    .font(.caption)
                                }
                            }

                            HStack {
                                Button("Create draft") {
                                    Task {
                                        await reviewSourceCandidate(
                                            candidate,
                                            status: "accepted"
                                        )
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))

                                Button("Ignore") {
                                    Task {
                                        await reviewSourceCandidate(
                                            candidate,
                                            status: "ignored"
                                        )
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))

                                Button("Reject", role: .destructive) {
                                    Task {
                                        await reviewSourceCandidate(
                                            candidate,
                                            status: "rejected"
                                        )
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 4)
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

            if !actionLogs.isEmpty {
                Section("Recent admin activity") {
                    ForEach(actionLogs.prefix(10)) { log in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                log.action
                                    .replacingOccurrences(
                                        of: "_",
                                        with: " "
                                    )
                                    .capitalized
                            )
                            .font(.caption.weight(.semibold))

                            Text(
                                "\(log.targetType.capitalized) · " +
                                "\(log.targetIds.count) item(s)"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            Text(String(log.createdAt.prefix(16)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
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
        .sheet(isPresented: $showingImport) {
            ScholarshipImportView {
                Task { await load() }
            }
        }
        .sheet(item: $selectedDraft) { draft in
            DraftScholarshipReviewView(
                scholarship: draft
            ) {
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
            async let healthSummary =
                DataService.adminSystemHealth()
            async let logs =
                DataService.recentAdminActionLogs(limit: 20)
            async let imports =
                DataService.scholarshipImportBatches(limit: 20)
            async let pendingChanges =
                DataService.pendingScholarshipDetectedChanges(limit: 50)
            async let openHealth =
                DataService.openCatalogHealthIssues(limit: 100)
            async let sourceDiscoveryRows =
                DataService.pendingScholarshipSourceCandidates(limit: 50)
            async let observationRows =
                DataService.recentScholarshipAuditObservations(limit: 80)

            scholarships = try await scholarshipRows
            reports = try await reportRows
            analytics = try await analyticsSummary
            systemHealth = try await healthSummary
            actionLogs = try await logs
            importBatches = try await imports
            detectedChanges = try await pendingChanges
            healthIssues = try await openHealth
            sourceCandidates = try await sourceDiscoveryRows
            auditObservations = try await observationRows
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    @MainActor
    private func bulkUpdate(
        ids: [UUID],
        action: String
    ) async {
        guard !ids.isEmpty else {
            bulkMessage = "No matching records."
            return
        }

        bulkOperating = true
        bulkMessage = nil
        defer { bulkOperating = false }

        do {
            let affected = try await DataService
                .adminBulkUpdateScholarships(
                    ids: ids,
                    action: action
                )

            bulkMessage =
                "\(affected) scholarship(s) updated."

            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func commitImport(
        _ batch: ScholarshipImportBatch
    ) async {
        do {
            let result = try await DataService
                .commitScholarshipImport(batchId: batch.id)

            bulkMessage =
                "Import committed: \(result.inserted) inserted, " +
                "\(result.updated) updated, \(result.skipped) skipped."

            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func rollbackImport(
        _ batch: ScholarshipImportBatch
    ) async {
        do {
            let result = try await DataService
                .rollbackScholarshipImport(batchId: batch.id)

            bulkMessage =
                "Import rolled back: \(result.removed) removed, " +
                "\(result.restored) restored."

            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func reviewSourceCandidate(
        _ candidate: ScholarshipSourceCandidate,
        status: String
    ) async {
        do {
            try await DataService.reviewScholarshipSourceCandidate(
                id: candidate.id,
                status: status
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func reviewDetectedChange(
        _ change: ScholarshipDetectedChange,
        accept: Bool
    ) async {
        do {
            if accept {
                try await DataService.acceptDetectedScholarshipChange(
                    id: change.id
                )
            } else {
                try await DataService.rejectDetectedScholarshipChange(
                    id: change.id
                )
            }

            await load()
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

struct AdminPeopleView: View {
    @State private var users: [AdminUserAccount] = []
    @State private var query = ""
    @State private var loading = true
    @State private var workingUserID: UUID?
    @State private var errorMessage: String?

    private var filteredUsers: [AdminUserAccount] {
        let trimmed = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !trimmed.isEmpty else { return users }

        return users.filter { user in
            [
                user.fullName ?? "",
                user.email ?? "",
                user.role,
                user.advisorStatus ?? "",
                user.advisorTitle ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(trimmed)
        }
    }

    private var pendingAdvisorCount: Int {
        users.filter { $0.advisorStatus == "pending" }.count
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    AdminMetric(
                        value: "\(users.filter { $0.role == "student" }.count)",
                        label: "Students"
                    )
                    AdminMetric(
                        value: "\(users.filter { $0.role == "advisor" }.count)",
                        label: "Advisors"
                    )
                    AdminMetric(
                        value: "\(pendingAdvisorCount)",
                        label: "Pending"
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
            }

            Section("Advisor review") {
                NavigationLink {
                    AdminAdvisorApplicationsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundStyle(Theme.accent)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Advisor applications")
                                .font(.subheadline.weight(.semibold))

                            Text(
                                pendingAdvisorCount == 0
                                    ? L10n.string(
                                        "No applications waiting for review"
                                    )
                                    : L10n.format(
                                        "%d application(s) waiting",
                                        pendingAdvisorCount
                                    )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                TextField("Search people", text: $query)
                    .textInputAutocapitalization(.never)
            }

            if loading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if filteredUsers.isEmpty {
                Section {
                    Text("No matching accounts.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Accounts") {
                    ForEach(filteredUsers) { user in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(user.fullName?.nonEmpty ?? user.email ?? "User")
                                        .font(.subheadline.weight(.semibold))

                                    if let email = user.email,
                                       email != user.fullName {
                                        Text(email)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(
                                    L10n.string(
                                        user.role.capitalized
                                    )
                                )
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            if let advisorStatus = user.advisorStatus {
                                HStack(spacing: 7) {
                                    Label(
                                        localizedAdvisorStatus(
                                            advisorStatus
                                        ),
                                        systemImage: advisorStatus == "approved"
                                            ? "checkmark.seal.fill"
                                            : "clock.badge.questionmark"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        advisorStatus == "approved"
                                            ? .green
                                            : advisorStatus == "rejected"
                                                ? .red
                                                : .orange
                                    )

                                    if let title = user.advisorTitle?.nonEmpty {
                                        Text("· \(title)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            if user.isSuspended {
                                Label(
                                    "Account suspended",
                                    systemImage: "lock.fill"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                            }

                            Menu {
                                if user.advisorStatus == "pending" {
                                    Button("Approve advisor") {
                                        Task {
                                            await reviewAdvisor(
                                                user,
                                                action: "approve"
                                            )
                                        }
                                    }

                                    Button("Reject advisor", role: .destructive) {
                                        Task {
                                            await reviewAdvisor(
                                                user,
                                                action: "reject"
                                            )
                                        }
                                    }
                                }

                                if user.advisorStatus == "approved" {
                                    Button("Suspend advisor") {
                                        Task {
                                            await reviewAdvisor(
                                                user,
                                                action: "suspend"
                                            )
                                        }
                                    }
                                }

                                if user.advisorStatus == "suspended" {
                                    Button("Restore advisor") {
                                        Task {
                                            await reviewAdvisor(
                                                user,
                                                action: "restore"
                                            )
                                        }
                                    }
                                }

                                Divider()

                                if user.isSuspended {
                                    Button("Restore account") {
                                        Task {
                                            await setSuspended(
                                                user,
                                                suspended: false
                                            )
                                        }
                                    }
                                } else {
                                    Button(
                                        "Suspend account",
                                        role: .destructive
                                    ) {
                                        Task {
                                            await setSuspended(
                                                user,
                                                suspended: true
                                            )
                                        }
                                    }
                                }
                            } label: {
                                Label(
                                    workingUserID == user.id
                                        ? "Updating…"
                                        : "Manage",
                                    systemImage: "ellipsis.circle"
                                )
                                .font(.caption.weight(.semibold))
                            }
                            .disabled(workingUserID != nil)
                        }
                        .padding(.vertical, 4)
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
        .navigationTitle("Students & Advisors")
        .refreshable { await load() }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            users = try await DataService.adminUserAccounts()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func reviewAdvisor(
        _ user: AdminUserAccount,
        action: String
    ) async {
        workingUserID = user.id
        defer { workingUserID = nil }

        do {
            try await DataService.adminReviewAdvisor(
                userId: user.id,
                action: action
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func setSuspended(
        _ user: AdminUserAccount,
        suspended: Bool
    ) async {
        workingUserID = user.id
        defer { workingUserID = nil }

        do {
            try await DataService.adminSetAccountSuspended(
                userId: user.id,
                suspended: suspended
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AdminAdvisorApplicationsView: View {
    @State private var applications: [AdvisorApplicationProfile] = []
    @State private var filter = "pending"
    @State private var loading = true
    @State private var errorMessage: String?

    private let filters = [
        "pending",
        "changes_requested",
        "approved",
        "rejected",
        "suspended"
    ]

    private var filtered: [AdvisorApplicationProfile] {
        applications.filter { $0.approvalStatus == filter }
    }

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $filter) {
                    ForEach(filters, id: \.self) { status in
                        Text(localizedAdvisorStatus(status))
                            .tag(status)
                    }
                }
                .pickerStyle(.menu)
            }

            if loading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if filtered.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No applications",
                        systemImage: "person.crop.circle.badge.checkmark",
                        description: Text(
                            L10n.format(
                                "There are no %@ advisor applications.",
                                localizedAdvisorStatus(filter)
                                    .lowercased()
                            )
                        )
                    )
                }
            } else {
                Section {
                    ForEach(filtered) { application in
                        NavigationLink {
                            AdminAdvisorReviewView(
                                application: application,
                                onUpdated: {
                                    await load()
                                }
                            )
                        } label: {
                            advisorRow(application)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .navigationTitle("Advisor Applications")
        .refreshable { await load() }
        .task { await load() }
    }

    private func advisorRow(
        _ application: AdvisorApplicationProfile
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceRaised)

                if let value = application.avatarUrl,
                   let url = URL(string: value) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .foregroundStyle(Theme.muted)
                        }
                    }
                } else {
                    Image(systemName: "person.fill")
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    application.displayName?.nonEmpty
                        ?? "Advisor applicant"
                )
                .font(.subheadline.weight(.semibold))

                Text(
                    [
                        application.title,
                        application.organization
                    ]
                    .compactMap { $0?.nonEmpty }
                    .joined(separator: " · ")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

                Text(
                    application.specialties
                        .prefix(3)
                        .joined(separator: " · ")
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Text("v\(application.applicationVersion)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 3)
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            applications =
                try await DataService.adminAdvisorApplications()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AdminAdvisorReviewView: View {
    let application: AdvisorApplicationProfile
    let onUpdated: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reviewNote = ""
    @State private var workingAction: String?
    @State private var errorMessage: String?
    @State private var showActionConfirmation: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.surfaceRaised)

                        if let value = application.avatarUrl,
                           let url = URL(string: value) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(width: 78, height: 78)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            application.displayName?.nonEmpty
                                ?? "Advisor applicant"
                        )
                        .font(.title3.bold())

                        if let title = application.title?.nonEmpty {
                            Text(title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.accentSoft)
                        }

                        if let org = application.organization?.nonEmpty {
                            Text(org)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Background") {
                if let summary = application.shortBio?.nonEmpty {
                    Text(summary)
                        .font(.subheadline.weight(.semibold))
                }

                Text(
                    application.bio?.nonEmpty
                        ?? "No background provided."
                )

                if let approach =
                    application.mentoringApproach?.nonEmpty {
                    LabeledContent("How they help") {
                        Text(approach)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if let years = application.yearsExperience {
                    LabeledContent(
                        "Experience",
                        value: "\(years) years"
                    )
                }
            }

            Section("Expertise") {
                advisorList(
                    "Specialties",
                    application.specialties
                )
                advisorList(
                    "Countries",
                    application.countries
                )
                advisorList(
                    "Languages",
                    application.languages
                )
            }

            Section("Introduction video") {
                if let value = application.introVideoUrl,
                   let url = URL(string: value) {
                    Link(destination: url) {
                        Label(
                            "Open introduction video",
                            systemImage: "play.rectangle.fill"
                        )
                    }
                } else {
                    Label(
                        "No introduction video",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(Theme.danger)
                }
            }

            if application.linkedinUrl?.nonEmpty != nil ||
                application.websiteUrl?.nonEmpty != nil {
                Section("Verification links") {
                    if let value = application.linkedinUrl,
                       let url = URL(string: value) {
                        Link("LinkedIn", destination: url)
                    }

                    if let value = application.websiteUrl,
                       let url = URL(string: value) {
                        Link("Website", destination: url)
                    }
                }
            }

            Section("Admin note") {
                TextEditor(text: $reviewNote)
                    .frame(minHeight: 90)

                Text(
                    "A note is required when requesting changes or rejecting an application."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Decision") {
                if application.approvalStatus == "pending" ||
                    application.approvalStatus == "changes_requested" {
                    Button {
                        showActionConfirmation = "approve"
                    } label: {
                        Label(
                            "Approve & publish",
                            systemImage: "checkmark.seal.fill"
                        )
                    }
                    .tint(.green)

                    Button {
                        showActionConfirmation = "request_changes"
                    } label: {
                        Label(
                            "Request changes",
                            systemImage: "pencil.circle"
                        )
                    }

                    Button(role: .destructive) {
                        showActionConfirmation = "reject"
                    } label: {
                        Label(
                            "Reject application",
                            systemImage: "xmark.circle"
                        )
                    }
                }

                if application.approvalStatus == "approved" {
                    Button(role: .destructive) {
                        showActionConfirmation = "suspend"
                    } label: {
                        Label(
                            "Suspend advisor",
                            systemImage: "pause.circle"
                        )
                    }
                }

                if application.approvalStatus == "suspended" {
                    Button {
                        showActionConfirmation = "restore"
                    } label: {
                        Label(
                            "Restore advisor",
                            systemImage: "arrow.counterclockwise.circle"
                        )
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .navigationTitle("Review Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(workingAction != nil)
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { showActionConfirmation != nil },
                set: {
                    if !$0 {
                        showActionConfirmation = nil
                    }
                }
            )
        ) {
            if let action = showActionConfirmation {
                Button(
                    actionTitle(action),
                    role: action == "reject" ||
                        action == "suspend"
                        ? .destructive
                        : nil
                ) {
                    Task { await perform(action) }
                }

                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var confirmationTitle: String {
        guard let action = showActionConfirmation else {
            return "Review advisor"
        }

        return actionTitle(action) + "?"
    }

    private func actionTitle(_ action: String) -> String {
        switch action {
        case "approve":
            return L10n.string("Approve & publish")
        case "request_changes":
            return L10n.string("Request changes")
        case "reject":
            return L10n.string("Reject application")
        case "suspend":
            return L10n.string("Suspend advisor")
        case "restore":
            return L10n.string("Restore advisor")
        default:
            return L10n.string("Continue")
        }
    }

    private func advisorList(
        _ label: String,
        _ values: [String]
    ) -> some View {
        LabeledContent(label) {
            Text(
                values.isEmpty
                    ? "Not provided"
                    : values.joined(separator: " · ")
            )
            .multilineTextAlignment(.trailing)
        }
    }

    @MainActor
    private func perform(
        _ action: String
    ) async {
        if ["request_changes", "reject"].contains(action) &&
            reviewNote
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty {
            errorMessage = L10n.string(
                "Please add a clear note for the advisor first."
            )
            showActionConfirmation = nil
            return
        }

        workingAction = action
        defer { workingAction = nil }

        do {
            try await DataService.adminReviewAdvisor(
                userId: application.id,
                action: action,
                note: reviewNote
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .nonEmpty
            )
            await onUpdated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private func localizedAdvisorStatus(
    _ status: String
) -> String {
    switch status {
    case "changes_requested":
        return L10n.string("Changes Requested")
    case "approved":
        return L10n.string("Approved")
    case "rejected":
        return L10n.string("Rejected")
    case "suspended":
        return L10n.string("Suspended")
    default:
        return L10n.string("Pending")
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
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
                    Button("Save Draft") {
                        Task { await saveDraft() }
                    }
                }
            }
        }
    }

    @MainActor
    private func saveDraft() async {
        let parsedDegreeLevels = degreeLevels
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(
                    in: .whitespaces
                )
            }
        let parsedFields = fields
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(
                    in: .whitespaces
                )
            }

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

            try await DataService.createScholarshipDraft(
                slug: slug,
                title: title,
                provider: provider,
                country: country,
                region: region,
                fundingType: funding,
                officialURL: url,
                degreeLevels: parsedDegreeLevels,
                fields: parsedFields
            )

            onCreated()
            dismiss()
        } catch let err {
            error = err.localizedDescription
        }
    }
}


struct ScholarshipImportView: View {
    @Environment(\.dismiss) private var dismiss

    let onStaged: () -> Void

    @State private var format = "csv"
    @State private var sourceLabel = ""
    @State private var sourceURL = ""
    @State private var content = ""
    @State private var staging = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Format", selection: $format) {
                    Text("CSV").tag("csv")
                    Text("JSON").tag("json")
                }
                .pickerStyle(.segmented)

                TextField("Source label", text: $sourceLabel)
                TextField("Source URL (optional)", text: $sourceURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                Section("Import content") {
                    TextEditor(text: $content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 260)
                }

                Section {
                    Text(
                        format == "csv"
                            ? "CSV headers should use scholarship field names such as title, provider, country, funding_type, official_url, degree_levels and fields. Use | or ; inside array fields."
                            : "JSON must be an array of scholarship objects."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Import scholarships")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(staging ? "Staging…" : "Preview") {
                        Task { await stage() }
                    }
                    .disabled(
                        staging ||
                        sourceLabel.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty ||
                        content.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
        }
    }

    @MainActor
    private func stage() async {
        staging = true
        errorMessage = nil
        defer { staging = false }

        do {
            _ = try await DataService.stageScholarshipImport(
                format: format,
                content: content,
                sourceLabel: sourceLabel,
                sourceURL: sourceURL.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty ? nil : sourceURL
            )

            onStaged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
