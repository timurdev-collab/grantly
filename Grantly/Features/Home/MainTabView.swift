import SwiftUI
import UIKit

private enum MainTab: Hashable {
    case home
    case explore
    case saved
    case messages
    case profile
}

private enum AdminExperience: String, CaseIterable {
    case admin
    case advisor
    case student

    var title: String {
        L10n.string(rawValue.capitalized)
    }

    var icon: String {
        switch self {
        case .admin: return "shield.fill"
        case .advisor: return "person.crop.circle.badge.questionmark"
        case .student: return "graduationcap.fill"
        }
    }
}

struct MainTabView: View {
    @State private var profile: StudentProfile?
    @State private var loadingProfile = true
    @State private var profileLoadError: String?
    @State private var adminExperience: AdminExperience = .admin

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
                    switch adminExperience {
                    case .admin:
                        AdminPortalView(
                            profile: $profile,
                            onSelectExperience: {
                                adminExperience = $0
                            }
                        )
                    case .advisor:
                        AdminAdvisorExperienceView(
                            profile: $profile,
                            returnToAdmin: {
                                adminExperience = .admin
                            }
                        )
                    case .student:
                        StudentMainTabs(
                            profile: $profile,
                            adminReturnAction: {
                                adminExperience = .admin
                            }
                        )
                    }
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
                        L10n.string(
                            "We could not confirm your account role. Try again before continuing."
                        )
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
    var adminReturnAction: (() -> Void)? = nil

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
                Label(
                    "Home",
                    systemImage: selection == .home ? "house.fill" : "house"
                )
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
                Label(
                    "Applications",
                    systemImage: selection == .saved ? "folder.fill" : "folder"
                )
            }
            .tag(MainTab.saved)

            NavigationStack {
                MessagesView()
            }
            .tabItem {
                Label(
                    "Messages",
                    systemImage: selection == .messages
                        ? "bubble.left.and.bubble.right.fill"
                        : "bubble.left.and.bubble.right"
                )
            }
            .tag(MainTab.messages)

            NavigationStack {
                ProfileView(profile: $profile)
            }
            .tabItem {
                Label(
                    "Profile",
                    systemImage: selection == .profile
                        ? "person.crop.circle.fill"
                        : "person.crop.circle"
                )
            }
            .tag(MainTab.profile)
        }
        .preferredColorScheme(.light)
        .tint(Theme.premiumForest)
        .toolbarColorScheme(.light, for: .tabBar)
        .toolbarBackground(
            Color(
                red: 247 / 255,
                green: 243 / 255,
                blue: 232 / 255
            ).opacity(0.94),
            for: .tabBar
        )
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
        .overlay(alignment: .topLeading) {
            if let adminReturnAction {
                Button(action: adminReturnAction) {
                    Label("Admin", systemImage: "shield.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(Theme.surface)
                        .foregroundStyle(Theme.ink)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Theme.ink.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.leading, 16)
            }
        }
    }
}

private struct AdminPortalView: View {
    @Binding var profile: StudentProfile?
    let onSelectExperience: (AdminExperience) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Admin Portal")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Theme.ink)

