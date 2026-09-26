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
                Label("Explore", systemImage: "books.vertical.fill")
            }
            .tag(MainTab.explore)

            NavigationStack {
                MyScholarshipsView()
            }
            .tabItem {
                Label("Shortlist", systemImage: "bookmark.fill")
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
        .tint(Theme.brass)
        .toolbarBackground(Theme.ivory, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            guard profile == nil,
                  let userId = try? await supabase.auth.session.user.id else {
                return
            }

            profile = try? await DataService.currentProfile(userId: userId)
        }
    }
}
