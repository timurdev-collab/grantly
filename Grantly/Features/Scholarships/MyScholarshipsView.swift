import SwiftUI

struct MyScholarshipsView: View {
    private let statuses = [
        "Planning",
        "Preparing",
        "Submitted",
        "Applied",
        "Interview",
        "Offer",
        "Rejected",
        "Withdrawn",
        "Result"
    ]

    @State private var items: [SavedScholarshipItem] = []
    @State private var loading = true
    @State private var selectedStatus = "All"
    @State private var editingItem: SavedScholarshipItem?
    @State private var taskItem: SavedScholarshipItem?
    @State private var workspaceItem: SavedScholarshipItem?
    @State private var noteText = ""
    @State private var errorMessage: String?

    private var filteredItems: [SavedScholarshipItem] {
        guard selectedStatus != "All" else {
            return items
        }

        return items.filter {
            $0.applicationStatus == selectedStatus
        }
    }

    private var appliedCount: Int {
        items.filter {
            ["Applied", "Submitted"].contains($0.applicationStatus)
        }.count
    }

    private var interviewCount: Int {
        items.filter { $0.applicationStatus == "Interview" }.count
    }

    private var resultCount: Int {
        items.filter {
            ["Result", "Offer", "Rejected"].contains($0.applicationStatus)
        }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                pipelineSummary

                if !items.isEmpty {
                    statusFilter
                }

                if loading && items.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.orange)
                        Text("Loading your scholarship tracker...")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 52)
                } else if filteredItems.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 13) {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ScholarshipDetailView(
                                    scholarship: item.scholarship,
                                    match: nil
                                )
                            } label: {
                                ApplicationCard(
                                    item: item,
                                    statuses: statuses,
                                    onStatus: { status in
                                        Task {
                                            await updateStatus(
                                                item: item,
                                                status: status
                                            )
                                        }
                                    },
                                    onNote: {
                                        editingItem = item
                                        noteText = item.notes ?? ""
                                    },
                                    onTasks: {
                                        taskItem = item
                                    },
                                    onWorkspace: {
                                        workspaceItem = item
                                    },
                                    onRemove: {
                                        Task {
                                            await remove(item)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationBarHidden(true)
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $editingItem) { item in
            noteSheet(item)
        }
        .sheet(item: $taskItem) { item in
            ApplicationTasksSheet(item: item)
        }
        .sheet(item: $workspaceItem, onDismiss: {
            Task { await load() }
        }) { item in
            ApplicationWorkspaceView(
                scholarship: item.scholarship
            )
        }
        .alert(
            "Something went wrong",
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("My Scholarships")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Turn your shortlist into an application plan")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            RefreshButton(loading: loading) { await load() }
        }
    }

    private var pipelineSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Application pipeline")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    Text("Keep every opportunity moving")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Text(L10n.format("%d saved scholarships", items.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.orangeSoft)
            }

            HStack(spacing: 8) {
                TrackerMetric(
                    value: "\(items.filter { $0.applicationStatus == "Planning" }.count)",
                    label: "Planning",
                    icon: "list.bullet.clipboard"
                )

                TrackerMetric(
                    value: "\(appliedCount)",
                    label: "Applied",
                    icon: "paperplane.fill"
                )

                TrackerMetric(
                    value: "\(interviewCount)",
                    label: "Interview",
                    icon: "person.2.fill"
                )

                TrackerMetric(
                    value: "\(resultCount)",
                    label: "Result",
                    icon: "checkmark.seal.fill"
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Theme.surfaceRaised, Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusChip("All")

                ForEach(statuses, id: \.self) { status in
                    statusChip(status)
                }
            }
        }
    }

    private func statusChip(_ status: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedStatus = status
            }
        } label: {
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    selectedStatus == status
                        ? .white
                        : Theme.ink.opacity(0.66)
                )
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(
                    selectedStatus == status
                        ? Theme.orange
                        : Theme.surface
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: selectedStatus == "All" ? "bookmark" : "tray")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.orangeSoft)
                .frame(width: 60, height: 60)
                .background(Theme.surface)
                .clipShape(Circle())

            Text(
                selectedStatus == "All"
                    ? "Your shortlist is empty"
                    : "Nothing in \(selectedStatus.lowercased())"
            )
            .font(.headline.bold())
            .foregroundStyle(Theme.ink)

            Text(
                selectedStatus == "All"
                    ? L10n.string("Save scholarships from Explore and manage each application here.") : L10n.string("Update a scholarship's stage when your application progresses.")
            )
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 290)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func noteSheet(_ item: SavedScholarshipItem) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Application note")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.orangeSoft)

                Text(item.scholarship.title)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)

                TextEditor(text: $noteText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 190)
                    .padding(12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.ink.opacity(0.07))
                    )

                Text("Keep document reminders, interview dates, useful links or anything else you need beside this application.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)

                Spacer()
            }
            .padding()
            .background(Theme.pageBackground)
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingItem = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveNote(
                                item: item,
                                notes: noteText
                            )
                        }
                    }
                }
            }
        }

    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            items = try await DataService.savedScholarshipItems()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateStatus(
        item: SavedScholarshipItem,
        status: String
    ) async {
        do {
            try await DataService.updateApplicationStatus(
                scholarshipId: item.scholarshipId,
                status: status
            )

            replace(
                item,
                status: status,
                notes: item.notes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveNote(
        item: SavedScholarshipItem,
        notes: String
    ) async {
        do {
            try await DataService.updateScholarshipNotes(
                scholarshipId: item.scholarshipId,
                notes: notes
            )

            replace(
                item,
                status: item.applicationStatus,
                notes: notes
            )

            editingItem = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func remove(_ item: SavedScholarshipItem) async {
        do {
            let userId = try await supabase.auth.session.user.id

            try await DataService.setSaved(
                false,
                userId: userId,
                scholarshipId: item.scholarshipId
            )

            withAnimation(.easeInOut(duration: 0.18)) {
                items.removeAll {
                    $0.scholarshipId == item.scholarshipId
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace(
        _ item: SavedScholarshipItem,
        status: String,
        notes: String?
    ) {
        guard let index = items.firstIndex(
            where: { $0.scholarshipId == item.scholarshipId }
        ) else {
            return
        }

        items[index] = SavedScholarshipItem(
            scholarshipId: item.scholarshipId,
            applicationStatus: status,
            notes: notes,
            applicationDeadline: item.applicationDeadline,
            personalDeadline: item.personalDeadline,
            submittedAt: item.submittedAt,
            interviewAt: item.interviewAt,
            resultAt: item.resultAt,
            documentsComplete: item.documentsComplete,
            reminderEnabled: item.reminderEnabled,
            applicationReference: item.applicationReference,
            portalLastCheckedAt: item.portalLastCheckedAt,
            scholarship: item.scholarship
        )
    }
}

private struct TrackerMetric: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Theme.orangeSoft)

            Text(value)
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.navyDeep.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

private struct ApplicationCard: View {
    let item: SavedScholarshipItem
    let statuses: [String]
    let onStatus: (String) -> Void
    let onNote: () -> Void
    let onTasks: () -> Void
    let onWorkspace: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            UniversityPhoto(
                seed: item.scholarship.provider + item.scholarship.title,
                remoteURL: item.scholarship.university?.campusImageUrl,
                height: 116
            )
            .frame(width: 112)
            .clipShape(RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    Text(item.scholarship.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Menu {
                        Button("Remove", role: .destructive) {
                            onRemove()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.muted)
                            .frame(width: 24, height: 24)
                    }
                }

                Text(item.scholarship.provider)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Menu {
                        ForEach(statuses, id: \.self) { status in
                            Button {
                                onStatus(status)
                            } label: {
                                if status == item.applicationStatus {
                                    Label(status, systemImage: "checkmark")
                                } else {
                                    Text(status)
                                }
                            }
                        }
                    } label: {
                        ApplicationStatusPill(status: item.applicationStatus)
                    }

                    Spacer()

                    Button(action: onTasks) {
                        Image(systemName: "checklist")
                            .font(.caption)
                            .foregroundStyle(Theme.orangeSoft)
                    }
                    .buttonStyle(.plain)

                    Button(action: onNote) {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundStyle(
                                item.notes?
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty == false
                                    ? Theme.orangeSoft
                                    : Theme.ink.opacity(0.54)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onWorkspace) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.caption)
                            .foregroundStyle(Theme.orangeSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Application Center")
                }

                if let deadline = item.scholarship.deadline {
                    Label(deadline, systemImage: "calendar")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.orangeSoft)
                }

                if let notes = item.notes?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                if let reference = item.applicationReference,
                   !reference.isEmpty {
                    Label(
                        reference,
                        systemImage: "number"
                    )
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct ApplicationStatusPill: View {
    let status: String

    var body: some View {
        Label(status, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var icon: String {
        switch status {
        case "Applied", "Submitted":
            return "paperplane.fill"
        case "Interview":
            return "person.2.fill"
        case "Offer":
            return "checkmark.seal.fill"
        case "Rejected":
            return "xmark.seal.fill"
        case "Result":
            return "checkmark.seal.fill"
        default:
            return "list.bullet.clipboard"
        }
    }

    private var color: Color {
        switch status {
        case "Applied", "Submitted":
            return Theme.orangeSoft
        case "Interview":
            return Color(red: 0.70, green: 0.55, blue: 1.0)
        case "Offer", "Result":
            return Theme.green
        case "Rejected":
            return Theme.danger
        default:
            return .white.opacity(0.62)
        }
    }
}


private struct ApplicationTasksSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: SavedScholarshipItem

    @State private var tasks: [ApplicationTask] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.scholarship.title)
                            .font(.headline)

                        Text(item.scholarship.provider)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Application checklist") {
                    if loading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(tasks) { task in
                            Button {
                                Task { await toggle(task) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(
                                        systemName: task.completedAt == nil
                                            ? "circle"
                                            : "checkmark.circle.fill"
                                    )
                                    .foregroundStyle(
                                        task.completedAt == nil
                                            ? .secondary
                                            : Theme.green
                                    )

                                    Text(task.title)
                                        .foregroundStyle(.primary)
                                        .strikethrough(task.completedAt != nil)

                                    Spacer()

                                    if let dueAt = task.dueAt {
                                        Text(String(dueAt.prefix(10)))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Reminder foundation") {
                    Label(
                        item.reminderEnabled
                            ? L10n.string("Deadline reminders enabled")
                            : L10n.string("Deadline reminders disabled"),
                        systemImage: item.reminderEnabled
                            ? "bell.fill"
                            : "bell.slash"
                    )

                    if let personalDeadline = item.personalDeadline {
                        Label(
                            personalDeadline,
                            systemImage: "calendar.badge.clock"
                        )
                    } else if let deadline = item.scholarship.deadline {
                        Label(
                            deadline,
                            systemImage: "calendar"
                        )
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
            .navigationTitle("Application Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            tasks = try await DataService.applicationTasks(
                scholarshipId: item.scholarshipId
            )
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
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