                            Text("Control students, advisors and EduT operations")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        LanguageFlagMenu()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("View EduT as")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)

                        HStack(spacing: 8) {
                            ForEach(AdminExperience.allCases, id: \.self) { mode in
                                Button {
                                    onSelectExperience(mode)
                                } label: {
                                    Label(mode.title, systemImage: mode.icon)
                                        .font(.caption.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(
                                            mode == .admin
                                                ? Theme.accent
                                                : Theme.surface
                                        )
                                        .foregroundStyle(
                                            mode == .admin
                                                ? Theme.onAccent
                                                : Theme.ink
                                        )
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 12)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(
                            "Student and Advisor views let you inspect the product without changing your real admin role."
                        )
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

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
                        AdminConsultationPaymentsView()
                    } label: {
                        portalCard(
                            icon: "creditcard.fill",
                            title: "Consultation Payments",
                            subtitle:
                                "Verify payments before advisor contact details unlock"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ProfileView(profile: $profile, showsNavigationBar: true)
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
                Text(L10n.string(title))
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Text(L10n.string(subtitle))
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

private struct AdminAdvisorExperienceView: View {
    @Binding var profile: StudentProfile?
    let returnToAdmin: () -> Void

    @State private var assignments: [AdminAdvisorAssignment] = []
    @State private var loading = true
    @State private var errorMessage: String?

    private var activeCount: Int {
        assignments.filter { $0.status == "active" }.count
    }

    private var requestCount: Int {
        assignments.filter { $0.status == "requested" }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Advisor View")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(Theme.ink)

                            Text(
                                "Admin preview of the live advisor workflow"
                            )
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        LanguageFlagMenu()
                    }
                    .padding(.vertical, 8)

                    Button(action: returnToAdmin) {
                        Label(
                            "Return to Admin",
                            systemImage: "shield.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }
                .listRowBackground(Theme.pageBackground)

                Section("Overview") {
                    HStack(spacing: 12) {
                        AdvisorPortalMetric(
                            value: "\(activeCount)",
                            label: "Active"
                        )
                        AdvisorPortalMetric(
                            value: "\(requestCount)",
                            label: "Requests"
                        )
                    }
                }

                Section("Advisor assignments") {
                    if loading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if assignments.isEmpty {
                        Text("No advisor assignments yet.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    } else {
                        ForEach(assignments) { row in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(row.advisorName)
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()

                                    Text(row.status.capitalized)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Theme.accentSoft)
                                }

                                Text(row.studentName)
                                    .font(.caption)
                                    .foregroundStyle(Theme.ink)

                                if let email = row.studentEmail,
                                   !email.isEmpty {
                                    Text(email)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    Text(
                        "Admin preview does not impersonate an advisor for private messages or calls. Use an actual advisor account to test identity-specific communication."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
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
                        ProfileView(profile: $profile, showsNavigationBar: true)
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
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.pageBackground)
            .navigationBarHidden(true)
            .refreshable { await load() }
            .task { await load() }
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            assignments = try await DataService.adminAdvisorAssignments()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminConsultationPaymentsView: View {
    @State private var requests: [AdminConsultationRequest] = []
    @State private var loading = true
    @State private var workingRequestID: UUID?
    @State private var errorMessage: String?

    private var actionableRequests: [AdminConsultationRequest] {
        requests.filter {
            !["paid", "completed", "cancelled"].contains($0.status)
        }
    }

    var body: some View {
        List {
            Section {
                Text(
                    "Only EduT admins can mark a consultation as paid. Advisor contact details stay locked until this step."
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }

            Section("Pending payment verification") {
                if loading && requests.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if actionableRequests.isEmpty {
                    Text("No consultation payments are waiting for verification.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                } else {
                    ForEach(actionableRequests) { request in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(request.studentName)
                                    .font(.subheadline.weight(.semibold))

                                Spacer()

                                Text(advisorConsultationStatus(request.status))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accentSoft)
                            }

                            Text(
                                "\(request.serviceTitle) · \(request.durationMinutes) min"
                            )
                            .font(.caption)

                            Text("Advisor: \(request.advisorName)")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)

                            Text(
                                String(
                                    format: "%@ %.2f",
                                    request.currency,
                                    Double(request.quotedPriceCents) / 100.0
                                )
                            )
                            .font(.caption.weight(.semibold))

                            Button {
                                Task {
                                    await markPaid(request)
                                }
                            } label: {
                                if workingRequestID == request.id {
                                    ProgressView()
                                } else {
                                    Label(
                                        "Mark payment received",
                                        systemImage: "checkmark.seal.fill"
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .disabled(workingRequestID != nil)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle("Consultation Payments")
        .refreshable { await load() }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            requests = try await DataService.adminConsultationRequests()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func markPaid(_ request: AdminConsultationRequest) async {
        workingRequestID = request.id
        defer { workingRequestID = nil }

        do {
            try await DataService.adminMarkConsultationPaid(
                requestId: request.id
            )
            requests = try await DataService.adminConsultationRequests()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdvisorPortalView: View {
    @Binding var profile: StudentProfile?
    @State private var students: [AdvisorStudent] = []
    @State private var consultationRequests:
        [AdvisorIncomingConsultationRequest] = []
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

    private var openConsultationCount: Int {
        consultationRequests.filter {
            !["completed", "cancelled"].contains($0.status)
        }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 12) {
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

                        Spacer()

                        LanguageFlagMenu()
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
                        AdvisorPortalMetric(
                            value: "\(openConsultationCount)",
                            label: "Consultations"
                        )
                    }
                }

                if !consultationRequests.isEmpty {
                    Section("Consultation requests") {
                        ForEach(consultationRequests) { request in
                            AdvisorIncomingConsultationRow(
                                request: request,
                                onStatusChange: { status in
                                    Task {
                                        await updateConsultation(
                                            request,
                                            status: status
                                        )
                                    }
                                }
                            )
                        }
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
                        ProfileView(profile: $profile, showsNavigationBar: true)
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
                        title: destination.title,
                        showsCloseButton: true
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
            async let studentRows = DataService.advisorMyStudents()
            async let consultationRows =
                DataService.advisorIncomingConsultationRequests()

            students = try await studentRows
            consultationRequests = try await consultationRows
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
    private func updateConsultation(
        _ request: AdvisorIncomingConsultationRequest,
        status: String
    ) async {
        do {
            try await DataService.advisorUpdateConsultationRequest(
                requestId: request.id,
                status: status
            )
            consultationRequests =
                try await DataService
                    .advisorIncomingConsultationRequests()
            errorMessage = nil
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

private struct AdvisorIncomingConsultationRow: View {
    let request: AdvisorIncomingConsultationRequest
    let onStatusChange: (String) -> Void

    private var contactUnlocked: Bool {
        ["paid", "confirmed", "completed"].contains(request.status)
    }

    private var whatsappURL: URL? {
        guard contactUnlocked,
              let number = request.whatsappNumber else {
            return nil
        }

        let digits = number.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        return URL(string: "https://wa.me/\(digits)")
    }

    private var emailURL: URL? {
        guard contactUnlocked,
              let email = request.contactEmail,
              !email.isEmpty else {
            return nil
        }

        let encoded = email
            .addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? email
        return URL(string: "mailto:\(encoded)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(request.studentName)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Menu {
                    statusButton(
                        "Awaiting payment",
                        value: "awaiting_payment"
                    )
                    statusButton("Confirmed", value: "confirmed")
                    statusButton("Completed", value: "completed")
                    statusButton(
                        "Cancelled",
                        value: "cancelled",
                        destructive: true
                    )
                } label: {
                    Label(
                        advisorConsultationStatus(request.status),
                        systemImage: "chevron.up.chevron.down"
                    )
                    .font(.caption2.weight(.semibold))
                }
            }

            Text(L10n.string(request.serviceTitle))
                .font(.caption)
                .foregroundStyle(Theme.ink)

            Text(
                "\(request.durationMinutes) min · " +
                String(
                    format: "%@ %.2f",
                    request.currency,
                    Double(request.quotedPriceCents) / 100.0
                )
            )
            .font(.caption2)
            .foregroundStyle(Theme.muted)

            Text(request.topic)
                .font(.caption)
                .foregroundStyle(Theme.muted)

            if let preferred = request.preferredStart {
                Text(
                    "Preferred: " +
                    advisorConsultationDate(preferred)
                )
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            }

            if contactUnlocked {
                HStack(spacing: 8) {
                    if let whatsappURL {
                        Link(destination: whatsappURL) {
                            Label("WhatsApp", systemImage: "message.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let emailURL {
                        Link(destination: emailURL) {
                            Label("Email", systemImage: "envelope.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text(
                    "Payment is recorded. Contact details are now available for consultation coordination."
                )
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            } else {
                Label(
                    "Contact details unlock after payment is recorded.",
                    systemImage: "lock.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func statusButton(
        _ title: String,
        value: String,
        destructive: Bool = false
    ) -> some View {
        Button(
            role: destructive ? .destructive : nil
        ) {
            onStatusChange(value)
        } label: {
            Text(L10n.string(title))
        }
    }
}

private func advisorConsultationStatus(
    _ status: String
) -> String {
    switch status {
    case "requested": return L10n.string("Requested")
    case "contacted": return L10n.string("Contacted")
    case "awaiting_payment":
        return L10n.string("Awaiting payment")
    case "paid": return L10n.string("Paid")
    case "confirmed": return L10n.string("Confirmed")
    case "completed": return L10n.string("Completed")
    case "cancelled": return L10n.string("Cancelled")
    default: return status.capitalized
    }
}

private func advisorConsultationDate(
    _ value: String
) -> String {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: value) else {
        return String(value.prefix(16))
    }

    return DateFormatter.localizedString(
        from: date,
        dateStyle: .medium,
        timeStyle: .short
    )
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
