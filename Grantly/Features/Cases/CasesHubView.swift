import SwiftUI
import UniformTypeIdentifiers

struct CasesHubView: View {
    @State private var segment = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Applications")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                applicationTab(
                    title: "University applications",
                    index: 0,
                    icon: "building.columns"
                )

                applicationTab(
                    title: "Scholarship applications",
                    index: 1,
                    icon: "graduationcap"
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if segment == 0 {
                UniversityCasesView()
            } else {
                MyScholarshipsView()
            }
        }
        .background(Theme.pageBackground)
        .navigationBarHidden(true)
    }

    private func applicationTab(
        title: String,
        index: Int,
        icon: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                segment = index
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .foregroundStyle(
                    segment == index
                        ? Theme.onAccent
                        : Theme.ink
                )
                .background(
                    segment == index
                        ? Theme.ink
                        : Theme.surfaceRaised
                )
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            segment == index ? .isSelected : []
        )
    }
}

struct UniversityCasesView: View {
    @State private var cases: [UniversityApplicationCase] = []
    @State private var loading = true
    @State private var showingCreateCase = false
    @State private var errorMessage: String?
    @State private var caseToDelete: UniversityApplicationCase?

    private var activeCount: Int {
        cases.filter {
            !["Offer", "Rejected", "Withdrawn"].contains(
                $0.applicationStatus
            )
        }.count
    }

    private var submittedCount: Int {
        cases.filter {
            ["Submitted", "Interview", "Offer", "Rejected"].contains(
                $0.applicationStatus
            )
        }.count
    }

