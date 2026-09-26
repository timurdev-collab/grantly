import SwiftUI

struct MyScholarshipsView: View {
    private let statuses = ["Planning", "Applied", "Interview", "Result"]

    @State private var items: [SavedScholarshipItem] = []
    @State private var loading = true
    @State private var selectedStatus = "All"
    @State private var editingItem: SavedScholarshipItem?
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                shortlistHero

                if !items.isEmpty {
                    statusFilter
                }

                if loading {
                    ProgressView("Opening your shortlist…")
                        .tint(Theme.brass)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else if filteredItems.isEmpty {
                    EmptyState(
                        icon: "bookmark",
                        title: selectedStatus == "All"
                            ? "Your shortlist is empty"
                            : "Nothing in \(selectedStatus.lowercased())",
                        text: selectedStatus == "All"
                            ? "Save scholarships from Explore and manage every application here."
                            : "Change an application's stage to keep your pipeline accurate."
                    )
                    .padding(.top, 30)
                } else {
                    LazyVStack(spacing: 12) {
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
        }
        .background(Theme.pageBackground)
        .navigationTitle("Shortlist")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    SectionEyebrow(text: "Application note")

                    Text(item.scholarship.title)
                        .font(Theme.serifTitle(24))
                        .foregroundStyle(Theme.ink)

                    TextEditor(text: $noteText)
                        .frame(minHeight: 190)
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.navy.opacity(0.08))
                        )

                    Text("Keep links, document reminders, interview dates or anything else you want beside this application.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private var shortlistHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionEyebrow(text: "Application desk")

            Text("Your shortlist,\nturned into a plan.")
                .font(Theme.serifTitle(31, weight: .medium))
                .tracking(-0.5)
                .foregroundStyle(Theme.parchment)

            Text("Move every scholarship from first idea to final result without losing the details in between.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .lineSpacing(3)

            HStack(spacing: 20) {
                ShortlistMetric(
                    value: "\(items.count)",
                    label: "saved"
                )

                ShortlistMetric(
                    value: "\(items.filter { $0.applicationStatus == "Applied" }.count)",
                    label: "applied"
                )

                ShortlistMetric(
                    value: "\(items.filter { $0.applicationStatus == "Interview" }.count)",
                    label: "interviews"
                )
            }
        }
        .padding(20)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
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
            selectedStatus = status
        } label: {
            Text(status)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    selectedStatus == status
                        ? Theme.navy
                        : Color.white
                )
                .foregroundStyle(
                    selectedStatus == status
                        ? Theme.parchment
                        : Theme.navy
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.navy.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            items = try await DataService.savedScholarshipItems()
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

            items.removeAll {
                $0.scholarshipId == item.scholarshipId
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
            scholarship: item.scholarship
        )
    }
}

private struct ShortlistMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.serifTitle(22))
                .foregroundStyle(Theme.parchment)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

private struct ApplicationCard: View {
    let item: SavedScholarshipItem
    let statuses: [String]
    let onStatus: (String) -> Void
    let onNote: () -> Void
    let onRemove: () -> Void

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.scholarship.title)
                            .font(Theme.serifTitle(19))
                            .foregroundStyle(Theme.ink)

                        Text(
                            "\(item.scholarship.provider) · " +
                            "\(item.scholarship.country)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button("Remove", role: .destructive) {
                            onRemove()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                }

                HStack {
                    Menu {
                        ForEach(statuses, id: \.self) { status in
                            Button {
                                onStatus(status)
                            } label: {
                                if status == item.applicationStatus {
                                    Label(
                                        status,
                                        systemImage: "checkmark"
                                    )
                                } else {
                                    Text(status)
                                }
                            }
                        }
                    } label: {
                        ApplicationStatusPill(
                            status: item.applicationStatus
                        )
                    }

                    Spacer()

                    Button(action: onNote) {
                        Label(
                            item.notes?
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty == false
                                ? "Edit note"
                                : "Add note",
                            systemImage: "note.text"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.brass)
                    }
                    .buttonStyle(.plain)
                }

                if let notes = item.notes?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                   !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }
        }
    }
}

private struct ApplicationStatusPill: View {
    let status: String

    var body: some View {
        Label(status, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.10))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var icon: String {
        switch status {
        case "Applied":
            return "paperplane.fill"
        case "Interview":
            return "person.2.fill"
        case "Result":
            return "checkmark.seal.fill"
        default:
            return "list.bullet.clipboard"
        }
    }

    private var color: Color {
        switch status {
        case "Applied":
            return Theme.brass
        case "Interview":
            return Theme.oxblood
        case "Result":
            return Theme.forest
        default:
            return Theme.navy
        }
    }
}
