import SwiftUI

struct WelcomeView: View {
    @State private var showingLogin = false
    @State private var showingSignup = false

    var body: some View {
        ZStack {
            Theme.navyDeep.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.orange.opacity(0.14), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 42)

                    GrantlyMonogram(size: 72)

                    Text("Grantly")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 16)

                    Text("Global opportunities\nfor brighter futures")
                        .font(.system(size: 25, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.top, 32)

                    Text("Discover scholarships, connect with a global community and take the next step in your journey.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.67))
                        .lineSpacing(4)
                        .padding(.horizontal, 28)
                        .padding(.top, 14)

                    ZStack(alignment: .bottom) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Theme.sky.opacity(0.42), Theme.navyDeep],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 270, height: 270)

                        Circle()
                            .trim(from: 0.03, to: 0.46)
                            .stroke(
                                Theme.orangeGradient,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(8))
                            .frame(width: 250, height: 250)
                            .shadow(color: Theme.orange.opacity(0.65), radius: 12)
                    }
                    .frame(height: 235)
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        Button("Get started") {
                            showingSignup = true
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("I already have an account") {
                            showingLogin = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                    Spacer(minLength: 24)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingSignup) {
            SignupView()
                .preferredColorScheme(.dark)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Theme.orangeGradient
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.surface.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.orange.opacity(0.75), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
