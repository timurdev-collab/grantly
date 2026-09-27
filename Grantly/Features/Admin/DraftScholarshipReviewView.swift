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
                            Text("Source checked \(String(checked.prefix(10)))")
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
                                "Use detected deadline \(candidate)" +
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
                                "Use detected cycle \(candidate)" +
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
                            working ? "Saving…" : "Save draft",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(working)

                    Button {
                        Task { await publish() }
                    } label: {
                        Label(
                            working ? "Working…" : "Publish scholarship",
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
                await refreshReadiness()
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

    private func confidenceText(_ confidence: Int?) -> String {
        confidence.map { " (\($0)% confidence)" } ?? ""
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

            await refreshReadiness()
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
