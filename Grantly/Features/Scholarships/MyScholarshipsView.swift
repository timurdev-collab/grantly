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
        guard selectedStatus != "All" else { return items }
        return items.filter { $0.applicationStatus == selectedStatus }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !items.isEmpty {
                Picker("Status", selection: $selectedStatus) {
                    Text("All").tag("All")
                    ForEach(statuses, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Group {
                if loading {
                    ProgressView("Loading saved scholarships…")
                } else if filteredItems.isEmpty {
                    EmptyState(
                        icon: "bookmark",
                        title: selectedStatus == "All" ? "No saved scholarships" : "No \(selectedStatus.lowercased()) scholarships",
                        text: selectedStatus == "All"
                            ? "Save scholarships from Explore to track your applications here."
                            : "Change a scholarship's status to keep your tracker organized."
                    )
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ScholarshipDetailView(scholarship: item.scholarship, match: nil)
                            } label: {
                                trackerRow(item)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await remove(item) }
                                } label: {
                                    Label("Remove", systemImage: "bookmark.slash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await load() }
                }
            }
        }
        .navigationTitle("My Scholarships")
        .task { await load() }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.scholarship.title)
                        .font(.headline)

                    TextEditor(text: $noteText)
                        .frame(minHeight: 180)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Use notes for documents, portal details, interview dates or anything you want to remember.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding()
                .navigationTitle("Scholarship Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingItem = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await saveNote(item: item, notes: noteText) }
                        }
                    }
                }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func trackerRow(_ item: SavedScholarshipItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.scholarship.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("\(item.scholarship.provider) · \(item.scholarship.country)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Menu {
                    ForEach(statuses, id: \.self) { status in
                        Button {
                            Task { await updateStatus(item: item, status: status) }
                        } label: {
                            if status == item.applicationStatus {
                                Label(status, systemImage: "checkmark")
                            } else {
                                Text(status)
                            }
                        }
                    }
                } label: {
                    Label(item.applicationStatus, systemImage: statusIcon(item.applicationStatus))
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Button {
                    editingItem = item
                    noteText = item.notes ?? ""
                } label: {
                    Label(
                        item.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "Edit note" : "Add note",
                        systemImage: "note.text"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }

            if let notes = item.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 6)
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "Applied": return "paperplane.fill"
        case "Interview": return "person.2.fill"
        case "Result": return "checkmark.seal.fill"
        default: return "list.bullet.clipboard"
        }
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
    private func updateStatus(item: SavedScholarshipItem, status: String) async {
        do {
            try await DataService.updateApplicationStatus(
                scholarshipId: item.scholarshipId,
                status: status
            )

            replace(item, status: status, notes: item.notes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveNote(item: SavedScholarshipItem, notes: String) async {
        do {
            try await DataService.updateScholarshipNotes(
                scholarshipId: item.scholarshipId,
                notes: notes
            )

            replace(item, status: item.applicationStatus, notes: notes)
            editingItem = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func remove(_ item: SavedScholarshipItem) async {
        do {
            let userId = try await supabase.auth.session.user.id
            try await DataService.setSaved(false, userId: userId, scholarshipId: item.scholarshipId)
            items.removeAll { $0.scholarshipId == item.scholarshipId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace(_ item: SavedScholarshipItem, status: String, notes: String?) {
        guard let index = items.firstIndex(where: { $0.scholarshipId == item.scholarshipId }) else { return }
        items[index] = SavedScholarshipItem(
            scholarshipId: item.scholarshipId,
            applicationStatus: status,
            notes: notes,
            scholarship: item.scholarship
        )
    }
}
