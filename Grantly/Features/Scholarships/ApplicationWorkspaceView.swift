import SwiftUI
import UniformTypeIdentifiers

struct ApplicationWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss

    let scholarship: Scholarship

    @State private var item: SavedScholarshipItem?
    @State private var tasks: [ApplicationTask] = []
    @State private var documents: [ApplicationDocument] = []
    @State private var status = "Planning"
    @State private var reference = ""
    @State private var notes = ""
    @State private var personalDeadline = Date()
    @State private var hasPersonalDeadline = false
    @State private var reminderEnabled = true
    @State private var documentsComplete = false
    @State private var loading = true
    @State private var saving = false
    @State private var uploadingDocument = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingPortal = false
    @State private var showingFileImporter = false
    @State private var showingNewTask = false
    @State private var newTaskTitle = ""

    private let statuses = [
        "Planning",
        "Preparing",
        "Submitted",
        "Interview",
        "Offer",
        "Rejected",
        "Withdrawn"
    ]

    private let activeTimeline = [
        "Planning",
        "Preparing",
        "Submitted",
        "Interview",
        "Offer"
    ]

    private var completedTasks: Int {
        tasks.filter { $0.completedAt != nil }.count
    }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedTasks) / Double(tasks.count)
    }

    private var portalURL: URL? {
        URL(string: scholarship.officialUrl)
    }

    private var isSubmittedOrLater: Bool {
        ["Submitted", "Interview", "Offer", "Rejected"]
            .contains(status)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCard
                    statusCard
                    deadlineCard
                    checklistCard
                    documentVaultCard
                    applicationDetailsCard
                    officialPortalCard
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(Theme.pageBackground)
            .navigationTitle("Application Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        Task { await saveWorkspace() }
                    }
                    .disabled(saving || loading)
                }
            }
            .task { await load() }
            .sheet(isPresented: $showingPortal) {
                if let portalURL {
                    InAppBrowser(url: portalURL)
                        .ignoresSafeArea()
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await importDocument(from: url) }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .alert(
                "Add checklist item",
                isPresented: $showingNewTask
            ) {
                TextField("Task", text: $newTaskTitle)

                Button("Add") {
                    Task { await addCustomTask() }
                }

                Button("Cancel", role: .cancel) {
                    newTaskTitle = ""
                }
            } message: {
                Text("Add a requirement or preparation step for this application.")
            }
            .alert(
                "Application Center",
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                UniversityLogo(
                    university: scholarship.university,
                    fallbackName: scholarship.provider,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(scholarship.title)
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)

                    Text(scholarship.provider)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Label(
                    scholarship.deadline ?? "Deadline not yet confirmed",
                    systemImage: "calendar"
                )

                Spacer()

                Label(
                    scholarship.country,
                    systemImage: "mappin.and.ellipse"
                )
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.orangeSoft)

            if let successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.green)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Application status")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    Text("Your progress inside EduT")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Menu {
                    ForEach(statuses, id: \.self) { value in
                        Button {
                            Task { await changeStatus(to: value) }
                        } label: {
                            if value == status {
                                Label(value, systemImage: "checkmark")
                            } else {
                                Text(value)
                            }
                        }
                    }
                } label: {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Theme.orange)
                        .clipShape(Capsule())
                }
            }

            statusTimeline

            ProgressView(value: progress)
                .tint(Theme.orange)

            HStack {
                Text("\(completedTasks) of \(tasks.count) preparation steps")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.orangeSoft)
            }

            if !isSubmittedOrLater {
                Button {
                    Task { await changeStatus(to: "Submitted") }
                } label: {
                    Label(
                        "I submitted my application",
                        systemImage: "paperplane.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.surfaceRaised)
                    .foregroundStyle(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }

            Text("EduT tracks your progress. The scholarship provider remains the official source for submission and decision status.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var statusTimeline: some View {
        HStack(spacing: 4) {
            ForEach(Array(activeTimeline.enumerated()), id: \.element) {
                index,
                value in

                let currentIndex =
                    activeTimeline.firstIndex(of: status) ?? 0
                let complete = index <= currentIndex &&
                    !["Rejected", "Withdrawn"].contains(status)

                VStack(spacing: 5) {
                    Circle()
                        .fill(
                            complete
                                ? Theme.orange
                                : Theme.ink.opacity(0.12)
                        )
                        .frame(width: 10, height: 10)

                    Text(shortStatus(value))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(
                            complete
                                ? .white.opacity(0.82)
                                : Theme.ink.opacity(0.30)
                        )
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                if index < activeTimeline.count - 1 {
                    Rectangle()
                        .fill(
                            index < currentIndex &&
                            !["Rejected", "Withdrawn"].contains(status)
                                ? Theme.orange.opacity(0.65)
                                : Theme.ink.opacity(0.08)
                        )
                        .frame(height: 2)
                        .offset(y: -8)
                }
            }
        }
    }

    private var deadlineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Plan your deadline")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Toggle("", isOn: $hasPersonalDeadline)
                    .labelsHidden()
                    .tint(Theme.orange)
            }

            if hasPersonalDeadline {
                DatePicker(
                    "My target date",
                    selection: $personalDeadline,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .foregroundStyle(Theme.ink)
            }

            Toggle(
                "Deadline reminders",
                isOn: $reminderEnabled
            )
            .tint(Theme.orange)

            if let official = scholarship.deadline {
                Label(
                    "Official deadline: \(official)",
                    systemImage: "calendar.badge.exclamationmark"
                )
                .font(.caption)
                .foregroundStyle(Theme.orangeSoft)
            }

            Text("Set an earlier personal target so you have time to fix missing documents before the official deadline.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Application checklist")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Button {
                    showingNewTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.orangeSoft)
                        .frame(width: 30, height: 30)
                        .background(Theme.surfaceRaised)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add checklist item")

                Toggle("", isOn: $documentsComplete)
                    .labelsHidden()
                    .tint(Theme.green)
            }

            if loading {
                ProgressView()
                    .tint(Theme.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if tasks.isEmpty {
                Text("No checklist items yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(tasks) { task in
                    Button {
                        Task { await toggle(task) }
                    } label: {
                        HStack(spacing: 11) {
                            Image(
                                systemName: task.completedAt == nil
                                    ? "circle"
                                    : "checkmark.circle.fill"
                            )
                            .font(.headline)
                            .foregroundStyle(
                                task.completedAt == nil
                                    ? .white.opacity(0.36)
                                    : Theme.green
                            )

                            Text(task.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if task.taskKey == nil {
                                Button(role: .destructive) {
                                    Task { await deleteCustomTask(task) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(
                documentsComplete
                    ? "You marked the document set as ready."
                    : "Mark this ready after checking every required document against the official portal."
            )
            .font(.caption2)
            .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var documentVaultCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Document vault")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    Text("Private files for this application")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Button {
                    showingFileImporter = true
                } label: {
                    Label(
                        uploadingDocument ? "Uploading…" : "Add file",
                        systemImage: "plus"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.orangeSoft)
                }
                .disabled(uploadingDocument)
            }

            if documents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "lock.doc")
                        .font(.title2)
                        .foregroundStyle(Theme.ink.opacity(0.34))

                    Text("Keep transcripts, letters and supporting files together.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ForEach(documents) { document in
                    HStack(spacing: 11) {
                        Image(systemName: documentIcon(document))
                            .foregroundStyle(Theme.orangeSoft)
                            .frame(width: 32, height: 32)
                            .background(Theme.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 9))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.fileName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)

                            Text(fileSize(document.byteSize))
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            Task { await delete(document) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Label(
                "Files are stored in a private user-scoped bucket. PDF and image files only, up to 6 MB each.",
                systemImage: "lock.fill"
            )
            .font(.caption2)
            .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var applicationDetailsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Submission details")
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            VStack(alignment: .leading, spacing: 6) {
                Text("Application / confirmation number")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)

                TextField("Example: APP-2026-12345", text: $reference)
                    .textInputAutocapitalization(.characters)
                    .padding(12)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)

                TextField(
                    "Add portal notes, document reminders or next steps",
                    text: $notes,
                    axis: .vertical
                )
                .lineLimit(3...7)
                .padding(12)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let submitted = item?.submittedAt {
                DetailLine(
                    label: "Submitted",
                    value: displayDate(submitted)
                )
            }

            if let interview = item?.interviewAt {
                DetailLine(
                    label: "Interview",
                    value: displayDate(interview)
                )
            }

            if let result = item?.resultAt {
                DetailLine(
                    label: "Decision",
                    value: displayDate(result)
                )
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var officialPortalCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Official application portal")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    Text("Open it without leaving EduT")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Image(systemName: "safari.fill")
                    .foregroundStyle(Theme.orangeSoft)
            }

            if let checked = item?.portalLastCheckedAt {
                Text("Last checked \(displayDate(checked))")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }

            Button {
                Task { await openPortal() }
            } label: {
                Label(
                    isSubmittedOrLater
                        ? "Check official status"
                        : "Open application form",
                    systemImage: "arrow.up.right.square"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.orangeGradient)
                .foregroundStyle(Theme.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(portalURL == nil)

            Text("The official website handles the actual submission. EduT keeps your preparation, files and progress organized around it.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            item = try await DataService.savedApplication(
                scholarshipId: scholarship.id
            )

            if item == nil,
               let userId = try? await supabase.auth.session.user.id {
                try await DataService.setSaved(
                    true,
                    userId: userId,
                    scholarshipId: scholarship.id
                )

                item = try await DataService.savedApplication(
                    scholarshipId: scholarship.id
                )
            }

            status = item?.applicationStatus ?? "Planning"
            reference = item?.applicationReference ?? ""
            notes = item?.notes ?? ""
            reminderEnabled = item?.reminderEnabled ?? true
            documentsComplete = item?.documentsComplete ?? false

            if let date = parseDate(item?.personalDeadline) {
                personalDeadline = date
                hasPersonalDeadline = true
            } else {
                personalDeadline = Date()
                hasPersonalDeadline = false
            }

            tasks = try await DataService.applicationTasks(
                scholarshipId: scholarship.id
            )

            documents = try await DataService.applicationDocuments(
                scholarshipId: scholarship.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveWorkspace() async {
        saving = true
        successMessage = nil
        defer { saving = false }

        do {
            try await DataService.updateApplicationWorkspace(
                scholarshipId: scholarship.id,
                reference: reference,
                notes: notes,
                personalDeadline: hasPersonalDeadline
                    ? databaseDate(personalDeadline)
                    : nil,
                documentsComplete: documentsComplete,
                reminderEnabled: reminderEnabled
            )

            item = try await DataService.savedApplication(
                scholarshipId: scholarship.id
            )

            successMessage = "Application workspace saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func changeStatus(to newStatus: String) async {
        let oldStatus = status
        status = newStatus
        successMessage = nil

        do {
            try await DataService.updateApplicationStatus(
                scholarshipId: scholarship.id,
                status: newStatus
            )

            item = try await DataService.savedApplication(
                scholarshipId: scholarship.id
            )

            successMessage = "Status updated to \(newStatus)."
        } catch {
            status = oldStatus
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func addCustomTask() async {
        let cleaned = newTaskTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleaned.isEmpty else {
            return
        }

        do {
            let nextPosition =
                (tasks.map(\.position).max() ?? 0) + 10

            try await DataService.addApplicationTask(
                scholarshipId: scholarship.id,
                title: cleaned,
                position: nextPosition
            )

            newTaskTitle = ""
            tasks = try await DataService.applicationTasks(
                scholarshipId: scholarship.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteCustomTask(
        _ task: ApplicationTask
    ) async {
        guard task.taskKey == nil else { return }

        do {
            try await DataService.deleteApplicationTask(
                taskId: task.id
            )

            withAnimation(.easeInOut(duration: 0.18)) {
                tasks.removeAll { $0.id == task.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggle(_ task: ApplicationTask) async {
        do {
            try await DataService.setApplicationTaskCompleted(
                taskId: task.id,
                completed: task.completedAt == nil
            )

            tasks = try await DataService.applicationTasks(
                scholarshipId: scholarship.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importDocument(from url: URL) async {
        uploadingDocument = true
        successMessage = nil
        defer { uploadingDocument = false }

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

            try await DataService.uploadApplicationDocument(
                scholarshipId: scholarship.id,
                fileName: url.lastPathComponent,
                data: data,
                contentType: contentType
            )

            documents = try await DataService.applicationDocuments(
                scholarshipId: scholarship.id
            )

            successMessage = "Document added."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func delete(_ document: ApplicationDocument) async {
        do {
            try await DataService.deleteApplicationDocument(document)

            withAnimation(.easeInOut(duration: 0.18)) {
                documents.removeAll { $0.id == document.id }
            }

            successMessage = "Document removed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openPortal() async {
        guard portalURL != nil else { return }

        do {
            try await DataService.markApplicationPortalChecked(
                scholarshipId: scholarship.id
            )

            try? await DataService.trackProductEvent(
                isSubmittedOrLater
                    ? "application_status_check"
                    : "application_portal_open",
                scholarshipId: scholarship.id,
                properties: [
                    "provider": scholarship.provider,
                    "status": status
                ]
            )

            item = try? await DataService.savedApplication(
                scholarshipId: scholarship.id
            )
        } catch {
            // Keep the official portal available if analytics fail.
        }

        showingPortal = true
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return Self.databaseDateFormatter.date(from: value)
    }

    private func databaseDate(_ date: Date) -> String {
        Self.databaseDateFormatter.string(from: date)
    }

    private func displayDate(_ value: String) -> String {
        if let date = ISO8601DateFormatter().date(from: value) {
            return Self.displayDateFormatter.string(from: date)
        }

        if let date = Self.databaseDateFormatter.date(from: value) {
            return Self.displayDateFormatter.string(from: date)
        }

        return String(value.prefix(10))
    }

    private func shortStatus(_ value: String) -> String {
        switch value {
        case "Preparing":
            return "Prepare"
        case "Submitted":
            return "Submit"
        case "Interview":
            return "Interview"
        default:
            return value
        }
    }

    private func documentIcon(
        _ document: ApplicationDocument
    ) -> String {
        document.contentType == "application/pdf"
            ? "doc.richtext"
            : "photo"
    }

    private func fileSize(_ bytes: Int?) -> String {
        guard let bytes else { return "Private file" }
        return ByteCountFormatter.string(
            fromByteCount: Int64(bytes),
            countStyle: .file
        )
    }

    private func fallbackContentType(_ url: URL) -> String {
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

    private static let databaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
