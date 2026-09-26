import SwiftUI

struct ScholarshipDetailView: View {
    let scholarship: Scholarship
    let match: ScholarshipMatch?

    @State private var saved = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var selectedTab = "Overview"

    private var verified: Bool {
        scholarship.verificationStatus == "verified"
    }

    private let tabs = ["Overview", "Eligibility", "Benefits", "Application"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                headerContent
                tabBar

                VStack(alignment: .leading, spacing: 18) {
                    if selectedTab == "Overview" {
                        overviewContent
                    } else if selectedTab == "Eligibility" {
                        eligibilityContent
                    } else if selectedTab == "Benefits" {
                        benefitsContent
                    } else {
                        applicationContent
                    }
                }
                .padding()
                .padding(.bottom, 90)
            }
        }
        .background(Theme.pageBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.navyDeep.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await toggleSaved() }
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(saved ? Theme.blue : .white)
                }
                .disabled(busy)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomAction
        }
        .task { await loadSaved() }
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

    private var heroImage: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(
                seed: scholarship.provider + scholarship.title + scholarship.country,
                height: 235
            )

            LinearGradient(
                colors: [.clear, Theme.navyDeep.opacity(0.96)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 150)

            HStack {
                FundingBadge(text: scholarship.fundingType)
                Spacer()
            }
            .padding(16)
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(scholarship.title)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white)

            Text(scholarship.provider)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))

            Label(scholarship.country, systemImage: "mappin.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(scholarship.degreeLevels.prefix(3), id: \.self) { level in
                        DetailPill(text: level)
                    }
                    DetailPill(text: scholarship.fields.first ?? "All fields")
                    DetailPill(text: scholarship.fundingType)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedTab == tab ? Theme.blueSoft : .white.opacity(0.55))

                            Rectangle()
                                .fill(selectedTab == tab ? Theme.blue : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private var overviewContent: some View {
        if let description = scholarship.description,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DetailSection(title: "About") {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.70))
                    .lineSpacing(4)
            }
        }

        DetailSection(title: "At a glance") {
            VStack(spacing: 13) {
                DetailLine(label: "Provider", value: scholarship.provider)
                DetailLine(label: "Country", value: scholarship.country)
                DetailLine(
                    label: "Deadline",
                    value: scholarship.deadline ?? "Varies / to be announced"
                )
                DetailLine(
                    label: "Source",
                    value: verified ? "Verified" : "Curated"
                )
            }
        }

        if let match {
            DetailSection(title: "Your match") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(match.eligible ? "\(match.score)% profile match" : "Review eligibility")
                        .font(.title3.bold())
                        .foregroundStyle(match.eligible ? Theme.blueSoft : Theme.danger)

                    ForEach(match.reasons, id: \.self) { reason in
                        Label(reason, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.green)
                    }

                    ForEach(match.blockers, id: \.self) { blocker in
                        Label(blocker, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
        }
    }

    private var eligibilityContent: some View {
        DetailSection(title: "Eligibility") {
            VStack(spacing: 13) {
                DetailLine(label: "Degree", value: scholarship.degreeLevels.joined(separator: ", "))
                DetailLine(label: "Field", value: scholarship.fields.joined(separator: ", "))
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
    }

    private var benefitsContent: some View {
        DetailSection(title: "What it covers") {
            VStack(spacing: 13) {
                DetailLine(label: "Tuition", value: scholarship.tuitionCoverage ?? scholarship.fundingType)
                DetailLine(label: "Stipend", value: scholarship.stipend ?? "Check official source")
                DetailLine(label: "Airfare", value: scholarship.airfare ? "Included" : "Not listed")
                DetailLine(label: "Accommodation", value: scholarship.accommodation ? "Included" : "Not listed")
                DetailLine(label: "Health insurance", value: scholarship.healthInsurance ? "Included" : "Not listed")
            }
        }
    }

    private var applicationContent: some View {
        DetailSection(title: "Application") {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    scholarship.deadline ?? "Deadline varies / to be announced",
                    systemImage: "calendar"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

                Text("Always confirm the current application cycle, eligibility and required documents on the official scholarship website.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineSpacing(4)

                TrustSeal(verified: verified)

                if let checked = scholarship.lastCheckedAt, !checked.isEmpty {
                    Text("Last checked \(String(checked.prefix(10)))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
        }
    }

    private var bottomAction: some View {
        HStack(spacing: 10) {
            Button {
                Task { await toggleSaved() }
            } label: {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.headline)
                    .frame(width: 50, height: 50)
                    .background(Theme.surfaceRaised)
                    .foregroundStyle(saved ? Theme.blue : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(busy)

            if let url = URL(string: scholarship.officialUrl) {
                Link(destination: url) {
                    Text("Apply now")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.blueGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
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

private struct DetailPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.surfaceRaised)
            .clipShape(Capsule())
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.white)
            content
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.05))
        )
    }
}

struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.56))

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
