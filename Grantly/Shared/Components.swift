import SwiftUI
import UIKit

struct SectionEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Theme.orange)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Theme.blueSoft)
                .frame(width: 58, height: 58)
                .background(Theme.surface)
                .clipShape(Circle())

            Text(title)
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
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
                    ? Theme.green.opacity(0.18)
                    : Theme.blue.opacity(0.16)
            )
            .foregroundStyle(
                text.lowercased().contains("fully")
                    ? Theme.green
                    : Theme.blueSoft
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
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(dark ? Theme.surface : Theme.navyDeep)

            HStack(spacing: size * 0.035) {
                RoundedRectangle(cornerRadius: size * 0.06)
                    .fill(Theme.blueGradient)
                    .frame(width: size * 0.22, height: size * 0.48)
                    .rotationEffect(.degrees(-28))
                RoundedRectangle(cornerRadius: size * 0.06)
                    .fill(Theme.blueGradient)
                    .frame(width: size * 0.22, height: size * 0.48)
                    .rotationEffect(.degrees(28))
            }
            .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28)
                .stroke(Theme.ink.opacity(0.07), lineWidth: 1)
        )
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
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.10),
                radius: 12,
                x: 0,
                y: 6
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
        .background(verified ? Theme.green.opacity(0.15) : Theme.orange.opacity(0.14))
        .foregroundStyle(verified ? Theme.green : Theme.orange)
        .clipShape(Capsule())
    }
}


struct UniversityPhoto: View {
    let seed: String
    var remoteURL: String? = nil
    var height: CGFloat = 170

    private static let urls = [
        "https://images.unsplash.com/photo-1564981797816-1043664bf78d?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1541339907198-e08756dedf3f?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1592280771190-3e2e4d571952?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1606761568499-6d2451b23c66?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1498243691581-b145c3f54a5a?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1503676260728-1c00da094a0b?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1567168544813-cc03465b4fa8?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1560523159-4a9692d222ef?auto=format&fit=crop&w=1200&q=84",
        "https://images.unsplash.com/photo-1560785496-3c9d27877182?auto=format&fit=crop&w=1200&q=84"
    ]

    private var seedValue: Int {
        seed.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
    }

    private var stockURL: URL? {
        URL(string: Self.urls[seedValue % Self.urls.count])
    }

    private var primaryURL: URL? {
        guard let remoteURL,
              !remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return URL(string: remoteURL)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.surfaceRaised,
                    seedValue.isMultiple(of: 2)
                        ? Theme.navy
                        : Theme.orange.opacity(0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let primaryURL {
                AsyncImage(url: primaryURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure:
                        stockImage
                    default:
                        placeholder
                    }
                }
            } else {
                stockImage
            }

            LinearGradient(
                colors: [.clear, Theme.navyDeep.opacity(0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    @ViewBuilder
    private var stockImage: some View {
        if let stockURL {
            AsyncImage(url: stockURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                case .failure:
                    fallbackMark
                default:
                    placeholder
                }
            }
        } else {
            fallbackMark
        }
    }

    private var placeholder: some View {
        ZStack {
            Theme.surface

            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.ink.opacity(0.04))
                .frame(width: 76, height: 52)
                .overlay {
                    Image(systemName: "building.columns")
                        .foregroundStyle(Theme.ink.opacity(0.30))
                }
        }
    }

    private var fallbackMark: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.surfaceRaised, Theme.navy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "building.columns.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.orangeSoft.opacity(0.72))
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt: String = "Search scholarships..."
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.muted)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit {
                    dismissKeyboard()
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()

                        Button("Done") {
                            dismissKeyboard()
                        }
                    }
                }
                .foregroundStyle(Theme.ink)

            if !text.isEmpty {
                Button {
                    text = ""
                    dismissKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private func dismissKeyboard() {
        isFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}


struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}


struct UniversityLogo: View {
    let university: University?
    let fallbackName: String
    var size: CGFloat = 40

    private var initials: String {
        let source = university?.name ?? fallbackName
        let words = source.split(separator: " ")

        if words.count >= 2 {
            return (
                String(words[0].prefix(1)) +
                String(words[1].prefix(1))
            ).uppercased()
        }

        return String(source.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(Theme.surfaceRaised)

            if let logoURL = university?.logoUrl,
               let url = URL(string: logoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.12)
                    default:
                        Text(initials)
                            .font(.system(size: size * 0.28, weight: .bold))
                            .foregroundStyle(Theme.ink)
                    }
                }
            } else {
                Text(initials)
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28)
                .stroke(Theme.blue.opacity(0.22))
        )
    }
}


struct OfflineBanner: View {
    var body: some View {
        Label(
            "You’re offline. Some content may be unavailable.",
            systemImage: "wifi.slash"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(.ultraThinMaterial)
        .background(Theme.navy.opacity(0.92))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.18),
            radius: 10,
            x: 0,
            y: 4
        )
        .accessibilityLabel(
            "Offline. Some content may be unavailable."
        )
    }
}

/// A visible alternative to the pull-to-refresh gesture, including empty lists.
struct RefreshButton: View {
    let loading: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Group {
                if loading {
                    ProgressView().tint(Theme.accent)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(width: 44, height: 44)
            .foregroundStyle(Theme.accent)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .disabled(loading)
        .accessibilityLabel(loading ? "Refreshing" : "Refresh")
    }
}
