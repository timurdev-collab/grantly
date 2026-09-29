import AVKit
import SwiftUI
import LiveKit
import UIKit
import Combine

struct AdvisorsView: View {
    @State private var advisors: [AdvisorDirectoryProfile] = []
    @State private var registration: AdvisorRegistration?
    @State private var loading = true
    @State private var requestingAdvisorID: UUID?
    @State private var errorMessage: String?
    @State private var chatDestination: AdvisorChatDestination?
    @State private var callSession: AdvisorCallSession?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Advisors")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.ink)

                    Text(
                        "Choose a verified advisor to support your study plans"
                    )
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                }

                if let registration {
                    currentRegistrationCard(registration)
                }

                if loading && advisors.isEmpty {
                    ProgressView()
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Meet our advisors")
                                .font(.headline.bold())
                                .foregroundStyle(Theme.ink)

                            Spacer()

                            if !advisors.isEmpty {
                                Text("\(advisors.count) available")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }

                        Text(
                            "Open a profile to watch an introduction and learn how each advisor can help."
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.muted)

                        advisorGrid
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
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

    private func currentRegistrationCard(
        _ registration: AdvisorRegistration
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(
                registration.status == "active"
                    ? "Your advisor"
                    : "Advisor request pending"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accentSoft)

            Text(registration.advisorName)
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            if let title = registration.advisorTitle,
               !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            if registration.status == "active" {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await openConversation(registration)
                        }
                    } label: {
                        Label(
                            "Message",
                            systemImage: "bubble.left.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.orangeGradient)
                        .foregroundStyle(Theme.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await prepareVideoCall(registration)
                        }
                    } label: {
                        Label(
                            "Video",
                            systemImage: "video.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.surface)
                        .foregroundStyle(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(
                    "The advisor can accept your registration from their Advisor Portal."
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var advisorGrid: some View {
        let placeholderCount = max(0, 5 - advisors.count)
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(advisors) { advisor in
                NavigationLink {
                    AdvisorDetailView(
                        advisor: advisor,
                        registration: registration,
                        onRequest: {
                            await request(advisor)
                        }
                    )
                } label: {
                    advisorGridCard(advisor)
                }
                .buttonStyle(.plain)
            }

            ForEach(0..<placeholderCount, id: \.self) { _ in
                advisorPlaceholderCard
            }
        }
    }

    private func advisorGridCard(
        _ advisor: AdvisorDirectoryProfile
    ) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceRaised)
                    .frame(width: 72, height: 72)

                if let value = advisor.avatarUrl,
                   let url = URL(string: value) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 25))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(width: 68, height: 68)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(Theme.muted)
                }
            }

            Text(advisor.displayName ?? "Grantly Advisor")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let title = advisor.title,
               !title.isEmpty {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            if advisor.isFeatured {
                Label("Featured", systemImage: "star.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accentSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 178)
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var advisorPlaceholderCard: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Theme.surfaceRaised)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.muted.opacity(0.55))
                }

            Text("New advisor")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)

            Text("Coming soon")
                .font(.caption2)
                .foregroundStyle(Theme.muted.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 178)
        .padding(12)
        .background(Theme.surfaceRaised.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    Theme.ink.opacity(0.06),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Advisor coming soon")
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            async let directoryRows = DataService.availableAdvisors()
            async let currentRegistration =
                DataService.myAdvisorRegistration()

            advisors = try await directoryRows
            registration = try await currentRegistration
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openConversation(
        _ registration: AdvisorRegistration
    ) async {
        do {
            let conversationId =
                try await DataService.ensureAdvisorConversation(
                    assignmentId: registration.assignmentId
                )

            chatDestination = AdvisorChatDestination(
                conversationId: conversationId,
                otherUserId: registration.advisorId,
                title: registration.advisorName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func prepareVideoCall(
        _ registration: AdvisorRegistration
    ) async {
        do {
            callSession =
                try await DataService.createAdvisorCallSession(
                    assignmentId: registration.assignmentId
                )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func request(
        _ advisor: AdvisorDirectoryProfile
    ) async {
        requestingAdvisorID = advisor.id
        defer { requestingAdvisorID = nil }

        do {
            try await DataService.requestAdvisor(
                advisorId: advisor.id
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


struct AdvisorDetailView: View {
    let advisor: AdvisorDirectoryProfile
    let registration: AdvisorRegistration?
    let onRequest: () async -> Void

    @State private var requesting = false
    @State private var requestSent = false
    @State private var errorMessage: String?

    private var requestStateTitle: String {
        if requestSent ||
            registration?.advisorId == advisor.id {
            return registration?.status == "active"
                ? "Your advisor"
                : "Request sent"
        }

        if registration?.status == "active" {
            return "You already have an advisor"
        }

        return "Request this advisor"
    }

    private var canRequest: Bool {
        !requesting &&
        !requestSent &&
        registration?.advisorId != advisor.id &&
        registration?.status != "active"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                introductionVideo
                aboutSection
                expertiseSection
                linksSection

                Button {
                    Task {
                        requesting = true
                        defer { requesting = false }

                        await onRequest()
                        requestSent = true
                    }
                } label: {
                    Label(
                        requesting ? "Sending request…" : requestStateTitle,
                        systemImage: "person.badge.plus"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        canRequest
                            ? Theme.orangeGradient
                            : LinearGradient(
                                colors: [
                                    Theme.surfaceRaised,
                                    Theme.surfaceRaised
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .foregroundStyle(
                        canRequest ? Theme.onAccent : Theme.muted
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .disabled(!canRequest)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding()
            .padding(.bottom, 28)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Advisor")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceRaised)

                if let value = advisor.avatarUrl,
                   let url = URL(string: value) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(Circle())

            Text(advisor.displayName ?? "Grantly Advisor")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            if let title = advisor.title?.nonEmpty {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accentSoft)
                    .multilineTextAlignment(.center)
            }

            if let organization = advisor.organization?.nonEmpty {
                Text(organization)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            if let years = advisor.yearsExperience {
                Label(
                    "\(years) years experience",
                    systemImage: "briefcase.fill"
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private var introductionVideo: some View {
        if let value = advisor.introVideoUrl,
           let url = URL(string: value) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Introduction")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                if ["mp4", "mov", "m4v"]
                    .contains(url.pathExtension.lowercased()) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.accent)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Watch introduction")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)

                                Text("Opens the advisor's video")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(16)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            if let shortBio = advisor.shortBio?.nonEmpty {
                Text(shortBio)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }

            if let bio = advisor.bio?.nonEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
            }

            if let approach = advisor.mentoringApproach?.nonEmpty {
                Divider()

                Text("How I help")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Text(approach)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var expertiseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expertise")
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            if !advisor.specialties.isEmpty {
                AdvisorTagWrap(
                    title: "Specialties",
                    values: advisor.specialties
                )
            }

            if !advisor.countries.isEmpty {
                AdvisorTagWrap(
                    title: "Countries",
                    values: advisor.countries
                )
            }

            if !advisor.languages.isEmpty {
                AdvisorTagWrap(
                    title: "Languages",
                    values: advisor.languages
                )
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var linksSection: some View {
        if advisor.linkedinUrl?.nonEmpty != nil ||
            advisor.websiteUrl?.nonEmpty != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("Professional links")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                if let value = advisor.linkedinUrl,
                   let url = URL(string: value) {
                    Link(destination: url) {
                        Label(
                            "LinkedIn",
                            systemImage: "person.text.rectangle"
                        )
                    }
                }

                if let value = advisor.websiteUrl,
                   let url = URL(string: value) {
                    Link(destination: url) {
                        Label(
                            "Website",
                            systemImage: "globe"
                        )
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct AdvisorTagWrap: View {
    let title: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)

            Text(values.prefix(8).joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
        }
    }
}

struct AdvisorChatDestination: Identifiable {
    let conversationId: UUID
    let otherUserId: UUID
    let title: String

    var id: UUID { conversationId }
}

struct AdvisorCallPreparationView: View {
    @Environment(\.dismiss) private var dismiss
    @State var session: AdvisorCallSession
    @StateObject private var call = AdvisorCallController()
    @State private var recordingConsent = false
    @State private var savingConsent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        LiveKitTrackView(track: call.remoteVideoTrack)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                if call.remoteVideoTrack == nil {
                                    VStack(spacing: 10) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(Theme.accentSoft)

                                        Text(
                                            call.connected
                                                ? "Waiting for the other participant"
                                                : "Preparing secure video call"
                                        )
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    }
                                }
                            }

                        LiveKitTrackView(track: call.localVideoTrack)
                            .frame(width: 112, height: 154)
                            .background(Theme.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(
                                        Theme.ink.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                            .padding(12)
                    }
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 12) {
                        callControl(
                            icon: call.microphoneEnabled
                                ? "mic.fill"
                                : "mic.slash.fill",
                            active: call.microphoneEnabled
                        ) {
                            Task { await call.toggleMicrophone() }
                        }

                        callControl(
                            icon: call.cameraEnabled
                                ? "video.fill"
                                : "video.slash.fill",
                            active: call.cameraEnabled
                        ) {
                            Task { await call.toggleCamera() }
                        }

                        callControl(
                            icon: "rectangle.on.rectangle",
                            active: call.screenSharing
                        ) {
                            Task { await call.toggleScreenShare() }
                        }

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 52, height: 52)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                        }
                    }

                    Toggle(
                        "Allow session recording",
                        isOn: $recordingConsent
                    )
                    .tint(Theme.accent)
                    .onChange(of: recordingConsent) {
                        Task { await updateRecordingConsent() }
                    }

                    Text(
                        "Recording requires explicit consent from both the student and advisor. Screen sharing uses the iOS system capture permission."
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)

                    if let message = errorMessage ?? call.errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Advisor Video Call")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await connect()
            }
        }
    }

    private func callControl(
        icon: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 52, height: 52)
                .background(
                    active
                        ? Theme.accent
                        : Theme.surfaceRaised
                )
                .foregroundStyle(
                    active
                        ? Theme.onAccent
                        : Theme.ink
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func connect() async {
        do {
            let credentials =
                try await DataService.liveKitCallCredentials(
                    callId: session.id
                )
            try await call.connect(credentials)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateRecordingConsent() async {
        savingConsent = true
        defer { savingConsent = false }

        do {
            session =
                try await DataService
                    .setAdvisorCallRecordingConsent(
                        callId: session.id,
                        consent: recordingConsent
                    )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private final class AdvisorCallController:
    NSObject,
    ObservableObject,
    RoomDelegate
{
    @Published var localVideoTrack: VideoTrack?
    @Published var remoteVideoTrack: VideoTrack?
    @Published var connected = false
    @Published var cameraEnabled = false
    @Published var microphoneEnabled = false
    @Published var screenSharing = false
    @Published var errorMessage: String?

    lazy var room = Room(delegate: self)

    @MainActor
    func connect(
        _ credentials: LiveKitCallCredentials
    ) async throws {
        do {
            try await room.connect(
                url: credentials.url,
                token: credentials.token
            )

            try await room.localParticipant
                .setCamera(enabled: true)
            try await room.localParticipant
                .setMicrophone(enabled: true)

            connected = true
            cameraEnabled = true
            microphoneEnabled = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    @MainActor
    func toggleCamera() async {
        do {
            let next = !cameraEnabled
            try await room.localParticipant
                .setCamera(enabled: next)
            cameraEnabled = next
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func toggleMicrophone() async {
        do {
            let next = !microphoneEnabled
            try await room.localParticipant
                .setMicrophone(enabled: next)
            microphoneEnabled = next
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func toggleScreenShare() async {
        do {
            let next = !screenSharing
            try await room.localParticipant
                .setScreenShare(enabled: next)
            screenSharing = next
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func room(
        _: Room,
        participant _: LocalParticipant,
        didPublishTrack publication: LocalTrackPublication
    ) {
        guard let track = publication.track as? VideoTrack else {
            return
        }

        DispatchQueue.main.async {
            if publication.source == .camera {
                self.localVideoTrack = track
            }
        }
    }

    func room(
        _: Room,
        participant _: RemoteParticipant,
        didSubscribeTrack publication: RemoteTrackPublication
    ) {
        guard let track = publication.track as? VideoTrack else {
            return
        }

        DispatchQueue.main.async {
            self.remoteVideoTrack = track
        }
    }

    func room(
        _: Room,
        participant _: RemoteParticipant,
        didUnsubscribeTrack publication: RemoteTrackPublication
    ) {
        guard publication.track is VideoTrack else {
            return
        }

        DispatchQueue.main.async {
            self.remoteVideoTrack = nil
        }
    }
}

private struct LiveKitTrackView: UIViewRepresentable {
    let track: VideoTrack?

    func makeUIView(context: Context) -> VideoView {
        let view = VideoView()
        view.clipsToBounds = true
        return view
    }

    func updateUIView(
        _ uiView: VideoView,
        context: Context
    ) {
        uiView.track = track
    }
}

struct CommunityView: View {
    @State private var profiles: [CommunityProfile] = []
    @State private var blockedUserIDs: Set<UUID> = []
    @State private var query = ""
    @State private var loading = true

    private var filtered: [CommunityProfile] {
        profiles.filter { profile in
            guard !blockedUserIDs.contains(profile.id) else {
                return false
            }

            let q = query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard !q.isEmpty else {
                return true
            }

            let searchableText =
                "\(profile.displayName ?? "") " +
                "\(profile.nationality ?? "") " +
                "\(profile.major ?? "") " +
                "\(profile.targetCountries?.joined(separator: " ") ?? "")"

            return searchableText
                .lowercased()
                .contains(q)
        }
    }

    private var featured: [CommunityProfile] {
        Array(filtered.prefix(8))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                SearchField(
                    text: $query,
                    prompt: "Search students, countries or fields..."
                )

                communityHero

                if loading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.blue)

                        Text("Loading the Grantly community...")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else if filtered.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.3")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Theme.blueSoft)
                            .frame(width: 62, height: 62)
                            .background(Theme.surface)
                            .clipShape(Circle())

                        Text("No students found")
                            .font(.headline.bold())
                            .foregroundStyle(Theme.ink)

                        Text("Try another name, country or study field.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Students to connect with")
                                .font(.headline.bold())
                                .foregroundStyle(Theme.ink)

                            Text("\(filtered.count) visible community profiles")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        Image(systemName: "globe.americas.fill")
                            .foregroundStyle(Theme.blueSoft)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(featured) { profile in
                            NavigationLink(value: profile) {
                                CommunityRow(profile: profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationBarHidden(true)
        .navigationDestination(for: CommunityProfile.self) { profile in
            CommunityProfileView(profile: profile)
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Community")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Meet students pursuing opportunities worldwide")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            NavigationLink {
                MessagesView()
            } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.blueSoft)
                    .frame(width: 42, height: 42)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityLabel("Messages")
        }
    }

    private var communityHero: some View {
        ZStack(alignment: .bottomLeading) {
            UniversityPhoto(seed: "international students university community", height: 190)

            LinearGradient(
                colors: [
                    Theme.navyDeep.opacity(0.06),
                    Theme.navyDeep.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("GLOBAL COHORT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.blueSoft)

                Text("You are not applying\nalone.")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Connect around study goals, countries and universities while keeping sensitive academic details private.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .frame(maxWidth: 290, alignment: .leading)

                HStack(spacing: 14) {
                    Label("Private profile", systemImage: "lock.fill")
                    Label("Report & block", systemImage: "hand.raised.fill")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            }
            .padding(16)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        async let profileRows = DataService.communityProfiles()
        async let blockedRows = DataService.blockedUserIDs()

        profiles = (try? await profileRows) ?? []
        blockedUserIDs = (try? await blockedRows) ?? []
    }
}

struct CommunityRow: View {
    let profile: CommunityProfile

    private var destinations: String {
        let values = profile.targetCountries ?? []
        return values.isEmpty
            ? "Open to global opportunities"
            : values.prefix(3).joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 13) {
            CommunityAvatar(
                name: profile.displayName ?? "Student",
                imageURL: profile.avatarUrl,
                size: 54
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.displayName ?? "Student")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.ink)

                Text(
                    [profile.nationality, profile.major]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)

                Label(destinations, systemImage: "airplane")
                    .font(.caption2)
                    .foregroundStyle(Theme.blueSoft)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.ink.opacity(0.35))
        }
        .padding(13)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct CommunityAvatar: View {
    let name: String
    var imageURL: String? = nil
    var size: CGFloat = 54

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return (
                String(words[0].prefix(1)) +
                String(words[1].prefix(1))
            ).uppercased()
        }

        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.blueSoft.opacity(0.95), Theme.blue.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Text(initials)
                            .font(.system(size: size * 0.27, weight: .bold))
                            .foregroundStyle(Theme.ink)
                    }
                }
            } else {
                Text(initials)
                    .font(.system(size: size * 0.27, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Theme.ink.opacity(0.12))
        )
    }
}

struct CommunityProfileView: View {
    @Environment(AuthStore.self) private var auth

    let profile: CommunityProfile

    @State private var status = ""
    @State private var openingConversation = false
    @State private var showingReport = false
    @State private var isBlocked = false
    @State private var changingBlock = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                profileHeader

                if let bio = profile.bio,
                   !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ProfileInfoCard(
                        title: "About",
                        icon: "person.text.rectangle"
                    ) {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(4)
                    }
                }

                if let countries = profile.targetCountries,
                   !countries.isEmpty {
                    ProfileInfoCard(
                        title: "Destination goals",
                        icon: "airplane"
                    ) {
                        FlowingText(values: countries)
                    }
                }

                if let regions = profile.targetRegions,
                   !regions.isEmpty {
                    ProfileInfoCard(
                        title: "Target regions",
                        icon: "globe"
                    ) {
                        FlowingText(values: regions)
                    }
                }

                actions

                if !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationTitle("Student")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBlockState() }
        .sheet(isPresented: $showingReport) {
            ReportSheet(
                subject: profile.displayName ?? "student"
            ) { reason, details in
                try await DataService.submitSafetyReport(
                    reportedUserId: profile.id,
                    reason: reason,
                    details: details
                )
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            CommunityAvatar(
                name: profile.displayName ?? "Student",
                imageURL: profile.avatarUrl,
                size: 86
            )
            .padding(.top, 8)

            Text(profile.displayName ?? "Student")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(
                [profile.nationality, profile.major]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            )
            .font(.subheadline)
            .foregroundStyle(Theme.muted)

            HStack(spacing: 8) {
                Label("Community profile", systemImage: "person.2.fill")
                Label("Sensitive data hidden", systemImage: "lock.fill")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.blueSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Theme.surfaceRaised, Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if profile.id != auth.userId {
                Button {
                    Task { await startConversation() }
                } label: {
                    Label(
                        openingConversation
                            ? "Opening..."
                            : "Start conversation",
                        systemImage: "message.fill"
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(openingConversation || isBlocked)

                Button {
                    Task { await toggleBlock() }
                } label: {
                    Label(
                        changingBlock
                            ? "Updating..."
                            : (
                                isBlocked
                                    ? "Unblock student"
                                    : "Block student"
                            ),
                        systemImage: isBlocked
                            ? "person.crop.circle.badge.checkmark"
                            : "person.crop.circle.badge.xmark"
                    )
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(changingBlock)

                Button {
                    showingReport = true
                } label: {
                    Label(
                        "Report student",
                        systemImage: "exclamationmark.bubble"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                Text("This is your public community profile.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    @MainActor
    private func loadBlockState() async {
        guard profile.id != auth.userId else {
            return
        }

        let blocked = (try? await DataService.blockedUserIDs()) ?? []
        isBlocked = blocked.contains(profile.id)
    }

    @MainActor
    private func startConversation() async {
        guard profile.id != auth.userId,
              !isBlocked else {
            return
        }

        openingConversation = true
        defer { openingConversation = false }

        do {
            _ = try await DataService.startDirectConversation(
                otherUser: profile.id
            )

            status = L10n.string("Conversation created. Open Messages from Community.")
        } catch {
            status = error.localizedDescription
        }
    }

    @MainActor
    private func toggleBlock() async {
        changingBlock = true
        defer { changingBlock = false }

        do {
            if isBlocked {
                try await DataService.unblockUser(profile.id)
                isBlocked = false
                status = L10n.string("Student unblocked.")
            } else {
                try await DataService.blockUser(profile.id)
                isBlocked = true
                status = L10n.string("Student blocked. Messaging is disabled between your accounts.")
            }
        } catch {
            status = error.localizedDescription
        }
    }
}

private struct ProfileInfoCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.blueSoft)
                    .frame(width: 32, height: 32)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            content
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.05))
        )
    }
}

private struct FlowingText: View {
    let values: [String]

    var body: some View {
        Text(values.joined(separator: " · "))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.blueSoft)
            .lineSpacing(3)
    }
}
