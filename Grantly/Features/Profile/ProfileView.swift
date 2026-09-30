import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Binding var profile: StudentProfile?
    var showsNavigationBar = false
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
    @State private var selectedProfileSection = 0
    @State private var showingSettings = false

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
            VStack(spacing: 0) {
                instagramProfileHeader
                profileSectionTabs

                VStack(spacing: 16) {
                    if selectedProfileSection == 0 {
                        communityCard
                    } else {
                        academicSnapshot
                        destinationCard
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.pageBackground)
        .navigationTitle(showsNavigationBar ? "Profile" : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(!showsNavigationBar)
        .task { await populate() }
        .sheet(isPresented: $showingEditProfile) {
            editProfileSheet
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
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

    private var instagramProfileHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            HStack(alignment: .center, spacing: 20) {
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
                .frame(width: 92, height: 92)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.ink.opacity(0.12), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)

                    Text(
                        [degreeLevel, intendedMajor, nationality]
                            .filter {
                                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            }
                            .joined(separator: " · ")
                    )
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)

                    Label(
                        visible ? "Community visible" : "Community hidden",
                        systemImage: visible ? "eye.fill" : "eye.slash.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.blueSoft)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedBio.isEmpty {
                Text(trimmedBio)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            Button {
                showingEditProfile = true
            } label: {
                Text("Edit")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Academic profile")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)

                        Spacer()

                        Text("\(profileCompletion)%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.ink)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.ink.opacity(0.08))

                            Capsule()
                                .fill(Theme.blueSoft)
                                .frame(
                                    width: geometry.size.width *
                                        CGFloat(profileCompletion) / 100
                                )
                        }
                    }
                    .frame(height: 5)
                }

                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .accessibilityLabel("Private academic data")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background(Theme.surface)
    }

    private var profileSectionTabs: some View {
        HStack(spacing: 0) {
            profileSectionButton(
                index: 0,
                systemImage: "person.crop.circle",
                accessibilityLabel: "Community profile"
            )
            profileSectionButton(
                index: 1,
                systemImage: "graduationcap",
                accessibilityLabel: "Academic profile"
            )
        }
        .frame(height: 48)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.ink.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func profileSectionButton(
        index: Int,
        systemImage: String,
        accessibilityLabel: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedProfileSection = index
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        selectedProfileSection == index
                            ? Theme.ink
                            : Theme.muted
                    )

                Rectangle()
                    .fill(
                        selectedProfileSection == index
                            ? Theme.ink
                            : Color.clear
                    )
                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(
            selectedProfileSection == index ? .isSelected : []
        )
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

                Label(
                    visible ? "Community visible" : "Community hidden",
                    systemImage: visible ? "eye.fill" : "eye.slash.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.blueSoft)
            }

            Text(
                bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? L10n.string("Add a short bio so other students know your study interests.")
                    : bio
            )
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
            .lineSpacing(3)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.muted)

                Text("GPA, IELTS, income and residence details are never copied into your public community profile.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Theme.ink.opacity(0.05))
        )
    }

    private var settingsSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    settingsCard

                    NavigationLink {
                        MyContentView()
                    } label: {
                        ProfileMenuRow(
                            icon: "rectangle.stack.badge.person.crop",
                            title: L10n.string("My content"),
                            subtitle: L10n.string("Edit or delete your posts, stories and shorts"),
                            tint: Theme.orangeSoft
                        )
                    }
                    .buttonStyle(.plain)

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

                    accountCard
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.pageBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
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

    @State private var step = 0
    @State private var existingApplication: AdvisorApplicationProfile?
    @State private var loadingApplication = true

    @State private var displayName = ""
    @State private var title = ""
    @State private var organization = ""
    @State private var yearsExperience = ""
    @State private var shortBio = ""
    @State private var bio = ""
    @State private var mentoringApproach = ""
    @State private var specialties = ""
    @State private var countries = ""
    @State private var languages = ""
    @State private var introVideoURL = ""
    @State private var linkedinURL = ""
    @State private var websiteURL = ""

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoImage: UIImage?

    @State private var submitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    private var stepTitles: [String] {
        [
            L10n.string("Professional profile"),
            L10n.string("How you can help"),
            L10n.string("Introduction & review")
        ]
    }

    private var normalizedVideoURL: URL? {
        guard
            let url = URL(
                string: introVideoURL
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            url.scheme?.lowercased() == "https",
            url.host != nil
        else {
            return nil
        }

        return url
    }

    var body: some View {
        Form {
            if loadingApplication {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                if let existingApplication {
                    applicationStatusSection(existingApplication)
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(
                                L10n.format(
                                    "Step %d of 3",
                                    step + 1
                                )
                            )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accentSoft)

                            Spacer()

                            Text(stepTitles[step])
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Theme.ink.opacity(0.07))

                                Capsule()
                                    .fill(Theme.accent)
                                    .frame(
                                        width:
                                            geometry.size.width *
                                            CGFloat(step + 1) / 3
                                    )
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.vertical, 4)
                }

                if step == 0 {
                    basicProfileStep
                } else if step == 1 {
                    expertiseStep
                } else {
                    introAndReviewStep
                }

                if let errorMessage {
                    Section {
                        Label(
                            errorMessage,
                            systemImage: "exclamationmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        if step > 0 {
                            Button("Back") {
                                errorMessage = nil
                                step -= 1
                            }
                            .buttonStyle(.bordered)
                        }

                        Button {
                            if step < 2 {
                                continueToNextStep()
                            } else {
                                Task { await submit() }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text(
                                    step < 2
                                        ? L10n.string("Continue")
                                        : submitting
                                            ? L10n.string("Submitting…")
                                            : L10n.string("Submit for review")
                                )
                                .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(submitting)
                    }
                }

                Section {
                    Label(
                        "Your profile stays private until a Grantly admin approves it.",
                        systemImage: "lock.shield.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                }
            }
        }
        .navigationTitle("Advisor Application")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadExistingApplication() }
        .onChange(of: selectedPhoto) {
            Task { await loadSelectedPhoto() }
        }
        .alert(
            "Application submitted",
            isPresented: $submitted
        ) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text(
                "Your profile is now in the admin review queue. It will not appear to students until it is approved."
            )
        }
    }

    @ViewBuilder
    private func applicationStatusSection(
        _ application: AdvisorApplicationProfile
    ) -> some View {
        Section("Application status") {
            HStack(spacing: 10) {
                Image(systemName: statusIcon(application.approvalStatus))
                    .foregroundStyle(
                        statusColor(application.approvalStatus)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        localizedAdvisorStatus(
                            application.approvalStatus
                        )
                    )
                    .font(.subheadline.weight(.semibold))

                    Text(
                        L10n.format(
                            "Application version %@",
                            String(application.applicationVersion)
                        )
                    )
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }

            if let note = application.reviewNote,
               !note.trimmingCharacters(
                    in: .whitespacesAndNewlines
               ).isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Admin feedback")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)

                    Text(note)
                        .font(.subheadline)
                }
            }

            if application.approvalStatus == "pending" {
                Text(
                    "You can still update and resubmit while the application is waiting for review."
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }
        }
    }

    private var basicProfileStep: some View {
        Group {
            Section("Profile photo") {
                HStack(spacing: 14) {
                    advisorPhotoPreview

                    VStack(alignment: .leading, spacing: 6) {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images
                        ) {
                            Label(
                                selectedPhotoData == nil
                                    ? L10n.string("Choose photo")
                                    : L10n.string("Change photo"),
                                systemImage: "photo"
                            )
                        }

                        Text(
                            "Use a clear professional headshot. Students will see this in the advisor grid."
                        )
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    }
                }
            }

            Section("Professional details") {
                TextField("Full name", text: $displayName)
                    .textContentType(.name)

                TextField(
                    "Professional title",
                    text: $title,
                    prompt: Text("Admissions Advisor")
                )

                TextField(
                    "Organization (optional)",
                    text: $organization
                )

                TextField(
                    "Years of relevant experience",
                    text: $yearsExperience
                )
                .keyboardType(.numberPad)
            }
        }
    }

    private var expertiseStep: some View {
        Group {
            Section("Your introduction") {
                TextField(
                    "One-line summary",
                    text: $shortBio,
                    axis: .vertical
                )
                .lineLimit(2...3)

                TextField(
                    "Professional background and experience",
                    text: $bio,
                    axis: .vertical
                )
                .lineLimit(5...10)

                TextField(
                    "How will you help students?",
                    text: $mentoringApproach,
                    axis: .vertical
                )
                .lineLimit(4...8)
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

                Text(
                    "Be specific. For example: US admissions, scholarship essays, graduate applications."
                )
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            }
        }
    }

    private var introAndReviewStep: some View {
        Group {
            Section("Introduction video") {
                TextField(
                    "https://youtube.com/…",
                    text: $introVideoURL
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()

                Text(
                    "Add a short introduction video from YouTube, Loom, Vimeo or another secure HTTPS link. Around 60–90 seconds works best."
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)

                if normalizedVideoURL != nil {
                    Label(
                        "Video link looks valid",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.green)
                }
            }

            Section("Professional links") {
                TextField("LinkedIn URL (optional)", text: $linkedinURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("Website URL (optional)", text: $websiteURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }

            Section("Review") {
                advisorReviewRow("Name", displayName)
                advisorReviewRow("Title", title)
                advisorReviewRow(
                    "Experience",
                    yearsExperience.isEmpty
                        ? L10n.string("Not specified")
                        : L10n.format(
                            "%@ years",
                            yearsExperience
                        )
                )
                advisorReviewRow(
                    "Specialties",
                    csvValues(specialties).joined(separator: " · ")
                )
                advisorReviewRow(
                    "Countries",
                    csvValues(countries).joined(separator: " · ")
                )
                advisorReviewRow(
                    "Languages",
                    csvValues(languages).joined(separator: " · ")
                )
            }
        }
    }

    @ViewBuilder
    private var advisorPhotoPreview: some View {
        ZStack {
            Circle()
                .fill(Theme.surfaceRaised)

            if let image = selectedPhotoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let value = existingApplication?.avatarUrl,
                      let url = URL(string: value) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "person.fill")
                            .foregroundStyle(Theme.muted)
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
        )
    }

    private func advisorReviewRow(
        _ label: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.string(label))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)

            Text(
                value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
                    ? L10n.string("Not provided")
                    : value
            )
            .font(.subheadline)
        }
    }

    private func continueToNextStep() {
        errorMessage = validationMessage(for: step)

        guard errorMessage == nil else { return }
        step += 1
    }

    private func validationMessage(
        for step: Int
    ) -> String? {
        if step == 0 {
            if displayName.trimmed.isEmpty {
                return L10n.string("Please enter your full name.")
            }

            if title.trimmed.isEmpty {
                return L10n.string("Please enter your professional title.")
            }

            if selectedPhotoData == nil &&
                existingApplication?.avatarStoragePath == nil &&
                existingApplication?.avatarUrl == nil {
                return L10n.string("Please add a professional profile photo.")
            }

            if let years = Int(yearsExperience),
               !(0...80).contains(years) {
                return L10n.string("Please check your years of experience.")
            }

            return nil
        }

        if step == 1 {
            if bio.trimmed.count < 80 {
                return L10n.string("Please add a little more detail to your professional background.")
            }

            if csvValues(specialties).isEmpty {
                return L10n.string("Please add at least one specialty.")
            }

            if csvValues(languages).isEmpty {
                return L10n.string("Please add at least one language.")
            }

            return nil
        }

        if normalizedVideoURL == nil {
            return L10n.string("Please add a valid HTTPS introduction video link.")
        }

        if !linkedinURL.trimmed.isEmpty &&
            !isValidHTTPSURL(linkedinURL) {
            return L10n.string("Please check your LinkedIn URL.")
        }

        if !websiteURL.trimmed.isEmpty &&
            !isValidHTTPSURL(websiteURL) {
            return L10n.string("Please check your website URL.")
        }

        return nil
    }

    @MainActor
    private func loadExistingApplication() async {
        loadingApplication = true
        defer { loadingApplication = false }

        do {
            if let application =
                try await DataService.myAdvisorApplication() {
                existingApplication = application
                populate(from: application)
            } else if displayName.isEmpty {
                displayName = defaultName
            }
        } catch {
            displayName = displayName.isEmpty
                ? defaultName
                : displayName
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }

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
                errorMessage = L10n.string("Could not read that photo.")
                return
            }

            guard jpegData.count <= 5 * 1024 * 1024 else {
                errorMessage = L10n.string("Please choose a smaller photo.")
                return
            }

            selectedPhotoData = jpegData
            selectedPhotoImage = UIImage(data: jpegData)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func submit() async {
        if let message = validationMessage(for: 0) ??
            validationMessage(for: 1) ??
            validationMessage(for: 2) {
            errorMessage = message
            return
        }

        submitting = true
        errorMessage = nil
        defer { submitting = false }

        do {
            let userId = try await supabase.auth.session.user.id
            var avatarPath = existingApplication?.avatarStoragePath

            if let selectedPhotoData {
                avatarPath = try await DataService.uploadAdvisorAvatar(
                    userId: userId,
                    imageData: selectedPhotoData
                )
            }

            let result = try await DataService.submitAdvisorApplication(
                displayName: displayName.trimmed,
                title: title.trimmed,
                organization: organization.trimmed,
                shortBio: shortBio.trimmed,
                bio: bio.trimmed,
                mentoringApproach: mentoringApproach.trimmed,
                yearsExperience: Int(yearsExperience),
                specialties: csvValues(specialties),
                countries: csvValues(countries),
                languages: csvValues(languages),
                linkedinURL: linkedinURL.trimmed,
                websiteURL: websiteURL.trimmed,
                avatarStoragePath: avatarPath,
                introVideoURL: introVideoURL.trimmed
            )

            existingApplication = result
            submitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func populate(
        from application: AdvisorApplicationProfile
    ) {
        displayName = application.displayName ?? defaultName
        title = application.title ?? ""
        organization = application.organization ?? ""
        yearsExperience = application.yearsExperience
            .map(String.init) ?? ""
        shortBio = application.shortBio ?? ""
        bio = application.bio ?? ""
        mentoringApproach = application.mentoringApproach ?? ""
        specialties = application.specialties.joined(separator: ", ")
        countries = application.countries.joined(separator: ", ")
        languages = application.languages.joined(separator: ", ")
        introVideoURL = application.introVideoUrl ?? ""
        linkedinURL = application.linkedinUrl ?? ""
        websiteURL = application.websiteUrl ?? ""
    }

    private func csvValues(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }

    private func isValidHTTPSURL(
        _ value: String
    ) -> Bool {
        guard
            let url = URL(string: value.trimmed),
            url.scheme?.lowercased() == "https",
            url.host != nil
        else {
            return false
        }

        return true
    }

    private func resizedJPEGData(
        from image: UIImage,
        maxDimension: CGFloat,
        compressionQuality: CGFloat
    ) -> Data? {
        let size = image.size
        let longestSide = max(size.width, size.height)

        guard longestSide > 0 else { return nil }

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

    private func localizedAdvisorStatus(
        _ status: String
    ) -> String {
        switch status {
        case "changes_requested":
            return L10n.string("Changes Requested")
        case "approved":
            return L10n.string("Approved")
        case "rejected":
            return L10n.string("Rejected")
        case "suspended":
            return L10n.string("Suspended")
        default:
            return L10n.string("Pending")
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "approved":
            return "checkmark.seal.fill"
        case "changes_requested":
            return "pencil.circle.fill"
        case "rejected":
            return "xmark.circle.fill"
        case "suspended":
            return "pause.circle.fill"
        default:
            return "clock.fill"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved":
            return Theme.green
        case "changes_requested":
            return Theme.sand
        case "rejected", "suspended":
            return Theme.danger
        default:
            return Theme.accentSoft
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
