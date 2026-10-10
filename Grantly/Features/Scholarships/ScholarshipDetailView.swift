import SwiftUI

struct ScholarshipDetailView: View {
    let scholarship: Scholarship
    let match: ScholarshipMatch?

    @State private var saved = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var selectedTab = "Overview"
    @State private var trackedView = false
    @State private var showingApplicationWorkspace = false

    private let tabs = ["Overview", "Eligibility", "Benefits", "Application"]

    private var verified: Bool {
        scholarship.verificationStatus == "verified"
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    identity
                    tabsBar

                    VStack(alignment: .leading, spacing: 16) {
                        switch selectedTab {
                        case "Eligibility":
                            eligibilityContent
                        case "Benefits":
                            benefitsContent
                        case "Application":
                            applicationContent
                        default:
                            overviewContent
                        }
                    }
                    .padding()
                    .padding(.bottom, 84)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(
                    width: proxy.size.width,
                    alignment: .leading
                )
                .clipped()
            }
        }
        .background(Theme.premiumIvoryRaised)
        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await toggleSaved() }
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(saved ? Theme.orangeSoft : Theme.ink)
                }
                .disabled(busy)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomAction
        }
        .sheet(isPresented: $showingApplicationWorkspace) {
            ApplicationWorkspaceView(scholarship: scholarship)
        }
        .task {
            await loadSaved()

            if !trackedView {
                trackedView = true
                try? await DataService.trackProductEvent(
                    "scholarship_view",
                    scholarshipId: scholarship.id,
                    properties: [
                        "provider": scholarship.provider,
                        "country": scholarship.country
                    ]
                )
            }
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

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(
                seed: scholarship.provider + scholarship.title + scholarship.country,
                remoteURL: scholarship.university?.campusImageUrl,
                height: 310
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.16),
                    Theme.premiumForest.opacity(0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let match {
                        Text("\(match.score)% match")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.premiumForest)
                            .padding(.horizontal, 11)
                            .frame(height: 29)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    } else if verified {
                        Text(L10n.string("Verified"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.premiumForest)
                            .padding(.horizontal, 11)
                            .frame(height: 29)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }

                Spacer()

                Text(scholarship.title)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .tracking(-0.7)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(scholarship.university?.name ?? scholarship.provider)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .padding(18)
        }
        .frame(height: 310)
        .clipped()
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                UniversityLogo(
                    university: scholarship.university,
                    fallbackName: scholarship.provider,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(scholarship.university?.name ?? scholarship.provider)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    Label(
                        scholarship.country,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)

                    if let deadline = scholarship.deadline {
                        HStack(spacing: 6) {
                            Text("Deadline")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.muted)

                            Text(String(deadline.prefix(10)))
                                .font(.caption2.bold())
                                .foregroundStyle(Theme.orangeSoft)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(scholarship.degreeLevels.prefix(3), id: \.self) { level in
                        DetailPill(icon: "graduationcap", text: level)
                    }

                    if let field = scholarship.fields.first {
                        DetailPill(icon: "books.vertical", text: field)
                    }

                    DetailPill(icon: "banknote", text: scholarship.fundingType)
                }
            }

            if let match {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Theme.ink.opacity(0.08), lineWidth: 5)

                        Circle()
                            .trim(from: 0, to: CGFloat(max(0, min(match.score, 100))) / 100)
                            .stroke(
                                match.eligible ? Theme.blue : Theme.danger,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Text("\(match.score)")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(match.eligible ? "Strong profile fit" : "Check eligibility")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.ink)

                        Text(match.eligible ? "Based on your current academic profile" : "One or more requirements may need attention")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.premiumIvoryRaised)
    }

    private var tabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedTab == tab ? .white : Theme.ink.opacity(0.56))
                            .padding(.horizontal, 13)
                            .frame(height: 36)
                            .background(selectedTab == tab ? Theme.blue : Theme.surface)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var overviewContent: some View {
        if let description = scholarship.description,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DetailSection(title: "About", icon: "text.alignleft") {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(4)
            }
        }

        DetailSection(title: "At a glance", icon: "sparkles.rectangle.stack") {
            VStack(spacing: 13) {
                DetailLine(
                    label: "Provider",
                    value: scholarship.university?.name ?? scholarship.provider
                )

                if let institutionType = scholarship.university?.entityType {
                    DetailLine(
                        label: "Provider type",
                        value: institutionType
                            .replacingOccurrences(of: "_", with: " ")
                            .capitalized
                    )
                }

                DetailLine(label: "Country", value: scholarship.country)
                DetailLine(label: "Deadline", value: scholarship.deadline ?? "Deadline not yet confirmed")
                DetailLine(label: "Funding", value: scholarship.fundingType)
                DetailLine(label: "Source", value: verified ? "Verified" : "Curated")

                if let score = scholarship.reliabilityScore {
                    DetailLine(
                        label: "Data reliability",
                        value: "\(score)/100"
                    )
                }

                if let checked = scholarship.lastCheckedAt,
                   !checked.isEmpty {
                    DetailLine(
                        label: "Last source check",
                        value: String(checked.prefix(10))
                    )
                }
            }
        }

        if let match {
            DetailSection(title: "Why it matches", icon: "person.text.rectangle") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(match.reasons, id: \.self) { reason in
                        Label(reason, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.green)
                    }

                    ForEach(match.blockers, id: \.self) { blocker in
                        Label(blocker, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var eligibilityContent: some View {
        DetailSection(title: "Eligibility", icon: "checkmark.seal") {
            VStack(spacing: 13) {
                DetailLine(label: "Degree", value: scholarship.degreeLevels.joined(separator: ", "))
                DetailLine(label: "Field", value: scholarship.fields.joined(separator: ", "))
                DetailLine(label: "Minimum GPA", value: scholarship.minGpaPercent.map { "\(Int($0))%" } ?? "Not listed")
                DetailLine(label: "Minimum IELTS", value: scholarship.minIelts.map { String($0) } ?? "Not listed")
                DetailLine(label: "SAT", value: scholarship.satRequired ? "Required" : "Not listed as required")
            }
        }

        DetailSection(title: "Before you apply", icon: "checklist") {
            VStack(alignment: .leading, spacing: 10) {
                GuidanceRow(icon: "person.text.rectangle", text: "Confirm nationality and residency rules on the official source.")
                GuidanceRow(icon: "doc.text", text: "Check the current document list and any nomination requirements.")
                GuidanceRow(icon: "calendar", text: "Verify the application cycle and deadline before preparing documents.")
            }
        }
    }

    private var benefitsContent: some View {
        DetailSection(title: "What it covers", icon: "gift") {
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
        DetailSection(title: "Application", icon: "paperplane") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Current deadline")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)

                        Text(scholarship.deadline ?? "Deadline not yet confirmed")
                            .font(.headline.bold())
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                    }

                    Image(systemName: "calendar")
                        .font(.headline)
                        .foregroundStyle(Theme.orangeSoft)
                        .frame(width: 42, height: 42)
                        .background(Theme.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Always confirm the current cycle, eligibility, documents and deadline on the official scholarship website before submitting.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(4)

                HStack {
                    TrustSeal(verified: verified)

                    if let score = scholarship.reliabilityScore {
                        ReliabilityBadge(score: score)
                    }

                    if let checked = scholarship.lastCheckedAt, !checked.isEmpty {
                        Text("Checked \(String(checked.prefix(10)))")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()

                    if let website = scholarship.university?.websiteUrl,
                       let websiteURL = URL(string: website) {
                        Link(destination: websiteURL) {
                            Label("Provider", systemImage: "building.columns")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.orangeSoft)
                        }
                    }
                }

                Divider()
                    .overlay(Theme.ink.opacity(0.07))

                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "Apply and track in EduT",
                        systemImage: "checklist.checked"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                    Text("Open the official form inside EduT, keep your checklist, confirmation number, notes and progress together, then return to check the official portal status.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)

                    Button {
                        showingApplicationWorkspace = true
                    } label: {
                        Label(
                            "Open application workspace",
                            systemImage: "rectangle.stack.badge.plus"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.orangeSoft)
                    }
                    .buttonStyle(.plain)
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
                    .background(.ultraThinMaterial)
                    .foregroundStyle(
                        saved ? Theme.premiumBrass : Theme.premiumForest
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(busy)

            Button {
                showingApplicationWorkspace = true
            } label: {
                HStack(spacing: 8) {
                    Text("Apply & track in EduT")
                    Image(systemName: "arrow.up.right")
                }
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.premiumForest)
                .foregroundStyle(Theme.premiumIvory)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.premiumInk.opacity(0.05))
                .frame(height: 1)
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
            try await DataService.setSaved(
                !saved,
                userId: id,
                scholarshipId: scholarship.id
            )

            withAnimation(.easeInOut(duration: 0.18)) {
                saved.toggle()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DetailPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.surfaceRaised)
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.orangeSoft)
                    .frame(width: 32, height: 32)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(
            RoundedRectangle(cornerRadius: 19)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct GuidanceRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.orangeSoft)
                .frame(width: 22)

            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .frame(width: 104, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    alignment: .trailing
                )
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
