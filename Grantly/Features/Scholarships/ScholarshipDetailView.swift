import SwiftUI

struct ScholarshipDetailView: View {
    let scholarship: Scholarship
    let match: ScholarshipMatch?

    @State private var saved = false
    @State private var busy = false
    @State private var errorMessage: String?

    private var verified: Bool {
        scholarship.verificationStatus == "verified"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHero

                if let match {
                    matchCard(match)
                }

                if let description = scholarship.description,
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AcademicDetailCard(
                        eyebrow: "Overview",
                        title: "About this opportunity",
                        icon: "book.closed"
                    ) {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                }

                AcademicDetailCard(
                    eyebrow: "Award",
                    title: "What it covers",
                    icon: "banknote"
                ) {
                    VStack(spacing: 13) {
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

                AcademicDetailCard(
                    eyebrow: "Requirements",
                    title: "Eligibility",
                    icon: "checklist"
                ) {
                    VStack(spacing: 13) {
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

                VStack(spacing: 12) {
                    if saved {
                        Button {
                            Task { await toggleSaved() }
                        } label: {
                            Label(
                                "Saved to your shortlist",
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
                                "Save to shortlist",
                                systemImage: "bookmark"
                            )
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(busy)
                    }

                    if let url = URL(string: scholarship.officialUrl) {
                        Link(destination: url) {
                            Label(
                                "Visit official scholarship page",
                                systemImage: "arrow.up.right.square"
                            )
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
            .padding()
        }
        .background(Theme.pageBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSaved()
        }
        .alert(
            "Unable to update scholarship",
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

    private var detailHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                GrantlyMonogram(size: 44, dark: false)

                Spacer()

                TrustSeal(verified: verified)
            }

            SectionEyebrow(text: scholarship.country)

            Text(scholarship.title)
                .font(Theme.serifTitle(33, weight: .medium))
                .tracking(-0.6)
                .foregroundStyle(Theme.parchment)

            Text(scholarship.provider)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 9) {
                FundingBadge(text: scholarship.fundingType)

                ForEach(
                    scholarship.degreeLevels.prefix(2),
                    id: \.self
                ) { level in
                    Text(level)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.08))
                        .foregroundStyle(.white.opacity(0.78))
                        .clipShape(Capsule())
                }
            }

            Rectangle()
                .fill(Theme.brass.opacity(0.45))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 18) {
                if let deadline = scholarship.deadline {
                    DetailHeroMetric(
                        label: "NEXT DEADLINE",
                        value: deadline
                    )
                } else {
                    DetailHeroMetric(
                        label: "DEADLINE",
                        value: "Varies / TBA"
                    )
                }

                if let cycle = scholarship.applicationCycle,
                   !cycle.isEmpty {
                    DetailHeroMetric(
                        label: "CYCLE",
                        value: cycle
                    )
                }
            }

            if let notes = scholarship.deadlineNotes,
               !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineSpacing(3)
            }
        }
        .padding(20)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.brass.opacity(0.18))
        )
    }

    @ViewBuilder
    private func matchCard(_ match: ScholarshipMatch) -> some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                AcademicSectionHeader(
                    eyebrow: "Personal fit",
                    title: match.eligible
                        ? "\(match.score)% match"
                        : "Review eligibility"
                )

                ForEach(match.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.forest)
                }

                ForEach(match.blockers, id: \.self) { blocker in
                    Label(blocker, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.oxblood)
                }
            }
        }
    }

    private var sourceCard: some View {
        AcademicDetailCard(
            eyebrow: "Transparency",
            title: "Source quality",
            icon: "seal"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TrustSeal(verified: verified)

                Text(
                    verified
                        ? "This record has been checked against the linked source."
                        : "This record comes from a curated source. Confirm current details before applying."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let checked = scholarship.lastCheckedAt,
                   !checked.isEmpty {
                    Text("Last checked \(String(checked.prefix(10)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @MainActor
    private func loadSaved() async {
        guard let id = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let ids = try await DataService.savedScholarshipIDs(userId: id)
            saved = ids.contains(scholarship.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleSaved() async {
        guard let id = try? await supabase.auth.session.user.id else {
            return
        }

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

private struct DetailHeroMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.48))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.parchment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AcademicDetailCard<Content: View>: View {
    let eyebrow: String
    let title: String
    let icon: String
    let content: Content

    init(
        eyebrow: String,
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionEyebrow(text: eyebrow)

                        Text(title)
                            .font(Theme.serifTitle(22))
                            .foregroundStyle(Theme.ink)
                    }

                    Spacer()

                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(Theme.brass)
                        .frame(width: 36, height: 36)
                        .background(Theme.parchment)
                        .clipShape(Circle())
                }

                content
            }
        }
    }
}

struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 14)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

