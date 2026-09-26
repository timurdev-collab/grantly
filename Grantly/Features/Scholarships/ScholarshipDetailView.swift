import SwiftUI

struct ScholarshipDetailView: View {
    let scholarship: Scholarship
    let match: ScholarshipMatch?

    @State private var saved = false
    @State private var busy = false
    @State private var errorMessage: String?

    private var isVerified: Bool {
        scholarship.verificationStatus == "verified"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero

                if let match {
                    matchSection(match)
                }

                if let description = scholarship.description,
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detailCard(title: "About", icon: "text.alignleft") {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                detailCard(title: "Funding", icon: "banknote.fill") {
                    VStack(spacing: 12) {
                        DetailLine(
                            label: "Tuition",
                            value: scholarship.tuitionCoverage ?? scholarship.fundingType
                        )
                        DetailLine(
                            label: "Stipend",
                            value: scholarship.stipend ?? "Check official source"
                        )
                        DetailLine(
                            label: "Airfare",
                            value: scholarship.airfare ? "Included" : "Not listed"
                        )
                        DetailLine(
                            label: "Accommodation",
                            value: scholarship.accommodation ? "Included" : "Not listed"
                        )
                        DetailLine(
                            label: "Health insurance",
                            value: scholarship.healthInsurance ? "Included" : "Not listed"
                        )
                    }
                }

                detailCard(title: "Eligibility", icon: "checklist") {
                    VStack(spacing: 12) {
                        DetailLine(
                            label: "Degree",
                            value: scholarship.degreeLevels.joined(separator: ", ")
                        )
                        DetailLine(
                            label: "Field",
                            value: scholarship.fields.joined(separator: ", ")
                        )
                        DetailLine(
                            label: "Minimum GPA",
                            value: scholarship.minGpaPercent.map { "\(Int($0))%" } ?? "Not listed"
                        )
                        DetailLine(
                            label: "Minimum IELTS",
                            value: scholarship.minIelts.map { String($0) } ?? "Not listed"
                        )
                        DetailLine(
                            label: "SAT",
                            value: scholarship.satRequired ? "Required" : "Not listed as required"
                        )
                    }
                }

                sourceCard

                if saved {
                    Button {
                        Task { await toggleSaved() }
                    } label: {
                        Label(
                            "Saved to My Scholarships",
                            systemImage: "bookmark.fill"
                        )
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(busy)
                } else {
                    Button {
                        Task { await toggleSaved() }
                    } label: {
                        Label(
                            "Save scholarship",
                            systemImage: "bookmark"
                        )
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy)
                }

                if let url = URL(string: scholarship.officialUrl) {
                    Link(destination: url) {
                        Label(
                            "Open official source",
                            systemImage: "safari"
                        )
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FundingBadge(text: scholarship.fundingType)
                Spacer()
                TrustBadge(verified: isVerified)
            }

            Text(scholarship.title)
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)

            Text(scholarship.provider)
                .font(.headline)
                .foregroundStyle(.secondary)

            Label(
                "\(scholarship.country) · \(scholarship.region)",
                systemImage: "mappin.and.ellipse"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let deadline = scholarship.deadline {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .foregroundStyle(Theme.violet)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next deadline")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(deadline)
                            .font(.headline)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.violet.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let cycle = scholarship.applicationCycle,
               !cycle.isEmpty {
                Label(cycle, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let notes = scholarship.deadlineNotes,
               !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, -4)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [.white, Theme.violet.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.black.opacity(0.04))
        )
    }

    @ViewBuilder
    private func matchSection(_ match: ScholarshipMatch) -> some View {
        detailCard(title: "Your match", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(match.eligible ? "\(match.score)% fit" : "Review eligibility")
                        .font(.title3.bold())
                        .foregroundStyle(match.eligible ? Theme.green : .red)
                    Spacer()
                }

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
    }

    private var sourceCard: some View {
        detailCard(title: "Source quality", icon: "checkmark.shield.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TrustBadge(verified: isVerified)

                    if scholarship.linkStatus == "exact" {
                        Label("Exact page", systemImage: "link")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.green)
                    }
                }

                Text(
                    isVerified
                        ? "Grantly checked this record against the linked official source."
                        : "This listing comes from a curated source and should be confirmed on the official page before applying."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let checked = scholarship.lastCheckedAt,
                   !checked.isEmpty {
                    Text("Last checked: \(String(checked.prefix(10)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func detailCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Theme.ink)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.04))
        )
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
            try await DataService.setSaved(
                !saved,
                userId: id,
                scholarshipId: scholarship.id
            )
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
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .multilineTextAlignment(.trailing)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.ink)
        }
        .font(.subheadline)
    }
}
