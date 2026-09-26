import SwiftUI

struct WelcomeView: View {
    @State private var showingLogin = false
    @State private var showingSignup = false

    var body: some View {
        ZStack {
            Theme.ivory.ignoresSafeArea()

            Circle()
                .fill(Theme.brass.opacity(0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 2)
                .offset(x: 180, y: -330)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        GrantlyMonogram(size: 46)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("GRANTLY")
                                .font(.caption.weight(.bold))
                                .tracking(2.4)
                                .foregroundStyle(Theme.navy)

                            Text("Scholarship intelligence")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.bottom, 54)

                    SectionEyebrow(text: "Your education, funded")

                    Text("A clearer path\nto the world's\nbest opportunities.")
                        .font(Theme.serifTitle(47, weight: .medium))
                        .tracking(-1.3)
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 18)

                    Text("Discover scholarships with source quality, match them to your academic profile and organize every application in one place.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                        .padding(.top, 22)
                        .padding(.trailing, 14)

                    HStack(spacing: 0) {
                        WelcomeMetric(value: "500+", label: "opportunities")
                        Divider().frame(height: 42)
                        WelcomeMetric(value: "60+", label: "destinations")
                        Divider().frame(height: 42)
                        WelcomeMetric(value: "1", label: "application hub")
                    }
                    .padding(.vertical, 22)
                    .padding(.horizontal, 14)
                    .background(.white.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Theme.brass.opacity(0.20))
                    )
                    .padding(.top, 28)

                    VStack(spacing: 12) {
                        Button("Begin your search") {
                            showingSignup = true
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("I already have an account") {
                            showingLogin = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.top, 28)

                    HStack(spacing: 18) {
                        Label("Official sources", systemImage: "checkmark.seal")
                        Label("Private profile", systemImage: "lock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 18)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 30)
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

private struct WelcomeMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.serifTitle(21, weight: .semibold))
                .foregroundStyle(Theme.navy)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                configuration.isPressed
                    ? Theme.navy.opacity(0.88)
                    : Theme.navy
            )
            .foregroundStyle(Theme.parchment)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .trailing) {
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.brass)
                    .padding(.trailing, 17)
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                configuration.isPressed
                    ? Theme.parchment.opacity(0.7)
                    : .white
            )
            .foregroundStyle(Theme.navy)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.navy.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