    private var offerCount: Int {
        cases.filter { $0.applicationStatus == "Offer" }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                summary

                if loading && cases.isEmpty {
                    ProgressView()
                        .tint(Theme.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 52)
                } else if cases.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(cases) { item in
                            SwipeRevealDeleteRow(
                                cornerRadius: 16,
                                onDelete: {
                                    caseToDelete = item
                                }
                            ) {
                                NavigationLink {
                                    UniversityCaseDetailView(caseId: item.id)
                                } label: {
                                    UniversityCaseCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showingCreateCase, onDismiss: {
            Task { await load() }
        }) {
            CreateUniversityCaseView()
        }
        .alert(
            "University Cases",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            "Delete application?",
            isPresented: Binding(
                get: { caseToDelete != nil },
                set: { if !$0 { caseToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let item = caseToDelete else { return }
                Task { await deleteCase(item) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the application and its uploaded documents.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("University applications")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Text("Universities you are applying to")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            RefreshButton(loading: loading) { await load() }

            Button {
                showingCreateCase = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 42, height: 42)
                    .background(Theme.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add university application")
        }
    }

    private var summary: some View {
        HStack(spacing: 8) {
            UniversityCaseMetric(
                value: "\(activeCount)",
                label: "Active",
                icon: "folder.fill"
            )
            UniversityCaseMetric(
                value: "\(submittedCount)",
                label: "Submitted",
                icon: "paperplane.fill"
            )
            UniversityCaseMetric(
                value: "\(offerCount)",
                label: "Offers",
                icon: "checkmark.seal.fill"
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.orangeSoft)
                .frame(width: 64, height: 64)
                .background(Theme.surface)
                .clipShape(Circle())

            Text("Add your first university application")
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            Text("Choose a university, add the program, then track required documents, missing files, deadlines and status in one place.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button("Add application") {
                showingCreateCase = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            cases = try await DataService.universityApplicationCases()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteCase(_ item: UniversityApplicationCase) async {
        do {
            try await DataService.deleteUniversityCase(caseId: item.id)
            withAnimation(.easeInOut(duration: 0.18)) {
                cases.removeAll { $0.id == item.id }
            }
            caseToDelete = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct UniversityCaseMetric: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Theme.orangeSoft)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct UniversityCaseCard: View {
    let item: UniversityApplicationCase

    var body: some View {
        HStack(spacing: 12) {
            UniversityLogo(
                university: item.university,
                fallbackName: item.university.name,
                size: 52
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(item.university.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)

                    Spacer()

                    Text(item.applicationStatus)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                if !item.programName.isEmpty {
                    Text(item.programName)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    if let degree = item.degreeLevel {
                        Label(degree, systemImage: "graduationcap")
                    }

                    if let intake = item.intake {
                        Label(intake, systemImage: "calendar")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.orangeSoft)
            }
        }
        .padding(13)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var statusColor: Color {
        switch item.applicationStatus {
        case "Offer":
            return Theme.green
        case "Rejected":
            return .orange
        case "Submitted", "Interview":
            return Theme.orangeSoft
        default:
            return .white.opacity(0.62)
        }
    }
}

struct CreateUniversityCaseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var universities: [University] = []
    @State private var search = ""
    @State private var selectedUniversity: University?
    @State private var programName = ""
    @State private var degreeLevel = "Bachelor"
    @State private var intake = ""
    @State private var loading = true
    @State private var creating = false
    @State private var errorMessage: String?

    private let degreeOptions = [
        "Bachelor",
        "Master",
        "PhD",
        "Other"
    ]

    private var filteredUniversities: [University] {
        let query = search.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            return Array(universities.prefix(60))
        }

        return universities.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.country.localizedCaseInsensitiveContains(query) ||
            ($0.city?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedUniversity {
                    caseDetails(university: selectedUniversity)
                } else {
                    universityPicker
                }
            }
            .background(Theme.pageBackground)
            .navigationTitle(
                selectedUniversity == nil
                    ? "Choose University"
                    : "New Case"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        selectedUniversity == nil
                            ? "Close"
                            : "Back"
                    ) {
                        if selectedUniversity == nil {
                            dismiss()
                        } else {
                            self.selectedUniversity = nil
                        }
                    }
                }
            }
            .task { await loadUniversities() }
            .alert(
                "Create Case",
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

    private var universityPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.muted)

                TextField(
                    "Search university or country",
                    text: $search
                )
                .textInputAutocapitalization(.never)
            }
            .padding(12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding()

            if loading {
                Spacer()
                ProgressView()
                    .tint(Theme.orange)
                Spacer()
            } else {
                List(filteredUniversities) { university in
                    Button {
                        selectedUniversity = university
                    } label: {
                        HStack(spacing: 12) {
                            UniversityLogo(
                                university: university,
                                fallbackName: university.name,
                                size: 42
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(university.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(
                                    [university.city, university.country]
                                        .compactMap { $0 }
                                        .joined(separator: ", ")
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func caseDetails(
        university: University
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 13) {
                    UniversityLogo(
                        university: university,
                        fallbackName: university.name,
                        size: 58
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(university.name)
                            .font(.headline.bold())
                            .foregroundStyle(Theme.ink)

                        Text(university.country)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Application details")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    TextField(
                        "Program / major",
                        text: $programName
                    )
                    .caseFieldStyle()

                    Picker("Study level", selection: $degreeLevel) {
                        ForEach(degreeOptions, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.orangeSoft)

                    TextField(
                        "Intake, e.g. Fall 2027",
                        text: $intake
                    )
                    .caseFieldStyle()
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "Starter document checklist",
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.ink)

                    Text("EduT will create a starter checklist for passport, transcripts, diploma, language test, essays and recommendation letters. These are not automatically claimed as the university's official requirements. You can add, remove and upload documents inside the case.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await create() }
                } label: {
                    HStack {
                        if creating {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(
                            creating
                                ? "Creating…"
                                : "Create university case"
                        )
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.orangeGradient)
                    .foregroundStyle(Theme.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .disabled(creating)
            }
            .padding()
        }
    }

    @MainActor
    private func loadUniversities() async {
        guard universities.isEmpty else {
            loading = false
            return
        }

        loading = true
        defer { loading = false }

        do {
            universities = try await DataService.universityChoices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func create() async {
        guard let selectedUniversity else {
            return
        }

        creating = true
        defer { creating = false }

        do {
            _ = try await DataService.createUniversityApplicationCase(
                universityId: selectedUniversity.id,
                programName: programName,
                degreeLevel: degreeLevel,
                intake: intake.isEmpty ? nil : intake
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UniversityCaseDetailView: View {
    let caseId: UUID

    @State private var item: UniversityApplicationCase?
    @State private var requirements: [UniversityCaseRequirement] = []
    @State private var documents: [UniversityCaseDocument] = []
    @State private var loading = true
    @State private var showingImporter = false
    @State private var uploadRequirement: UniversityCaseRequirement?
    @State private var showingAddRequirement = false
    @State private var newRequirementTitle = ""
    @State private var newRequirementCategory = "Other"
    @State private var newRequirementRequired = true
    @State private var errorMessage: String?

    private let statuses = [
        "Planning",
        "Preparing",
        "Submitted",
        "Interview",
        "Offer",
        "Rejected",
        "Withdrawn"
    ]

    private let categories = [
        "Identity",
        "Academic",
        "Testing",
        "Essay",
        "Recommendation",
        "Financial",
        "Profile",
        "Other"
    ]

    private var requiredRequirements: [UniversityCaseRequirement] {
        requirements.filter(\.isRequired)
    }

    private var missingRequirements: [UniversityCaseRequirement] {
        requiredRequirements.filter { requirement in
            !documents.contains {
                $0.requirementId == requirement.id
            }
        }
    }

    private var uploadedRequirements: [UniversityCaseRequirement] {
        requirements.filter { requirement in
            documents.contains {
                $0.requirementId == requirement.id
            }
        }
    }

    private var completion: Double {
        guard !requiredRequirements.isEmpty else { return 0 }
        return Double(
            requiredRequirements.count - missingRequirements.count
        ) / Double(requiredRequirements.count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if loading {
                ProgressView()
                    .tint(Theme.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if let item {
                VStack(alignment: .leading, spacing: 18) {
                    caseHeader(item)
                    documentSummary
                    requirementsSection
                    extraDocumentsSection

                    if !item.notes
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Notes")
                                .font(.headline.bold())
                                .foregroundStyle(Theme.ink)

                            Text(item.notes)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(16)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
        }
        .background(Theme.pageBackground)
        .navigationTitle("Application Case")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await upload(url: url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingAddRequirement) {
            addRequirementSheet
        }
        .alert(
            "Application Case",
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

    private func caseHeader(
        _ item: UniversityApplicationCase
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                UniversityLogo(
                    university: item.university,
                    fallbackName: item.university.name,
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.university.name)
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    if !item.programName.isEmpty {
                        Text(item.programName)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer()
            }

            HStack {
                Menu {
                    ForEach(statuses, id: \.self) { status in
                        Button {
                            Task { await updateStatus(status) }
                        } label: {
                            if item.applicationStatus == status {
                                Label(status, systemImage: "checkmark")
                            } else {
                                Text(status)
                            }
                        }
                    }
                } label: {
                    Label(
                        item.applicationStatus,
                        systemImage: "flag.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 11)
                    .frame(height: 36)
                    .background(Theme.orange)
                    .clipShape(Capsule())
                }

                Spacer()

                if let deadline = item.deadline {
                    Label(deadline, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(Theme.orangeSoft)
                }
            }

            if let reference = item.applicationReference.nilIfBlank {
                Label(
                    "Reference: \(reference)",
                    systemImage: "number"
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var documentSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Document readiness")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    Text(
                        missingRequirements.isEmpty &&
                        !requiredRequirements.isEmpty
                            ? "All required documents are attached"
                            : "\(missingRequirements.count) required document(s) missing"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        missingRequirements.isEmpty
                            ? Theme.green
                            : .orange
                    )
                }

                Spacer()

                Text("\(Int(completion * 100))%")
                    .font(.title3.bold())
                    .foregroundStyle(
                        missingRequirements.isEmpty &&
                        !requiredRequirements.isEmpty
                            ? Theme.green
                            : Theme.orangeSoft
                    )
            }

            ProgressView(value: completion)
                .tint(
                    missingRequirements.isEmpty &&
                    !requiredRequirements.isEmpty
                        ? Theme.green
                        : Theme.orange
                )

            HStack(spacing: 8) {
                docCountPill(
                    "\(requiredRequirements.count)",
                    "Required",
                    "doc.text.fill"
                )
                docCountPill(
                    "\(uploadedRequirements.count)",
                    "Attached",
                    "checkmark.circle.fill"
                )
                docCountPill(
                    "\(missingRequirements.count)",
                    "Missing",
                    "exclamationmark.circle.fill"
                )
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func docCountPill(
        _ count: String,
        _ label: String,
        _ icon: String
    ) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.orangeSoft)

            Text(count)
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Required documents")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    Text("See exactly what is attached and what is missing")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Button {
                    showingAddRequirement = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.orangeSoft)
                }
                .buttonStyle(.plain)
            }

            ForEach(requirements) { requirement in
                requirementRow(requirement)
            }

            Text("Starter items are planning aids until you verify them against the university's official admissions page. Official/source-linked requirements can be added to the same case.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func requirementRow(
        _ requirement: UniversityCaseRequirement
    ) -> some View {
        let attached = documents.first {
            $0.requirementId == requirement.id
        }

        return VStack(spacing: 9) {
            HStack(spacing: 10) {
                Image(
                    systemName: attached == nil
                        ? "circle"
                        : "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(
                    attached == nil
                        ? (requirement.isRequired
                            ? .orange
                            : Theme.ink.opacity(0.34))
                        : Theme.green
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(requirement.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)

                    HStack(spacing: 6) {
                        Text(requirement.category)

                        if requirement.isRequired {
                            Text("Required")
                        } else {
                            Text("Optional")
                        }

                        if requirement.isOfficial {
                            Label(
                                "Source-linked",
                                systemImage: "checkmark.seal.fill"
                            )
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                }

                Spacer()

                if attached == nil {
                    Button("Upload") {
                        uploadRequirement = requirement
                        showingImporter = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.orangeSoft)
                    .buttonStyle(.plain)
                }
            }

            if let attached {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.orangeSoft)

                    Text(attached.fileName)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)

                    Spacer()

                    Button(role: .destructive) {
                        Task { await deleteDocument(attached) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 4)
    }

    private var extraDocumentsSection: some View {
        let extras = documents.filter { $0.requirementId == nil }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Other documents")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Button {
                    uploadRequirement = nil
                    showingImporter = true
                } label: {
                    Label("Add file", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.orangeSoft)
                }
                .buttonStyle(.plain)
            }

            if extras.isEmpty {
                Text("Upload any additional application file that does not belong to a checklist item.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(extras) { document in
                    HStack {
                        Label(
                            document.fileName,
                            systemImage: "doc.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)

                        Spacer()

                        Button(role: .destructive) {
                            Task { await deleteDocument(document) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var addRequirementSheet: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    TextField(
                        "Document name",
                        text: $newRequirementTitle
                    )

                    Picker(
                        "Category",
                        selection: $newRequirementCategory
                    ) {
                        ForEach(categories, id: \.self) {
                            Text($0).tag($0)
                        }
                    }

                    Toggle(
                        "Required for my case",
                        isOn: $newRequirementRequired
                    )
                }

                Section {
                    Text("Add the item after checking the university's admissions instructions. You can then upload the matching file directly to this requirement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Document Requirement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddRequirement = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addRequirement() }
                    }
                    .disabled(
                        newRequirementTitle
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
        }

    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            async let caseTask = DataService.universityCase(id: caseId)
            async let requirementsTask =
                DataService.universityCaseRequirements(caseId: caseId)
            async let documentsTask =
                DataService.universityCaseDocuments(caseId: caseId)

            item = try await caseTask
            requirements = try await requirementsTask
            documents = try await documentsTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateStatus(
        _ status: String
    ) async {
        do {
            try await DataService.setUniversityCaseStatus(
                caseId: caseId,
                status: status
            )

            item = try await DataService.universityCase(id: caseId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func addRequirement() async {
        let title = newRequirementTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !title.isEmpty else { return }

        do {
            try await DataService.addUniversityCaseRequirement(
                caseId: caseId,
                title: title,
                category: newRequirementCategory,
                required: newRequirementRequired
            )

            newRequirementTitle = ""
            newRequirementCategory = "Other"
            newRequirementRequired = true
            showingAddRequirement = false

            requirements =
                try await DataService.universityCaseRequirements(
                    caseId: caseId
                )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func upload(
        url: URL
    ) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)

            guard data.count <= 6 * 1024 * 1024 else {
                errorMessage = L10n.string("Please choose a file smaller than 6 MB.")
                return
            }

            let values = try? url.resourceValues(
                forKeys: [.contentTypeKey]
            )

            let contentType =
                values?.contentType?.preferredMIMEType ??
                fallbackContentType(url)

            guard [
                "application/pdf",
                "image/jpeg",
                "image/png",
                "image/heic",
                "image/heif"
            ].contains(contentType) else {
                errorMessage = L10n.string("Please choose a PDF or image file.")
                return
            }

            try await DataService.uploadUniversityCaseDocument(
                caseId: caseId,
                requirementId: uploadRequirement?.id,
                fileName: url.lastPathComponent,
                data: data,
                contentType: contentType
            )

            documents =
                try await DataService.universityCaseDocuments(
                    caseId: caseId
                )

            uploadRequirement = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteDocument(
        _ document: UniversityCaseDocument
    ) async {
        do {
            try await DataService.deleteUniversityCaseDocument(
                document
            )

            withAnimation(.easeInOut(duration: 0.18)) {
                documents.removeAll {
                    $0.id == document.id
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fallbackContentType(
        _ url: URL
    ) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        default:
            return "image/jpeg"
        }
    }
}

private extension View {
    func caseFieldStyle() -> some View {
        self
            .padding(12)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        guard let value = self?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }

        return value
    }
}
