import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Binding var profile: StudentProfile?
    @AppStorage("grantly.appearance") private var appearance: AppAppearance = .system
    @AppStorage("grantly.language") private var language: AppLanguage = .english

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
    @State private var showingEditProfile = false
    @State private var avatarURL: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var uploadingPhoto = false

    private var displayName: String {
        let value = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Your Grantly profile" : value
    }

    private var profileCompletion: Int {
        let fields = [
            fullName,
            nationality,
            residenceCountry,
            graduationYear,
            gpaValue,
            ielts,
            intendedMajor,
            targetCountries
        ]

        let complete = fields.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count

        return Int((Double(complete) / Double(fields.count)) * 100)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                header
                academicSnapshot
                destinationCard
                communityCard
                settingsCard

                if profile?.role == "student" {
                    NavigationLink {
                        AdvisorApplicationView(
                            defaultName: profile?.fullName ?? ""
                        )
                    } label: {
                        ProfileMenuRow(
                            icon: "person.crop.circle.badge.checkmark",
                            title: "Apply as an advisor",
                            subtitle: "Create a counselor profile for admin review",
                            tint: Theme.orangeSoft
                        )
                    }
                    .buttonStyle(.plain)
                }

                if profile?.role == "admin" {
                    NavigationLink {
                        AdminView()
                    } label: {
                        ProfileMenuRow(
                            icon: "shield.lefthalf.filled",
                            title: "Admin dashboard",
                            subtitle: "Scholarship and safety administration",
                            tint: Theme.blueSoft
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(
                            status == L10n.string("Profile saved.")
                                ? Theme.green
                                : Theme.danger
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                accountCard
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Theme.pageBackground)
        .navigationBarHidden(true)
        .task { await populate() }
        .sheet(isPresented: $showingEditProfile) {
            editProfileSheet
        }
        .alert(
            "Delete your Grantly account?",
            isPresented: $showingDeleteAccount
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, profile, saved scholarships and messages. This cannot be undone.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Profile")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Spacer()

                Button {
                    showingEditProfile = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.blueSoft)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.blueSoft, Theme.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if let avatarURL,
                       let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Text(profileInitials)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    } else {
                        Text(profileInitials)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .frame(width: 86, height: 86)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.ink.opacity(0.12), lineWidth: 1)
                )

                Text(displayName)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text(
                    [degreeLevel, intendedMajor, nationality]
                        .filter {
                            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        .joined(separator: " · ")
                )
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Label(
                        visible ? "Community visible" : "Community hidden",
                        systemImage: visible ? "eye.fill" : "eye.slash.fill"
                    )

                    Label(
                        "Private academic data",
                        systemImage: "lock.fill"
                    )
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.blueSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private var profileInitials: String {
        let words = fullName.split(separator: " ")

        if words.count >= 2 {
            return (
                String(words[0].prefix(1)) +
                String(words[1].prefix(1))
            ).uppercased()
        }

        return fullName.isEmpty
            ? "G"
            : String(fullName.prefix(2)).uppercased()
    }

    private var academicSnapshot: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Academic profile")
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)

                    Text("Used privately for scholarship matching")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Text("\(profileCompletion)%")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.blueSoft)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.ink.opacity(0.07))
                        .frame(height: 6)

                    Capsule()
                        .fill(Theme.blueGradient)
                        .frame(
                            width: geometry.size.width *
                                CGFloat(profileCompletion) / 100,
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                ProfileMetric(
                    value: gpaValue.isEmpty ? "—" : gpaValue,
                    label: "GPA"
                )

                ProfileMetric(
                    value: ielts.isEmpty ? "—" : ielts,
                    label: "IELTS"
                )

                ProfileMetric(
                    value: graduationYear.isEmpty ? "—" : graduationYear,
                    label: "Graduation"
                )
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Study goals")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Image(systemName: "airplane")
                    .foregroundStyle(Theme.blueSoft)
            }

            ProfileSummaryLine(
                icon: "graduationcap.fill",
                label: "Degree",
                value: degreeLevel
            )

            ProfileSummaryLine(
                icon: "books.vertical.fill",
                label: "Major",
                value: intendedMajor.isEmpty ? "Not set" : intendedMajor
            )

            ProfileSummaryLine(
                icon: "globe",
                label: "Countries",
                value: targetCountries.isEmpty ? "Not set" : targetCountries
            )
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var communityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Community profile")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.ink)

                Spacer()

                Circle()
                    .fill(visible ? Theme.green : Theme.ink.opacity(0.25))
                    .frame(width: 8, height: 8)
            }

            Text(
                bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Add a short bio so other students know your study interests."
                    : bio
            )
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .lineSpacing(3)

            Text("GPA, IELTS, income and residence details are never copied into your public community profile.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .tint(Theme.accent)
            .padding(.vertical, 12)
            .accessibilityHint("System follows your device. Light uses cream and brown; dark uses navy and blue.")

            Divider()

            Picker("Language", selection: $language) {
                ForEach(AppLanguage.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .tint(Theme.accent)
            .padding(.vertical, 12)

            Divider()

            NavigationLink {
                PrivacyAndSafetyView()
            } label: {
                ProfileMenuRow(
                    icon: "lock.shield.fill",
                    title: "Privacy & Safety",
                    subtitle: "Data, community and scholarship guidance",
                    tint: Theme.blueSoft
                )
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(Theme.ink.opacity(0.06))

            NavigationLink {
                BlockedUsersView()
            } label: {
                ProfileMenuRow(
                    icon: "person.crop.circle.badge.xmark",
                    title: "Blocked students",
                    subtitle: "Review and unblock community members",
                    tint: Theme.blueSoft
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var accountCard: some View {
        VStack(spacing: 10) {
            Button {
                Task { await auth.signOut() }
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.surface)
                    .foregroundStyle(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button(
                role: .destructive
            ) {
                showingDeleteAccount = true
            } label: {
                Label(
                    deletingAccount ? "Deleting account..." : "Delete account",
                    systemImage: "trash"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.danger)
            }
            .disabled(deletingAccount)
        }
    }

    private var editProfileSheet: some View {
        NavigationStack {
            Form {
                Section("Student profile") {
                    TextField("Full name", text: $fullName)
                    TextField("Nationality", text: $nationality)
                    TextField("Country of residence", text: $residenceCountry)

                    TextField("Graduation year", text: $graduationYear)
                        .keyboardType(.numberPad)

                    HStack {
                        TextField("GPA", text: $gpaValue)
                            .keyboardType(.decimalPad)

                        TextField("Scale", text: $gpaScale)
                            .keyboardType(.decimalPad)
                    }

                    TextField("IELTS", text: $ielts)
                        .keyboardType(.decimalPad)

                    TextField("Intended major", text: $intendedMajor)

                    Picker("Degree", selection: $degreeLevel) {
                        ForEach(["Bachelor", "Master", "PhD"], id: \.self) {
                            Text($0)
                        }
                    }
                }

                Section("Preferences") {
                    TextField(
                        "Target regions, comma separated",
                        text: $targetRegions
                    )

                    TextField(
                        "Target countries, comma separated",
                        text: $targetCountries
                    )

                    TextField(
                        "Family annual income, USD",
                        text: $familyIncome
                    )
                    .keyboardType(.decimalPad)
                }

                Section("Profile photo") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.surfaceRaised)

                            if let avatarURL,
                               let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    default:
                                        Text(profileInitials)
                                            .font(.headline.bold())
                                            .foregroundStyle(Theme.ink)
                                    }
                                }
                            } else {
                                Text(profileInitials)
                                    .font(.headline.bold())
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        .frame(width: 62, height: 62)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(
                                selection: $selectedPhoto,
                                matching: .images
                            ) {
                                Label(
                                    uploadingPhoto
                                        ? "Uploading…"
                                        : "Choose photo",
                                    systemImage: "photo.on.rectangle"
                                )
                            }
                            .disabled(uploadingPhoto)

                            Text("JPG, PNG or HEIC. Up to 5 MB.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: selectedPhoto) {
                    guard selectedPhoto != nil else { return }
                    Task { await uploadSelectedPhoto() }
                }

                Section("Community") {
                    TextField(
                        "Short bio",
                        text: $bio,
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    Toggle(
                        "Show my community profile",
                        isOn: $visible
                    )

                    Text("Your GPA, IELTS and family income remain private.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.pageBackground)
            .tint(Theme.blue)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEditProfile = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving..." : "Save") {
                        Task {
                            await save()

                            if status == L10n.string("Profile saved.") {
                                showingEditProfile = false
                            }
                        }
                    }
                    .disabled(
                        saving ||
                        fullName
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }
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

        if let community = try? await DataService.currentCommunityProfile(
            userId: userId
        ) {
            bio = community.bio ?? ""
            visible = community.isVisible ?? true
            avatarURL = community.avatarUrl
        }
    }

    @MainActor
    private func deleteAccount() async {
        deletingAccount = true
        defer { deletingAccount = false }

        if !(await auth.deleteAccount()) {
            status = auth.errorMessage ?? L10n.string("Your account could not be deleted.")
        }
    }

    @MainActor
    private func uploadSelectedPhoto() async {
        guard
            let selectedPhoto,
            let userId = auth.userId
        else {
            return
        }

        uploadingPhoto = true
        status = ""
        defer {
            uploadingPhoto = false
            self.selectedPhoto = nil
        }

        do {
            guard
                let rawData = try await selectedPhoto
                    .loadTransferable(type: Data.self),
                let image = UIImage(data: rawData),
                let jpegData = resizedJPEGData(
                    from: image,
                    maxDimension: 1200,
                    compressionQuality: 0.82
                )
            else {
                status = L10n.string("Could not read that photo.")
                return
            }

            guard jpegData.count <= 5 * 1024 * 1024 else {
                status = L10n.string("Please choose a smaller photo.")
                return
            }

            avatarURL = try await DataService.uploadProfileAvatar(
                userId: userId,
                imageData: jpegData
            )

            status = L10n.string("Profile photo updated.")
        } catch {
            status = error.localizedDescription
        }
    }

    private func resizedJPEGData(
        from image: UIImage,
        maxDimension: CGFloat,
        compressionQuality: CGFloat
    ) -> Data? {
        let size = image.size
        let longestSide = max(size.width, size.height)

        guard longestSide > 0 else {
            return nil
        }

        let scale = min(1, maxDimension / longestSide)
        let targetSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(
                in: CGRect(
                    origin: .zero,
                    size: targetSize
                )
            )
        }

        return resized.jpegData(
            compressionQuality: compressionQuality
        )
    }

    @MainActor
    private func save() async {
        guard let userId = auth.userId else { return }

        saving = true
        status = ""
        defer { saving = false }

        if let value = Double(ielts), !(0...9).contains(value) {
            status = L10n.string("IELTS must be between 0 and 9.")
            return
        }

        if let gpa = Double(gpaValue),
           let scale = Double(gpaScale),
           (scale <= 0 || gpa < 0 || gpa > scale) {
            status = L10n.string("Please check your GPA and GPA scale.")
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
            status = L10n.string("Profile saved.")
        } catch {
            status = error.localizedDescription
        }
    }
}

private struct ProfileMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

private struct ProfileSummaryLine: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Theme.blueSoft)
                .frame(width: 30, height: 30)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

private struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.ink.opacity(0.28))
        }
        .padding(.vertical, 12)
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
                                    .foregroundStyle(Theme.muted)
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
        .background(Theme.pageBackground)
        .navigationTitle("Blocked Students")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert(
            "Unable to update block",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
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
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) ==
                    .orderedAscending
                }
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
                    .foregroundStyle(Theme.muted)
            }

            Section("Account control") {
                Text("You can permanently delete your Grantly account from Profile. Deleting the authentication account also removes linked profile and user-owned app data according to the database relationships.")
                    .foregroundStyle(Theme.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle("Privacy & Safety")
        .navigationBarTitleDisplayMode(.inline)
    }
}


private struct AdvisorApplicationView: View {
    @Environment(\.dismiss) private var dismiss

    let defaultName: String

    @State private var displayName = ""
    @State private var title = ""
    @State private var bio = ""
    @State private var specialties = ""
    @State private var countries = ""
    @State private var languages = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Professional profile") {
                TextField("Full name", text: $displayName)
                TextField(
                    "Title, e.g. Admissions Counselor",
                    text: $title
                )

                TextField(
                    "Short professional bio",
                    text: $bio,
                    axis: .vertical
                )
                .lineLimit(3...6)
            }

            Section("Expertise") {
                TextField(
                    "Specialties, separated by commas",
                    text: $specialties
                )
                TextField(
                    "Countries or regions, separated by commas",
                    text: $countries
                )
                TextField(
                    "Languages, separated by commas",
                    text: $languages
                )
            }

            Section {
                Text(
                    "Advisor profiles are not visible to students until an administrator reviews and approves the application."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if submitted {
                Section {
                    Label(
                        "Application submitted for review",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)

                    Button("Done") {
                        dismiss()
                    }
                }
            } else {
                Section {
                    Button(
                        submitting
                            ? "Submitting…"
                            : "Submit advisor application"
                    ) {
                        Task { await submit() }
                    }
                    .disabled(
                        submitting ||
                        displayName
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
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
        .navigationTitle("Advisor Application")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if displayName.isEmpty {
                displayName = defaultName
            }
        }
    }

    @MainActor
    private func submit() async {
        submitting = true
        errorMessage = nil
        defer { submitting = false }

        do {
            try await DataService.requestAdvisorAccess(
                displayName: displayName
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                title: title
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                bio: bio
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                specialties: csvValues(specialties),
                countries: csvValues(countries),
                languages: csvValues(languages)
            )
            submitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func csvValues(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
    }
}
