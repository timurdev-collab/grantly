import SwiftUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Binding var profile: StudentProfile?

    @State private var fullName = ""
    @State private var nationality = ""
    @State private var residenceCountry = ""
    @State private var graduationYear = ""
    @State private var gpaValue = ""
    @State private var gpaScale = "10"
    @State private var ielts = ""
    @State private var intendedMajor = ""
    @State private var degreeLevel = "Bachelor"
    @State private var targetRegions = ""
    @State private var targetCountries = ""
    @State private var familyIncome = ""
    @State private var bio = ""
    @State private var visible = true
    @State private var status = ""
    @State private var saving = false
    @State private var showingDeleteAccount = false
    @State private var deletingAccount = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    GrantlyMonogram(size: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        SectionEyebrow(text: "Academic identity")

                        Text(
                            fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Build your Grantly profile"
                                : fullName
                        )
                        .font(Theme.serifTitle(22))
                        .foregroundStyle(.white)

                        Text("Your private profile powers scholarship matching.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Theme.surface)

            Section("Student profile") {
                TextField("Full name", text: $fullName)
                TextField("Nationality", text: $nationality)
                TextField("Country of residence", text: $residenceCountry)
                TextField("Graduation year", text: $graduationYear)
                    .keyboardType(.numberPad)
                TextField("GPA", text: $gpaValue)
                    .keyboardType(.decimalPad)
                TextField("GPA scale", text: $gpaScale)
                    .keyboardType(.decimalPad)
                TextField("IELTS", text: $ielts)
                    .keyboardType(.decimalPad)
                TextField("Intended major", text: $intendedMajor)
                Picker("Degree", selection: $degreeLevel) {
                    ForEach(["Bachelor", "Master", "PhD"], id: \.self) { Text($0) }
                }
            }

            Section("Preferences") {
                TextField("Target regions, comma separated", text: $targetRegions)
                TextField("Target countries, comma separated", text: $targetCountries)
                TextField("Family annual income, USD", text: $familyIncome)
                    .keyboardType(.decimalPad)
            }

            Section("Community") {
                TextField("Short bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                Toggle("Show my community profile", isOn: $visible)
                Text("Your GPA, IELTS and family income are never copied into your public community profile.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))

                NavigationLink("Blocked students") {
                    BlockedUsersView()
                }
            }

            if !status.isEmpty {
                Section {
                    if status == "Profile saved." {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    } else {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                Button(saving ? "Saving…" : "Save profile") {
                    Task { await save() }
                }
                .disabled(saving || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Privacy & safety") {
                NavigationLink("Privacy & Safety") {
                    PrivacyAndSafetyView()
                }
            }

            Section("Account") {
                Button("Sign out") {
                    Task { await auth.signOut() }
                }

                Button(
                    deletingAccount ? "Deleting account…" : "Delete account",
                    role: .destructive
                ) {
                    showingDeleteAccount = true
                }
                .disabled(deletingAccount)
            }

            if profile?.role == "admin" {
                Section("Administration") {
                    NavigationLink("Open admin dashboard") {
                        AdminView()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .tint(Theme.orange)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await populate() }
        .alert("Delete your Grantly account?", isPresented: $showingDeleteAccount) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, profile, saved scholarships and messages. This cannot be undone.")
        }
    }

    private func csv(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    @MainActor
    private func populate() async {
        guard let userId = auth.userId else { return }

        if profile == nil {
            profile = try? await DataService.currentProfile(userId: userId)
        }

        guard let p = profile else { return }

        fullName = p.fullName ?? ""
        nationality = p.nationality ?? ""
        residenceCountry = p.residenceCountry ?? ""
        graduationYear = p.graduationYear.map { String($0) } ?? ""
        gpaValue = p.gpaValue.map { String($0) } ?? ""
        gpaScale = p.gpaScale.map { String($0) } ?? "10"
        ielts = p.ielts.map { String($0) } ?? ""
        intendedMajor = p.intendedMajor ?? ""
        degreeLevel = p.degreeLevel ?? "Bachelor"
        targetRegions = p.targetRegions?.joined(separator: ", ") ?? ""
        targetCountries = p.targetCountries?.joined(separator: ", ") ?? ""
        familyIncome = p.familyIncomeUSD.map { String($0) } ?? ""

        if let community = try? await DataService.currentCommunityProfile(userId: userId) {
            bio = community.bio ?? ""
            visible = community.isVisible ?? true
        }
    }

    @MainActor
    private func deleteAccount() async {
        deletingAccount = true
        defer { deletingAccount = false }

        if !(await auth.deleteAccount()) {
            status = auth.errorMessage ?? "Your account could not be deleted."
        }
    }

    @MainActor
    private func save() async {
        guard let userId = auth.userId else { return }

        saving = true
        status = ""
        defer { saving = false }

        if let value = Double(ielts), !(0...9).contains(value) {
            status = "IELTS must be between 0 and 9."
            return
        }

        if let gpa = Double(gpaValue),
           let scale = Double(gpaScale),
           (scale <= 0 || gpa < 0 || gpa > scale) {
            status = "Please check your GPA and GPA scale."
            return
        }

        do {
            try await DataService.updateProfile(
                userId: userId,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                nationality: nationality.trimmingCharacters(in: .whitespacesAndNewlines),
                residenceCountry: residenceCountry.trimmingCharacters(in: .whitespacesAndNewlines),
                graduationYear: Int(graduationYear),
                gpaValue: Double(gpaValue),
                gpaScale: Double(gpaScale),
                ielts: Double(ielts),
                intendedMajor: intendedMajor.trimmingCharacters(in: .whitespacesAndNewlines),
                degreeLevel: degreeLevel,
                targetRegions: csv(targetRegions),
                targetCountries: csv(targetCountries),
                familyIncomeUSD: Double(familyIncome)
            )

            try await DataService.updateCommunityProfile(
                userId: userId,
                displayName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                nationality: nationality.trimmingCharacters(in: .whitespacesAndNewlines),
                major: intendedMajor.trimmingCharacters(in: .whitespacesAndNewlines),
                targetRegions: csv(targetRegions),
                targetCountries: csv(targetCountries),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                isVisible: visible
            )

            profile = try await DataService.currentProfile(userId: userId)
            status = "Profile saved."
        } catch {
            status = error.localizedDescription
        }
    }
}


private struct BlockedStudentRow: Identifiable {
    let id: UUID
    let name: String
}

private struct BlockedUsersView: View {
    @State private var rows: [BlockedStudentRow] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if rows.isEmpty {
                EmptyState(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "No blocked students",
                    text: "Students you block will appear here."
                )
            } else {
                List {
                    ForEach(rows) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.name)
                                    .font(.headline)
                                Text(row.id.uuidString.prefix(8))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.62))
                            }

                            Spacer()

                            Button("Unblock") {
                                Task { await unblock(row) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Blocked Students")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Unable to update block", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }

        do {
            async let blockedIDs = DataService.blockedUserIDs()
            async let visibleProfiles = DataService.communityProfiles()

            let ids = try await blockedIDs
            let profiles = try await visibleProfiles
            let names = Dictionary(
                uniqueKeysWithValues: profiles.map {
                    ($0.id, $0.displayName ?? "Student")
                }
            )

            rows = ids
                .map {
                    BlockedStudentRow(
                        id: $0,
                        name: names[$0] ?? "Student"
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func unblock(_ row: BlockedStudentRow) async {
        do {
            try await DataService.unblockUser(row.id)
            rows.removeAll { $0.id == row.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


private struct PrivacyAndSafetyView: View {
    var body: some View {
        List {
            Section("Your data") {
                Label(
                    "Your academic profile and family income are private to your account.",
                    systemImage: "lock.shield"
                )

                Label(
                    "Your Community profile is separate and can be hidden at any time from Profile.",
                    systemImage: "person.3"
                )

                Label(
                    "Saved scholarships, application statuses and notes are visible only to your account.",
                    systemImage: "bookmark"
                )
            }

            Section("Community safety") {
                Label(
                    "Avoid sharing passwords, financial account details, identity documents or other sensitive information in messages.",
                    systemImage: "exclamationmark.shield"
                )

                Label(
                    "You can report a student or message and block a student whenever needed.",
                    systemImage: "hand.raised"
                )

                Label(
                    "Blocking disables new direct messages between the two accounts.",
                    systemImage: "person.crop.circle.badge.xmark"
                )
            }

            Section("Scholarship information") {
                Text("Grantly helps you discover and organize opportunities. Always confirm deadlines, eligibility and benefits on the official scholarship website before applying.")
                    .foregroundStyle(.white.opacity(0.62))
            }

            Section("Account control") {
                Text("You can permanently delete your Grantly account from Profile. Deleting the authentication account also removes linked profile and user-owned app data according to the database relationships.")
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .navigationTitle("Privacy & Safety")
        .navigationBarTitleDisplayMode(.inline)
    }
}
