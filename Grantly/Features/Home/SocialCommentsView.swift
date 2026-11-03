import SwiftUI

// Social comments have been disabled; advisor and direct messaging is separate.
struct SocialCommentsView: View {
    let post: SocialPost
    let onChanged: () async -> Void

    var body: some View {
        ContentUnavailableView(
            "Comments unavailable",
            systemImage: "bubble.left.slash",
            description: Text("Community comments are no longer collected.")
        )
    }
}
