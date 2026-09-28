import SwiftUI

struct WelcomeView: View {
    @State private var showingLogin = false
    @State private var showingSignup = false

    private let earthURL = URL(string:
        "https://images.unsplash.com/photo-1614730321146-b6fa6a46bcb4?auto=format&fit=crop&w=1200&q=88"
    )

    var body: some View {
        ZStack {
            Theme.navyDeep.ignoresSafeArea()

            LinearGradient(
                colors: [Theme.navyDeep, Theme.navy, Theme.navyDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 34)

                    GrantlyMonogram(size: 64)

                    Text("Grantly")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 14)

                    Text("Global opportunities for\nbrighter futures")
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 30)

                    Text("Discover scholarships, connect with a global community and take the next step in your journey.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 34)
                        .padding(.top, 12)

                    ZStack(alignment: .bottom) {
                        AsyncImage(url: earthURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                ZStack {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [Theme.blue.opacity(0.48), Theme.navyDeep],
                                                center: .center,
                                                startRadius: 18,
                                                endRadius: 150
                                            )
                                        )
                                    Image(systemName: "globe.americas.fill")
                                        .font(.system(size: 112))
                                        .foregroundStyle(Theme.blue.opacity(0.36))
                                }
                            default:
                                ProgressView().tint(Theme.blue)
                            }
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 26))

                        LinearGradient(
                            colors: [.clear, Theme.navyDeep.opacity(0.86)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .frame(height: 110)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 22)

                    HStack(spacing: 6) {
                        Circle().fill(Theme.blue).frame(width: 7, height: 7)
                        Circle().fill(Theme.ink.opacity(0.30)).frame(width: 6, height: 6)
                        Circle().fill(Theme.ink.opacity(0.30)).frame(width: 6, height: 6)
                    }
                    .padding(.top, 10)

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

        .sheet(isPresented: $showingLogin) {
            LoginView()

        }
        .sheet(isPresented: $showingSignup) {
            SignupView()

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
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.blueGradient)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .foregroundStyle(Theme.onAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.navyDeep.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(Theme.ink)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.blue.opacity(0.75), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
