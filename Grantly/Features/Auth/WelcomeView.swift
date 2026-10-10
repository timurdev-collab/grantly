import SwiftUI

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    private var isLightPage: Bool { page == 1 }
    private var foreground: Color {
        isLightPage ? Theme.premiumForest : Theme.premiumIvory
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                (isLightPage ? Theme.premiumIvory : Theme.premiumForest)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    TabView(selection: $page) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                            WelcomeEditorialPage(item: item, pageIndex: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    controls
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingLogin) {
            LoginView().preferredColorScheme(.light)
        }
        .sheet(isPresented: $showingSignup) {
            SignupView().preferredColorScheme(.light)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(foreground.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)

            Text(verbatim: "EduT")
                .font(.system(size: 23, weight: .semibold, design: .serif))

            Spacer()

            if page < pages.count - 1 {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                        page = pages.count - 1
                    }
                } label: {
                    Text(L10n.string("Skip"))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(foreground)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(foreground.opacity(index == page ? 1 : 0.30))
                        .frame(width: index == page ? 24 : 6, height: 6)
                }
            }
            .padding(.bottom, 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Page \(page + 1) of \(pages.count)"))

            Button {
                if page < pages.count - 1 {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                        page += 1
                    }
                } else {
                    showingSignup = true
                }
            } label: {
                HStack(spacing: 10) {
                    Text(L10n.string(page < pages.count - 1 ? "Continue" : "Get started"))
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(isLightPage ? Theme.premiumIvory : Theme.premiumForest)
                .background(foreground, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(CardPressButtonStyle())
            .accessibilityIdentifier("onboarding.primary")

            Button {
                showingLogin = true
            } label: {
                Text(L10n.string("I already have an account"))
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(foreground.opacity(0.85))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding.signIn")
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
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 36
    let item: WelcomePage
    let pageIndex: Int

    private var isLightPage: Bool { pageIndex == 1 }
    private var foreground: Color {
        isLightPage ? Theme.premiumForest : Theme.premiumIvory
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if pageIndex == 0 {
                        landscape(height: max(160, geometry.size.height * 0.47))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string(item.eyebrow))
                            .font(.caption2.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(foreground.opacity(0.65))

                        Text(L10n.string(item.title))
                            .font(.system(size: titleSize, weight: .regular, design: .serif))
                            .tracking(-0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text(L10n.string(item.body))
                            .font(.subheadline)
                            .lineSpacing(4)
                            .foregroundStyle(foreground.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if pageIndex == 1 {
                        discoveryIllustration
                    } else if pageIndex == 2 {
                        guidanceServices
                    }
                }
                .foregroundStyle(foreground)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func landscape(height: CGFloat) -> some View {
        GeometryReader { geometry in
            AsyncImage(url: item.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Theme.premiumSage, Theme.premiumForestSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 70, weight: .thin))
                            .foregroundStyle(Theme.premiumIvory.opacity(0.6))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Theme.premiumIvory.opacity(0.12), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var discoveryIllustration: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.premiumSageSoft)
                    .frame(width: 180, height: 180)
                Circle()
                    .strokeBorder(Theme.premiumForest.opacity(0.12), lineWidth: 1)
                    .frame(width: 210, height: 210)
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 130, weight: .ultraLight))
                    .foregroundStyle(Theme.premiumForestSoft)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.premiumBrass, Theme.premiumIvory)
                    .offset(x: 60, y: -50)
            }
            .accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { discoveryLabels }
                VStack(spacing: 8) { discoveryLabels }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var discoveryLabels: some View {
        discoveryPill("Scholarships", icon: "graduationcap")
        discoveryPill("Universities", icon: "building.columns")
        discoveryPill("Programs", icon: "books.vertical")
    }

    private func discoveryPill(_ title: String, icon: String) -> some View {
        Label(L10n.string(title), systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.premiumSageSoft, in: Capsule())
    }

    private var guidanceServices: some View {
        VStack(spacing: 0) {
            guidanceRow("Application guidance", icon: "doc.text.magnifyingglass")
            Divider().overlay(Theme.premiumIvory.opacity(0.12))
            guidanceRow("Document review", icon: "doc.text")
            Divider().overlay(Theme.premiumIvory.opacity(0.12))
            guidanceRow("Interview preparation", icon: "bubble.left.and.bubble.right")
        }
        .padding(.horizontal, 18)
        .background(Theme.premiumIvory.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Theme.premiumIvory.opacity(0.10), lineWidth: 1)
        }
    }

    private func guidanceRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .frame(width: 42, height: 42)
                .background(Theme.premiumIvory.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            Text(L10n.string(title))
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
    }
}

struct PremiumPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .frame(minHeight: 54)
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
            .padding(.vertical, 12)
            .frame(minHeight: 48)
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
