import SwiftUI

private enum MainTab: Hashable {
    case home
    case explore
    case saved
    case advisors
    case profile
}

struct MainTabView: View {
    @State private var profile: StudentProfile?
    @State private var selection: MainTab = .home
    @State private var networkMonitor = NetworkMonitor()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(
                    profile: $profile,
                    openProfile: { selection = .profile },
                    openExplore: { selection = .explore },
                    openApplications: { selection = .saved }
                )
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(MainTab.home)

            NavigationStack {
                ScholarshipsView()
            }
            .tabItem {
                Label("Explore", systemImage: "magnifyingglass")
            }
            .tag(MainTab.explore)

            NavigationStack {
                CasesHubView()
            }
            .tabItem {
                Label("Applications", systemImage: "folder.fill")
            }
            .tag(MainTab.saved)

            NavigationStack {
                AdvisorsView()
            }
            .tabItem {
                Label("Advisors", systemImage: "person.crop.circle.badge.questionmark")
            }
            .tag(MainTab.advisors)

            NavigationStack {
                ProfileView(profile: $profile)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(MainTab.profile)
        }
        .tint(Theme.orange)
        .toolbarBackground(Theme.navyDeep, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)

        .overlay(alignment: .top) {
            if !networkMonitor.isOnline {
                OfflineBanner()
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                    )
            }
        }
        .animation(
            .easeInOut(duration: 0.2),
            value: networkMonitor.isOnline
        )
        .task {
            if profile == nil,
               let userId = try? await supabase.auth.session.user.id {
                profile = try? await DataService.currentProfile(
                    userId: userId
                )
            }

            await NotificationRegistration
                .requestAuthorizationAndRegister()
        }
    }
}
