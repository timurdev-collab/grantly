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

    var body: some View {
        Form {
            Section("Student profile") {
                TextField("Full name", text: $fullName)
                TextField("Nationality", text: $nationality)
                TextField("Country of residence", text: $residenceCountry)
                TextField("Graduation year", text: $graduationYear).keyboardType(.numberPad)
                TextField("GPA", text: $gpaValue).keyboardType(.decimalPad)
                TextField("GPA scale", text: $gpaScale).keyboardType(.decimalPad)
                TextField("IELTS", text: $ielts).keyboardType(.decimalPad)
                TextField("Intended major", text: $intendedMajor)
                Picker("Degree", selection: $degreeLevel) {
                    ForEach(["Bachelor","Master","PhD"], id: \.self) { Text($0) }
                }
            }

            Section("Preferences") {
                TextField("Target regions, comma separated", text: $targetRegions)
                TextField("Target countries, comma separated", text: $targetCountries)
                TextField("Family annual income, USD", text: $familyIncome).keyboardType(.decimalPad)
            }

            Section("Community") {
                TextField("Short bio", text: $bio, axis: .vertical).lineLimit(3...6)
                Toggle("Show my community profile", isOn: $visible)
                Text("Your GPA, IELTS and family income are not stored in the public community profile.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !status.isEmpty { Section { Text(status).font(.caption) } }

            Section {
                Button("Save profile") { Task { await save() } }
                Button("Sign out", role: .destructive) { Task { await auth.signOut() } }
            }

            if profile?.role == "admin" {
                Section("Administration") {
                    NavigationLink("Open admin dashboard") { AdminView() }
                }
            }
        }
        .navigationTitle("Profile")
        .task { populate() }
    }

    private func csv(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func populate() {
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
    }

    @MainActor
    private func save() async {
        guard let userId = auth.userId else { return }
        do {
            try await DataService.updateProfile(
                userId: userId,
                fullName: fullName,
                nationality: nationality,
                residenceCountry: residenceCountry,
                graduationYear: Int(graduationYear),
                gpaValue: Double(gpaValue),
                gpaScale: Double(gpaScale),
                ielts: Double(ielts),
                intendedMajor: intendedMajor,
                degreeLevel: degreeLevel,
                targetRegions: csv(targetRegions),
                targetCountries: csv(targetCountries),
                familyIncomeUSD: Double(familyIncome)
            )
            try await DataService.updateCommunityProfile(
                userId: userId,
                displayName: fullName,
                nationality: nationality,
                major: intendedMajor,
                targetRegions: csv(targetRegions),
                targetCountries: csv(targetCountries),
                bio: bio,
                isVisible: visible
            )
            profile = try await DataService.currentProfile(userId: userId)
            status = "Profile saved."
        } catch {
            status = error.localizedDescription
        }
    }
}
