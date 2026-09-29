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
    @State private var loadingProfile = true
    @State private var profileLoadError: String?

    var body: some View {
        Group {
            if loadingProfile {
                ZStack {
                    Theme.pageBackground.ignoresSafeArea()
                    ProgressView()
                        .tint(Theme.accent)
                }
            } else if let profile {
                switch profile.role {
                case "admin":
                    AdminPortalView(profile: $profile)
                case "advisor":
                    AdvisorPortalView(profile: $profile)
                default:
                    StudentMainTabs(profile: $profile)
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.accentSoft)

                    Text("Unable to load your account")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)

                    Text(
                        profileLoadError ??
                        "We could not confirm your account role. Try again before continuing."
                    )
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                    Button("Try again") {
                        Task { await loadProfile() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.pageBackground)
            }
        }
        .task {
            await loadProfile()
            await NotificationRegistration
                .requestAuthorizationAndRegister()
        }
    }

    @MainActor
    private func loadProfile() async {
        loadingProfile = true
        profileLoadError = nil
        defer { loadingProfile = false }

        do {
            let userId = try await supabase.auth.session.user.id
            profile = try await DataService.currentProfile(userId: userId)
        } catch {
            profile = nil
            profileLoadError = L10n.string(
                "Your profile could not be loaded securely. Please check your connection and try again."
            )
        }
    }
}

private struct StudentMainTabs: View {
    @Binding var profile: StudentProfile?
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
                Label(
                    "Advisors",
                    systemImage: "person.crop.circle.badge.questionmark"
                )
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
        .tint(Theme.accent)
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
    }
}

private struct AdminPortalView: View {
    @Binding var profile: StudentProfile?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Admin Portal")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Theme.ink)

                        Text("Control students, advisors and Grantly operations")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }

                    NavigationLink {
                        AdminPeopleView()
                    } label: {
                        portalCard(
                            icon: "person.2.badge.gearshape",
                            title: "Students & Advisors",
                            subtitle:
                                "Approve advisors, suspend accounts and manage people"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AdminView()
                    } label: {
                        portalCard(
                            icon: "shield.checkered",
                            title: "Platform Control",
                            subtitle:
                                "Scholarships, safety, analytics, imports and system health"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ProfileView(profile: $profile)
                    } label: {
                        portalCard(
                            icon: "person.crop.circle.fill",
                            title: "Admin Profile",
                            subtitle: "Account settings and appearance"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(Theme.pageBackground)
            .navigationBarHidden(true)
        }
    }

    private func portalCard(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.accentSoft)
                .frame(width: 48, height: 48)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct AdvisorPortalView: View {
    @Binding var profile: StudentProfile?
    @State private var students: [AdvisorStudent] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var chatDestination: AdvisorChatDestination?
    @State private var callSession: AdvisorCallSession?

    private var pending: [AdvisorStudent] {
        students.filter { $0.status == "requested" }
    }

    private var active: [AdvisorStudent] {
        students.filter { $0.status == "active" }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Advisor Portal")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.ink)

                        Text(
                            "Manage students who registered with you"
                        )
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Theme.pageBackground)

                Section("Overview") {
                    HStack(spacing: 12) {
                        AdvisorPortalMetric(
                            value: "\(active.count)",
                            label: "Active"
                        )
                        AdvisorPortalMetric(
                            value: "\(pending.count)",
                            label: "Requests"
                        )
                    }
                }

                if !pending.isEmpty {
                    Section("Registration requests") {
                        ForEach(pending) { student in
                            AdvisorStudentRow(
                                student: student,
                                working: false,
                                primaryTitle: "Accept",
                                primaryAction: {
                                    Task {
                                        await manage(
                                            student,
                                            action: "accept"
                                        )
                                    }
                                },
                                secondaryTitle: "Decline",
                                secondaryAction: {
                                    Task {
                                        await manage(
                                            student,
                                            action: "decline"
                                        )
                                    }
                                },
                                messageAction: nil,
                                videoAction: nil
                            )
                        }
                    }
                }

                Section("My students") {
                    if loading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if active.isEmpty {
                        Text(
                            "Students you accept will appear here."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(active) { student in
                            AdvisorStudentRow(
                                student: student,
                                working: false,
                                primaryTitle: nil,
                                primaryAction: nil,
                                secondaryTitle: "End advising",
                                secondaryAction: {
                                    Task {
                                        await manage(
                                            student,
                                            action: "end"
                                        )
                                    }
                                },
                                messageAction: {
                                    Task {
                                        await openConversation(student)
                                    }
                                },
                                videoAction: {
                                    Task {
                                        await prepareVideoCall(student)
                                    }
                                }
                            )
                        }
                    }
                }

                Section("Advisor tools") {
                    NavigationLink {
                        MessagesView()
                    } label: {
                        Label(
                            "Messages",
                            systemImage: "bubble.left.and.bubble.right.fill"
                        )
                    }

                    NavigationLink {
                        ProfileView(profile: $profile)
                    } label: {
                        Label(
                            "Profile & settings",
                            systemImage: "person.crop.circle.fill"
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.pageBackground)
            .navigationBarHidden(true)
            .refreshable { await load() }
            .task { await load() }
            .sheet(item: $chatDestination) { destination in
                NavigationStack {
                    ChatView(
                        conversationId: destination.conversationId,
                        otherUserId: destination.otherUserId,
                        title: destination.title
                    )
                }
            }
            .sheet(item: $callSession) { session in
                AdvisorCallPreparationView(session: session)
            }
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            students = try await DataService.advisorMyStudents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openConversation(
        _ student: AdvisorStudent
    ) async {
        do {
            let conversationId =
                try await DataService.ensureAdvisorConversation(
                    assignmentId: student.assignmentId
                )

            chatDestination = AdvisorChatDestination(
                conversationId: conversationId,
                otherUserId: student.studentId,
                title: student.fullName ?? "Student"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func prepareVideoCall(
        _ student: AdvisorStudent
    ) async {
        do {
            callSession =
                try await DataService.createAdvisorCallSession(
                    assignmentId: student.assignmentId
                )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func manage(
        _ student: AdvisorStudent,
        action: String
    ) async {
        do {
            try await DataService.advisorManageStudent(
                assignmentId: student.assignmentId,
                action: action
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdvisorPortalMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct AdvisorStudentRow: View {
    let student: AdvisorStudent
    let working: Bool
    let primaryTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?
    let messageAction: (() -> Void)?
    let videoAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                student.fullName?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty == false
                    ? student.fullName!
                    : "Student"
            )
            .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                if let degree = student.degreeLevel,
                   !degree.isEmpty {
                    Label(
                        degree,
                        systemImage: "graduationcap"
                    )
                }

                if let major = student.intendedMajor,
                   !major.isEmpty {
                    Text(major)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let countries = student.targetCountries,
               !countries.isEmpty {
                Text(
                    "Targets: " +
                    countries.prefix(3).joined(separator: ", ")
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if let messageAction,
               let videoAction {
                HStack(spacing: 8) {
                    Button(action: messageAction) {
                        Label("Message", systemImage: "bubble.left.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: videoAction) {
                        Label("Video", systemImage: "video.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack {
                if let primaryTitle,
                   let primaryAction {
                    Button(
                        primaryTitle,
                        action: primaryAction
                    )
                    .buttonStyle(.borderedProminent)
                    .disabled(working)
                }

                if let secondaryTitle,
                   let secondaryAction {
                    Button(
                        secondaryTitle,
                        role: secondaryTitle == "Decline" ? .destructive : nil,
                        action: secondaryAction
                    )
                    .buttonStyle(.bordered)
                    .disabled(working)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
