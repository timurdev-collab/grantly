import SwiftUI

struct CommunityView: View {
    @State private var profiles: [CommunityProfile] = []
    @State private var query = ""
    @State private var loading = true

    private var filtered: [CommunityProfile] {
        guard !query.isEmpty else { return profiles }
        let q = query.lowercased()
        return profiles.filter {
            "\($0.displayName ?? "") \($0.nationality ?? "") \($0.major ?? "") \($0.targetCountries?.joined(separator: " ") ?? "")"
                .lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if filtered.isEmpty {
                EmptyState(icon: "person.3", title: "No students found", text: "Try a different search.")
            } else {
                List(filtered) { profile in
                    NavigationLink(value: profile) {
                        CommunityRow(profile: profile)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $query, prompt: "Name, country, major")
        .navigationTitle("Community")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MessagesView()
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
                .accessibilityLabel("Messages")
            }
        }
        .navigationDestination(for: CommunityProfile.self) { profile in
            CommunityProfileView(profile: profile)
        }
        .task {
            defer { loading = false }
            profiles = (try? await DataService.communityProfiles()) ?? []
        }
    }
}

struct CommunityRow: View {
    let profile: CommunityProfile

    var body: some View {
        HStack(spacing: 12) {
            Text((profile.displayName ?? "?").prefix(2).uppercased())
                .font(.caption.bold())
                .frame(width: 44, height: 44)
                .background(Theme.violet.opacity(0.12))
                .foregroundStyle(Theme.violet)
                .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName ?? "Student")
                    .font(.headline)

                Text([profile.nationality, profile.major].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CommunityProfileView: View {
    @Environment(AuthStore.self) private var auth
    let profile: CommunityProfile
    @State private var status = ""
    @State private var openingConversation = false
    @State private var showingReport = false

    var body: some View {
        VStack(spacing: 20) {
            Text((profile.displayName ?? "?").prefix(2).uppercased())
                .font(.title.bold())
                .frame(width: 82, height: 82)
                .background(Theme.violet.opacity(0.12))
                .foregroundStyle(Theme.violet)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            Text(profile.displayName ?? "Student")
                .font(.title2.bold())

            Text([profile.nationality, profile.major].compactMap { $0 }.joined(separator: " · "))
                .foregroundStyle(.secondary)

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .multilineTextAlignment(.center)
            }

            if let countries = profile.targetCountries, !countries.isEmpty {
                VStack {
                    Text("Target countries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(countries.joined(separator: " · "))
                        .font(.subheadline.bold())
                }
            }

            Button {
                Task {
                    guard profile.id != auth.userId else { return }
                    openingConversation = true
                    defer { openingConversation = false }

                    do {
                        _ = try await DataService.startDirectConversation(otherUser: profile.id)
                        status = "Conversation created. Tap the messages icon in Community."
                    } catch {
                        status = error.localizedDescription
                    }
                }
            } label: {
                Label(openingConversation ? "Opening…" : "Start conversation", systemImage: "message.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(profile.id == auth.userId || openingConversation)

            if profile.id != auth.userId {
                Button {
                    showingReport = true
                } label: {
                    Label("Report student", systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Student")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReport) {
            ReportSheet(subject: profile.displayName ?? "student") { reason, details in
                try await DataService.submitSafetyReport(
                    reportedUserId: profile.id,
                    reason: reason,
                    details: details
                )
            }
        }
    }
}
