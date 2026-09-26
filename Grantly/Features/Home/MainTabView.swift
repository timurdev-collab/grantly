import SwiftUI

struct MainTabView: View {
    @State private var profile: StudentProfile?

    var body: some View {
        TabView {

            NavigationStack {
                HomeView(profile: $profile)
            }
            .tabItem {
                Label("For You", systemImage: "sparkles")
            }

            NavigationStack {
                ScholarshipsView()
            }
            .tabItem {
                Label("Explore", systemImage: "globe")
            }

            NavigationStack {
                MyScholarshipsView()
            }
            .tabItem {
                Label("My Scholarships", systemImage: "bookmark.fill")
            }

            NavigationStack {
                CommunityView()
            }
            .tabItem {
                Label("Community", systemImage: "person.3.fill")
            }

            NavigationStack {
                MessagesView()
            }
            .tabItem {
                Label(
                    "Messages",
                    systemImage: "bubble.left.and.bubble.right.fill"
                )
            }

            NavigationStack {
                ProfileView(profile: $profile)
            }
            .tabItem {
                Label(
                    "Profile",
                    systemImage: "person.crop.circle.fill"
                )
            }
        }
        .task {
            guard profile == nil,
                  let userId = try? await supabase.auth.session.user.id else {
                return
            }

            profile = try? await DataService.currentProfile(
                userId: userId
            )
        }
    }
}
