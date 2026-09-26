import SwiftUI

struct WelcomeView: View {
    @State private var showingLogin = false
    @State private var showingSignup = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, Theme.violet.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 10) {
                        Text("G")
                            .font(.headline.bold())
                            .frame(width: 38, height: 38)
                            .background(Theme.violet)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("Grantly").font(.title3.bold())
                    }

                    Spacer(minLength: 40)

                    Text("SCHOLARSHIPS WITHOUT BORDERS")
                        .font(.caption2.bold())
                        .tracking(1.5)
                        .foregroundStyle(Theme.violet)

                    Text("Find funding.\nBuild your future.")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .tracking(-1.5)

                    Text("Discover global scholarships, get profile-based eligibility matches and connect with students applying on the same path.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)

                    VStack(spacing: 12) {
                        Button("Create free account") { showingSignup = true }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Sign in") { showingLogin = true }
                            .buttonStyle(SecondaryButtonStyle())
                    }

                    HStack(spacing: 16) {
                        Label("Official links", systemImage: "checkmark.shield")
                        Label("Smart matching", systemImage: "sparkles")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer(minLength: 30)
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showingLogin) { LoginView() }
        .sheet(isPresented: $showingSignup) { SignupView() }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.violet.opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(.white)
            .foregroundStyle(Theme.ink)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
