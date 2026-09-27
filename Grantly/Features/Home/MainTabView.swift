import SwiftUI

private enum MainTab: Hashable {
    case home
    case explore
    case saved
    case community
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
                    openProfile: { selection = .profile }
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
                Label("Cases", systemImage: "folder.fill")
            }
            .tag(MainTab.saved)

            NavigationStack {
                CommunityView()
            }
            .tabItem {
                Label("Community", systemImage: "person.2.fill")
            }
            .tag(MainTab.community)

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
        .preferredColorScheme(.dark)
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
