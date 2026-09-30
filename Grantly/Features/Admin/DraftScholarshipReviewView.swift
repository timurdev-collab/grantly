import SwiftUI

struct DraftScholarshipReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let scholarship: Scholarship
    let onUpdated: () -> Void

    @State private var title: String
    @State private var provider: String
    @State private var country: String
    @State private var region: String
    @State private var degreeLevels: String
    @State private var fields: String
    @State private var fundingType: String
    @State private var tuitionCoverage: String
    @State private var stipend: String
    @State private var eligibleNationalities: String
    @State private var description: String
    @State private var applicationCycle: String
    @State private var deadline: String
    @State private var deadlineNotes: String
    @State private var airfare: Bool
    @State private var accommodation: Bool
    @State private var healthInsurance: Bool
    @State private var satRequired: Bool

    @State private var readiness: ScholarshipDraftReadiness?
    @State private var evidence: ScholarshipDraftSourceEvidence?
    @State private var provenanceHistory: [ScholarshipFieldProvenanceEntry] = []
    @State private var working = false
    @State private var errorMessage: String?

    init(
        scholarship: Scholarship,
        onUpdated: @escaping () -> Void
    ) {
        self.scholarship = scholarship
        self.onUpdated = onUpdated

        _title = State(initialValue: scholarship.title)
        _provider = State(initialValue: scholarship.provider)
        _country = State(initialValue: scholarship.country)
        _region = State(initialValue: scholarship.region)
        _degreeLevels = State(
            initialValue: scholarship.degreeLevels.joined(separator: ", ")
        )
        _fields = State(
            initialValue: scholarship.fields.joined(separator: ", ")
        )
        _fundingType = State(initialValue: scholarship.fundingType)
        _tuitionCoverage = State(initialValue: scholarship.tuitionCoverage ?? "")
        _stipend = State(initialValue: scholarship.stipend ?? "")
        _eligibleNationalities = State(
            initialValue: scholarship.eligibleNationalities.joined(separator: ", ")
        )
        _description = State(initialValue: scholarship.description ?? "")
        _applicationCycle = State(initialValue: scholarship.applicationCycle ?? "")
        _deadline = State(initialValue: scholarship.deadline ?? "")
        _deadlineNotes = State(initialValue: scholarship.deadlineNotes ?? "")
        _airfare = State(initialValue: scholarship.airfare)
        _accommodation = State(initialValue: scholarship.accommodation)
        _healthInsurance = State(initialValue: scholarship.healthInsurance)
        _satRequired = State(initialValue: scholarship.satRequired)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Publication readiness") {
                    if let readiness {
                        Label(
                            readiness.ready
                                ? "Ready to publish"
                                : "\(readiness.blockers.count) blocker(s)",
                            systemImage: readiness.ready
                                ? "checkmark.seal.fill"
                                : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(
                            readiness.ready ? .green : .orange
                        )

                        ForEach(readiness.blockers, id: \.self) { blocker in
                            Label(
                                blocker,
                                systemImage: "xmark.circle"
                            )
                            .font(.caption)
                        }

                        ForEach(readiness.warnings, id: \.self) { warning in
                            Label(
                                warning,
                                systemImage: "exclamationmark.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        if let checked = readiness.lastSuccessfulCheckAt {
                            Text(L10n.format("Source checked %@", String(checked.prefix(10))))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ProgressView("Checking readiness…")
                    }

                    if let url = URL(string: scholarship.officialUrl) {
                        Link(destination: url) {
                            Label(
                                "Open official source",
                                systemImage: "arrow.up.right.square"
                            )
                        }
                    }
                }

                Section("Source evidence") {
                    if let evidence, evidence.available {
                        if let checkedAt = evidence.checkedAt {
                            Text(L10n.format("Extracted %@", String(checkedAt.prefix(10))))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let candidateUrl = evidence.candidateUrl,
                           let url = URL(string: candidateUrl) {
                            Link(destination: url) {
                                Label(
                                    "Open evidence source",
                                    systemImage: "arrow.up.right.square"
                                )
                            }
                        }

                        evidenceRow(
                            title: "Study level",
                            value: evidence.detectedDegreeLevels?
                                .joined(separator: ", "),
                            confidence: evidence.degreeConfidence,
                            excerpt: evidence.eligibilityExcerpt
                        ) {
                            if let levels = evidence.detectedDegreeLevels {
                                degreeLevels = levels.joined(separator: ", ")
                            }
                        }

                        evidenceRow(
                            title: "Funding",
                            value: evidence.detectedFundingType,
                            confidence: evidence.fundingConfidence,
                            excerpt: evidence.fundingExcerpt
                        ) {
                            if let value = evidence.detectedFundingType {
                                fundingType = value
                            }
                        }

                        evidenceRow(
                            title: "Tuition coverage",
                            value: evidence.detectedTuitionCoverage,
                            confidence: evidence.fundingConfidence,
                            excerpt: evidence.benefitsExcerpt
                        ) {
                            if let value = evidence.detectedTuitionCoverage {
                                tuitionCoverage = value
                            }
                        }

                        evidenceRow(
                            title: "Stipend",
                            value: evidence.detectedStipend,
                            confidence: evidence.fundingConfidence,
                            excerpt: evidence.benefitsExcerpt
                        ) {
                            if let value = evidence.detectedStipend {
                                stipend = value
                            }
                        }

                        evidenceRow(
                            title: "Eligible nationalities",
                            value: evidence.detectedEligibleNationalities?
                                .joined(separator: ", "),
                            confidence: evidence.eligibilityConfidence,
                            excerpt: evidence.eligibilityExcerpt
                        ) {
                            if let values = evidence.detectedEligibleNationalities {
                                eligibleNationalities = values.joined(separator: ", ")
                            }
                        }

                        evidenceRow(
                            title: "Deadline",
                            value: evidence.detectedDeadline,
                            confidence: evidence.deadlineConfidence,
                            excerpt: evidence.applicationExcerpt
                        ) {
                            if let value = evidence.detectedDeadline {
                                deadline = value
                            }
                        }

                        evidenceRow(
                            title: "Application cycle",
                            value: evidence.detectedCycle,
                            confidence: evidence.cycleConfidence,
                            excerpt: evidence.applicationExcerpt
                        ) {
                            if let value = evidence.detectedCycle {
                                applicationCycle = value
                            }
                        }

                        evidenceToggleRow(
                            title: "Airfare",
                            detected: evidence.detectedAirfare,
                            excerpt: evidence.benefitsExcerpt
                        ) {
                            airfare = true
                        }

                        evidenceToggleRow(
                            title: "Accommodation",
                            detected: evidence.detectedAccommodation,
                            excerpt: evidence.benefitsExcerpt
                        ) {
                            accommodation = true
                        }

                        evidenceToggleRow(
                            title: "Health insurance",
                            detected: evidence.detectedHealthInsurance,
                            excerpt: evidence.benefitsExcerpt
                        ) {
                            healthInsurance = true
                        }

                        if let requirements = evidence.applicationRequirementsExcerpt,
                           !requirements.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Application requirements evidence")
                                    .font(.caption.weight(.semibold))

                                Text(requirements)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    } else {
                        Text("No structured source evidence is available yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Field provenance") {
                    if provenanceHistory.isEmpty {
                        Text("No accepted field changes recorded yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(provenanceHistory.prefix(30)) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(
                                        entry.fieldName
                                            .replacingOccurrences(of: "_", with: " ")
                                            .capitalized
                                    )
                                    .font(.caption.weight(.semibold))

                                    Spacer()

                                    Text(
                                        entry.provenanceType == "source_extracted"
                                            ? "Source-derived"
                                            : "Manual"
                                    )
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                }

                                Text(
                                    "\(entry.previousValue?.displayText ?? "Not set") → " +
                                    "\(entry.acceptedValue?.displayText ?? "Not set")"
                                )
                                .font(.caption2)

                                if let confidence = entry.confidence {
                                    Text(L10n.format("%d%% source confidence", confidence))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                if let excerpt = entry.evidenceExcerpt,
                                   !excerpt.isEmpty {
                                    Text(excerpt)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }

                                if let sourceUrl = entry.sourceUrl,
                                   let url = URL(string: sourceUrl) {
                                    Link("Open supporting source", destination: url)
                                        .font(.caption2.weight(.semibold))
                                }

                                Text(String(entry.acceptedAt.prefix(16)))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Section("Core information") {
                    TextField("Title", text: $title)
                    TextField("Provider", text: $provider)
                    TextField("Country", text: $country)
                    TextField("Region", text: $region)
                    TextField("Study levels, comma separated", text: $degreeLevels)
                    TextField("Fields, comma separated", text: $fields)
                    TextField("Funding type", text: $fundingType)
                }

                Section("Benefits") {
                    TextField("Tuition coverage", text: $tuitionCoverage)
                    TextField("Stipend", text: $stipend)
                    Toggle("Airfare", isOn: $airfare)
                    Toggle("Accommodation", isOn: $accommodation)
                    Toggle("Health insurance", isOn: $healthInsurance)
                }

                Section("Eligibility") {
                    TextField(
                        "Eligible nationalities, comma separated",
                        text: $eligibleNationalities
                    )
                    Toggle("SAT required", isOn: $satRequired)
                }

                Section("Application cycle") {
                    TextField("Confirmed deadline YYYY-MM-DD", text: $deadline)
                        .textInputAutocapitalization(.never)

                    if let candidate = readiness?.deadlineCandidate,
                       candidate != deadline {
                        Button {
                            deadline = candidate
                        } label: {
                            Text(
                                L10n.format("Use detected deadline %@", candidate) +
                                confidenceText(
                                    readiness?.deadlineConfidence
                                )
                            )
                        }
                    }

                    TextField("Application cycle", text: $applicationCycle)

                    if let candidate = readiness?.cycleCandidate,
                       candidate != applicationCycle {
                        Button {
                            applicationCycle = candidate
                        } label: {
                            Text(
                                L10n.format("Use detected cycle %@", candidate) +
                                confidenceText(
                                    readiness?.cycleConfidence
                                )
                            )
                        }
                    }

                    TextField("Deadline notes", text: $deadlineNotes)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        Label(
                            working ? L10n.string("Saving…") : L10n.string("Save draft"),
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(working)

                    Button {
                        Task { await publish() }
                    } label: {
                        Label(
                            working ? L10n.string("Working…") : L10n.string("Publish scholarship"),
                            systemImage: "checkmark.seal"
                        )
                    }
                    .disabled(
                        working ||
                        readiness?.ready != true
                    )
                }
            }
            .navigationTitle("Review draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await refreshReviewData()
            }
            .alert(
                "Unable to update draft",
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
    }

    @ViewBuilder
    private func evidenceRow(
        title: String,
        value: String?,
        confidence: Int?,
        excerpt: String?,
        use: @escaping () -> Void
    ) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))

                    Spacer()

                    if let confidence {
                        Text("\(confidence)%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(value)
                    .font(.caption)

                if let excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                Button("Use this value", action: use)
                    .font(.caption.weight(.semibold))
            }
            .padding(.vertical, 3)
        }
    }

    @ViewBuilder
    private func evidenceToggleRow(
        title: String,
        detected: Bool?,
        excerpt: String?,
        use: @escaping () -> Void
    ) -> some View {
        if detected == true {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))

                    Spacer()

                    Label("Detected", systemImage: "checkmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                Button("Use detected benefit", action: use)
                    .font(.caption.weight(.semibold))
            }
            .padding(.vertical, 3)
        }
    }

    private func confidenceText(_ confidence: Int?) -> String {
        confidence.map { " " + L10n.format("(%d%% confidence)", $0) } ?? ""
    }

    private func values(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map {
                String($0).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
    }

    @MainActor
    private func refreshReviewData() async {
        do {
            async let readinessTask =
                DataService.scholarshipDraftReadiness(id: scholarship.id)
            async let evidenceTask =
                DataService.scholarshipDraftSourceEvidence(id: scholarship.id)
            async let provenanceTask =
                DataService.scholarshipFieldProvenanceHistory(id: scholarship.id)

            readiness = try await readinessTask
            evidence = try await evidenceTask
            provenanceHistory = try await provenanceTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshReadiness() async {
        do {
            readiness = try await DataService
                .scholarshipDraftReadiness(id: scholarship.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func save() async {
        working = true
        defer { working = false }

        do {
            let patch = ScholarshipDraftPatch(
                title: title,
                provider: provider,
                country: country,
                region: region,
                degreeLevels: values(degreeLevels),
                fields: values(fields),
                fundingType: fundingType,
                tuitionCoverage: tuitionCoverage,
                stipend: stipend,
                airfare: airfare,
                accommodation: accommodation,
                healthInsurance: healthInsurance,
                satRequired: satRequired,
                eligibleNationalities: values(eligibleNationalities),
                description: description,
                applicationCycle: applicationCycle,
                deadline: deadline,
                deadlineNotes: deadlineNotes
            )

            _ = try await DataService.updateScholarshipDraft(
                id: scholarship.id,
                patch: patch
            )

            await refreshReviewData()
            onUpdated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func publish() async {
        working = true
        defer { working = false }

        do {
            _ = try await DataService.publishScholarshipDraft(
                id: scholarship.id
            )
            onUpdated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            await refreshReadiness()
        }
    }
}
