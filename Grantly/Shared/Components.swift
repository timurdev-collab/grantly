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
