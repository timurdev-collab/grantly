import SwiftUI

struct ApplicationWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss

    let scholarship: Scholarship

    @State private var item: SavedScholarshipItem?
    @State private var tasks: [ApplicationTask] = []
    @State private var status = "Planning"
    @State private var reference = ""
    @State private var notes = ""
    @State private var loading = true
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var showingPortal = false

    private let statuses = [
        "Planning",
        "Preparing",
        "Submitted",
        "Interview",
        "Offer",
        "Rejected",
        "Withdrawn"
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

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCard

                    statusCard

                    checklistCard

                    applicationDetailsCard

                    officialPortalCard
                }
                .padding()
                .padding(.bottom, 24)
            }
            .background(Theme.pageBackground)
            .navigationTitle("Application")
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
            .alert(
                "Application workspace",
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
        .preferredColorScheme(.dark)
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
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(scholarship.provider)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Label(
                    scholarship.deadline ?? "Deadline varies",
                    systemImage: "calendar"
                )

                Spacer()

                Label(
                    scholarship.country,
                    systemImage: "mappin.and.ellipse"
                )
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.blueSoft)
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
                        .foregroundStyle(.white)

                    Text("Track your progress in Grantly")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Theme.blue)
                        .clipShape(Capsule())
                }
            }

            ProgressView(value: progress)
                .tint(Theme.blue)

            Text("\(completedTasks) of \(tasks.count) preparation steps complete")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.46))

            Text("Status here is your Grantly tracker. The provider remains the official source for application decisions.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.56))
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Application checklist")
                .font(.headline.bold())
                .foregroundStyle(.white)

            if loading {
                ProgressView()
                    .tint(Theme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if tasks.isEmpty {
                Text("No checklist items yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.52))
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
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var applicationDetailsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Submission details")
                .font(.headline.bold())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("Application / confirmation number")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))

                TextField("Example: APP-2026-12345", text: $reference)
                    .textInputAutocapitalization(.characters)
                    .padding(12)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))

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
                        .foregroundStyle(.white)

                    Text("Open it without leaving Grantly")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()

                Image(systemName: "safari.fill")
                    .foregroundStyle(Theme.blueSoft)
            }

            if let checked = item?.portalLastCheckedAt {
                Text("Last checked \(String(checked.prefix(10)))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.44))
            }

            Button {
                Task { await openPortal() }
            } label: {
                Label(
                    status == "Submitted" ||
                    status == "Interview" ||
                    status == "Offer" ||
                    status == "Rejected"
                        ? "Check official status"
                        : "Open application form",
                    systemImage: "arrow.up.right.square"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.blueGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(portalURL == nil)

            Text("Grantly does not submit the provider's form or read private portal status unless that provider offers an approved integration.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
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
            tasks = try await DataService.applicationTasks(
                scholarshipId: scholarship.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveWorkspace() async {
        saving = true
        defer { saving = false }

        do {
            try await DataService.updateApplicationWorkspace(
                scholarshipId: scholarship.id,
                reference: reference,
                notes: notes
            )

            item = try await DataService.savedApplication(
                scholarshipId: scholarship.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func changeStatus(to newStatus: String) async {
        let oldStatus = status
        status = newStatus

        do {
            try await DataService.updateApplicationStatus(
                scholarshipId: scholarship.id,
                status: newStatus
            )

            item = try await DataService.savedApplication(
                scholarshipId: scholarship.id
            )
        } catch {
            status = oldStatus
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
    private func openPortal() async {
        guard portalURL != nil else { return }

        do {
            try await DataService.markApplicationPortalChecked(
                scholarshipId: scholarship.id
            )

            try? await DataService.trackProductEvent(
                status == "Submitted"
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
            // The official portal should remain available even if tracking fails.
        }

        showingPortal = true
    }
}
