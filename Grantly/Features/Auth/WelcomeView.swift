import SwiftUI

struct WelcomeView: View {
    @State private var showingLogin = false
    @State private var showingSignup = false
    @State private var page = 0

    private let pages: [WelcomePage] = [
        WelcomePage(
            eyebrow: "DISCOVER",
            title: "Your next chapter\nstarts here",
            body: "Find scholarships and universities that fit your ambitions, not just your search terms.",
            imageURL: URL(
                string:
                    "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=88"
            ),
            symbol: "sparkles"
        ),
        WelcomePage(
            eyebrow: "PERSONALIZED",
            title: "Find opportunities\nthat fit you",
            body: "Use your goals, study level and background to surface stronger scholarship matches.",
            imageURL: URL(
                string:
                    "https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=1200&q=88"
            ),
            symbol: "scope"
        ),
        WelcomePage(
            eyebrow: "GUIDANCE",
            title: "Get guidance\nfrom experts",
            body: "Work with verified advisors for applications, essays, documents and your next decision.",
            imageURL: URL(
                string:
                    "https://images.unsplash.com/photo-1551836022-d5d88e9218df?auto=format&fit=crop&w=1200&q=88"
            ),
            symbol: "person.2.fill"
        )
    ]

    var body: some View {
        ZStack {
            Theme.premiumIvory
                .ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) {
                    index,
                    item in
                    WelcomeEditorialPage(
                        item: item,
                        pageIndex: index
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Theme.premiumForest)

                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.premiumIvory)
                        }
                        .frame(width: 32, height: 32)

                        Text(verbatim: "EduT")
                            .font(
                                .system(
                                    size: 20,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(Theme.premiumForest)
                    }

                    Spacer()

                    if page < pages.count - 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                page = pages.count - 1
                            }
                        } label: {
                            Text(L10n.string("Skip"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    page == 2
                                        ? Theme.premiumIvory
                                        : Theme.premiumForest
                                )
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index == page
                                        ? Theme.premiumForest
                                        : Theme.premiumMuted.opacity(0.26)
                                )
                                .frame(
                                    width: index == page ? 22 : 6,
                                    height: 6
                                )
                                .animation(
                                    .easeInOut(duration: 0.22),
                                    value: page
                                )
                        }
                    }

                    if page < pages.count - 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                page += 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(L10n.string("Continue"))
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(PremiumPrimaryButtonStyle())
                    } else {
                        Button {
                            showingSignup = true
                        } label: {
                            HStack(spacing: 8) {
                                Text(L10n.string("Get started"))
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(PremiumPrimaryButtonStyle())

                        Button {
                            showingLogin = true
                        } label: {
                            Text(L10n.string("I already have an account"))
                        }
                        .buttonStyle(PremiumSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showingSignup) {
            SignupView()
                .preferredColorScheme(.light)
        }
    }
}

private struct WelcomePage {
    let eyebrow: String
    let title: String
    let body: String
    let imageURL: URL?
    let symbol: String
}

private struct WelcomeEditorialPage: View {
    let item: WelcomePage
    let pageIndex: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AsyncImage(url: item.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        LinearGradient(
                            colors: [
                                Theme.premiumSage,
                                Theme.premiumForestSoft
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Image(systemName: item.symbol)
                                .font(.system(size: 100, weight: .thin))
                                .foregroundStyle(
                                    Theme.premiumIvory.opacity(0.44)
                                )
                        }
                    }
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .clipped()

                LinearGradient(
                    colors: [
                        Theme.premiumIvory.opacity(0.10),
                        Color.clear,
                        Theme.premiumForest.opacity(0.35),
                        Theme.premiumForest.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if pageIndex == 1 {
                    Circle()
                        .stroke(
                            Theme.premiumIvory.opacity(0.55),
                            lineWidth: 1
                        )
                        .frame(width: 230, height: 230)
                        .offset(x: 100, y: 40)

                    Circle()
                        .fill(Theme.premiumBrass.opacity(0.26))
                        .frame(width: 72, height: 72)
                        .offset(x: 125, y: 15)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Spacer()

                    Text(L10n.string(item.eyebrow))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.7)
                        .foregroundStyle(
                            Theme.premiumIvory.opacity(0.78)
                        )

                    Text(L10n.string(item.title))
                        .font(
                            .system(
                                size: 39,
                                weight: .regular,
                                design: .serif
                            )
                        )
                        .tracking(-1.0)
                        .lineSpacing(-2)
                        .foregroundStyle(Theme.premiumIvory)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.string(item.body))
                        .font(.subheadline)
                        .lineSpacing(3)
                        .foregroundStyle(
                            Theme.premiumIvory.opacity(0.78)
                        )
                        .frame(maxWidth: 330, alignment: .leading)

                    Spacer()
                        .frame(height: pageIndex == 2 ? 174 : 116)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct PremiumPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Theme.premiumIvory.opacity(
                    configuration.isPressed ? 0.84 : 1
                )
            )
            .foregroundStyle(Theme.premiumForest)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 19,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(0.12),
                radius: 18,
                x: 0,
                y: 8
            )
    }
}

struct PremiumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.ultraThinMaterial)
            .foregroundStyle(Theme.premiumIvory)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.36),
                    lineWidth: 1
                )
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

// Kept as aliases for older screens that still use the shared button styles.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .buttonStyle(PremiumPrimaryButtonStyle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .buttonStyle(PremiumSecondaryButtonStyle())
    }
}
