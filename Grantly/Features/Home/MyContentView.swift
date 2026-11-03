import SwiftUI

// Publishing/editing user-created posts, stories and shorts has been removed.
struct MyContentView: View {
    var body: some View {
        ContentUnavailableView(
            "Community posts removed",
            systemImage: "rectangle.stack.badge.minus",
            description: Text("EduT no longer supports creating or uploading community content.")
        )
        .navigationTitle("My content")
    }
}
