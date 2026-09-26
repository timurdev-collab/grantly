import SwiftUI

struct SectionEyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.brass)
                .frame(width: 22, height: 1)

            Text(text.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(2)
                .foregroundStyle(Theme.brass)
        }
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
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.8)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                text.lowercased().contains("fully")
                    ? Theme.forest.opacity(0.10)
                    : Theme.brass.opacity(0.10)
            )
            .foregroundStyle(
                text.lowercased().contains("fully")
                    ? Theme.forest
                    : Theme.brass
            )
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


struct GrantlyMonogram: View {
    var size: CGFloat = 44
    var dark: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26)
                .fill(dark ? Theme.navy : Theme.parchment)

            RoundedRectangle(cornerRadius: size * 0.26)
                .stroke(Theme.brass.opacity(0.65), lineWidth: 1)

            Text("G")
                .font(.system(size: size * 0.47, weight: .semibold, design: .serif))
                .foregroundStyle(dark ? Theme.parchment : Theme.navy)
        }
        .frame(width: size, height: size)
    }
}

struct PremiumCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.navy.opacity(0.07), lineWidth: 1)
            )
            .shadow(
                color: Theme.ink.opacity(0.045),
                radius: 18,
                x: 0,
                y: 8
            )
    }
}

struct AcademicSectionHeader: View {
    let eyebrow: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                SectionEyebrow(text: eyebrow)
                Text(title)
                    .font(Theme.serifTitle(25))
                    .foregroundStyle(Theme.ink)
            }

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TrustSeal: View {
    let verified: Bool

    var body: some View {
        Label(
            verified ? "Verified" : "Curated",
            systemImage: verified ? "checkmark.seal.fill" : "seal"
        )
        .font(.caption2.weight(.bold))
        .tracking(0.35)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(verified ? Theme.sage : Theme.parchment)
        .foregroundStyle(verified ? Theme.forest : Theme.oxblood)
        .clipShape(Capsule())
    }
}
