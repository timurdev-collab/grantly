import SwiftUI

struct SectionEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(Theme.violet)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(text))
    }
}

struct FundingBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(text.lowercased().contains("fully") ? Theme.mint : Theme.soft)
            .foregroundStyle(text.lowercased().contains("fully") ? Theme.green : .secondary)
            .clipShape(Capsule())
    }
}


struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let subject: String
    let onSubmit: (String, String) async throws -> Void

    @State private var reason = "Inappropriate content"
    @State private var details = ""
    @State private var busy = false
    @State private var errorMessage: String?

    private let reasons = [
        "Spam",
        "Harassment",
        "Inappropriate content",
        "Scam or fraud",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Report \(subject)")
                        .font(.headline)
                }

                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(reasons, id: \.self) { Text($0) }
                    }
                }

                Section("Details") {
                    TextField(
                        "Optional details",
                        text: $details,
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    Text("\(details.count)/1000")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Sending…" : "Send") {
                        Task { await submit() }
                    }
                    .disabled(busy || details.count > 1000)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        busy = true
        errorMessage = nil
        defer { busy = false }

        do {
            try await onSubmit(
                reason,
                details.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
