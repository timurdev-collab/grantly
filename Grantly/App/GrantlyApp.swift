import SwiftUI

@main
struct GrantlyApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .tint(Theme.violet)
                .onOpenURL { url in
                    Task {
                        await auth.handleDeepLink(url)
                    }
                }
        }
    }
}
