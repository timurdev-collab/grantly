import SwiftUI

struct ScholarshipDetailView: View {
    let scholarship: Scholarship
    let match: ScholarshipMatch?

    @State private var saved = false
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    FundingBadge(text: scholarship.fundingType)
                    Spacer()

                    if let match {
                        Text(match.eligible ? "\(match.score)% fit" : "Review eligibility")
                            .font(.caption.bold())
                            .foregroundStyle(match.eligible ? Theme.green : .red)
                    }
                }

                Text(scholarship.title)
                    .font(.largeTitle.bold())

                Text("\(scholarship.provider) · \(scholarship.country)")
                    .foregroundStyle(.secondary)

                if let deadline = scholarship.deadline {
                    Label("Deadline: \(deadline)", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                }

                if let match {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why it matches")
                            .font(.headline)

                        ForEach(match.reasons, id: \.self) {
                            Label($0, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.green)
                        }

                        ForEach(match.blockers, id: \.self) {
                            Label($0, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.subheadline)
                }

                GroupBox("Coverage") {
                    VStack(alignment: .leading, spacing: 10) {
                        DetailLine(label: "Tuition", value: scholarship.tuitionCoverage ?? scholarship.fundingType)
                        DetailLine(label: "Stipend", value: scholarship.stipend ?? "Check official source")
                        DetailLine(label: "Airfare", value: scholarship.airfare ? "Included" : "Not listed")
                        DetailLine(label: "Accommodation", value: scholarship.accommodation ? "Included" : "Not listed")
                        DetailLine(label: "Health insurance", value: scholarship.healthInsurance ? "Included" : "Not listed")
                    }
                    .padding(.top, 4)
                }

                GroupBox("Eligibility snapshot") {
                    VStack(alignment: .leading, spacing: 10) {
                        DetailLine(label: "Degree", value: scholarship.degreeLevels.joined(separator: ", "))
                        DetailLine(label: "Field", value: scholarship.fields.joined(separator: ", "))
                        DetailLine(label: "Minimum GPA", value: scholarship.minGpaPercent.map { "\(Int($0))%" } ?? "Not listed")
                        DetailLine(label: "Minimum IELTS", value: scholarship.minIelts.map { String($0) } ?? "Not listed")
                        DetailLine(label: "SAT", value: scholarship.satRequired ? "Required" : "Not listed as required")
                    }
                    .padding(.top, 4)
                }

                if saved {
                    Button {
                        Task { await toggleSaved() }
                    } label: {
                        Label("Saved to My Scholarships", systemImage: "bookmark.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(busy)
                } else {
                    Button {
                        Task { await toggleSaved() }
                    } label: {
                        Label("Save scholarship", systemImage: "bookmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy)
                }

                if let url = URL(string: scholarship.officialUrl) {
                    Link(destination: url) {
                        Label("Open official scholarship website", systemImage: "safari")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Text("Always verify final eligibility, deadlines and benefits on the official source.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSaved() }
        .alert("Unable to update scholarship", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func loadSaved() async {
        guard let id = try? await supabase.auth.session.user.id else { return }

        do {
            let ids = try await DataService.savedScholarshipIDs(userId: id)
            saved = ids.contains(scholarship.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleSaved() async {
        guard let id = try? await supabase.auth.session.user.id else { return }

        busy = true
        defer { busy = false }

        do {
            try await DataService.setSaved(!saved, userId: id, scholarshipId: scholarship.id)
            saved.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}
