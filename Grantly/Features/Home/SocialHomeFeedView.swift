import SwiftUI

// Community posting, stories, shorts, uploads, and comment composition are
// intentionally disabled as of EduT 1.0.1's data-minimization update.
struct SocialHomeFeedView: View {
    let currentAvatarURL: String?
    let currentName: String?
    let onChanged: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.title2)
            Text("Community posting is no longer available.")
                .font(.subheadline)
            Text("Scholarship discovery and advisor messaging remain available.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
