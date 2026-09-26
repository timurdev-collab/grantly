import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Opening Grantly…")
            } else if auth.userId == nil {
                WelcomeView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: auth.userId)
    }
}

