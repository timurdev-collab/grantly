import SwiftUI

struct SignupView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 36
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var created = false

    private var normalizedEmail: String {
        AuthValidation.normalizedEmail(email)
    }

    private var emailIsValid: Bool {
        AuthValidation.isValidEmail(email)
    }

    private var passwordIssue: String? {
        AuthValidation.passwordIssue(password)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.premiumIvory
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        if created {
                            createdState
                        } else {
                            createAccountForm
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 34)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .preferredColorScheme(.light)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.premiumForest)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("Close"))
                }
            }
        }
    }

    private var createAccountForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.string("Create your account"))
                    .font(
                        .system(
                            size: titleSize,
                            weight: .regular,
                            design: .serif
                        )
                    )
                    .tracking(-0.9)
                    .foregroundStyle(Theme.premiumInk)

                Text(
                    L10n.string(
                        "Start building a scholarship shortlist around your goals."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(Theme.premiumMuted)
                .lineSpacing(3)
            }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .foregroundStyle(Theme.premiumMuted)

                    TextField(
                        L10n.string("Email"),
                        text: $email
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                }
                .premiumSignupField()

                HStack(spacing: 10) {
                    Image(systemName: "lock")
                        .foregroundStyle(Theme.premiumMuted)

                    SecureField(
                        L10n.string(
                            "Password — at least 8 characters"
                        ),
                        text: $password
                    )
                    .textContentType(.newPassword)
                }
                .premiumSignupField()

                if !email.isEmpty && !emailIsValid {
                    Text(
                        L10n.string(
                            "Enter a valid email address."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.premiumBlush)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !password.isEmpty,
                   let passwordIssue {
                    Text(passwordIssue)
                        .font(.caption)
                        .foregroundStyle(Theme.premiumBlush)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.premiumBlush.opacity(0.08))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
            }

            Button {
                Task {
                    busy = true
                    created = await auth.signUp(
                        email: normalizedEmail,
                        password: password
                    )
                    busy = false
                }
            } label: {
                HStack(spacing: 8) {
                    if busy {
                        ProgressView()
                            .tint(Theme.premiumIvory)
                    }

                    Text(
                        busy
                            ? L10n.string("Creating…")
                            : L10n.string("Create account")
                    )

                    if !busy {
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.premiumForest)
                .foregroundStyle(Theme.premiumIvory)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !emailIsValid ||
                passwordIssue != nil ||
                busy
            )
            .opacity(
                !emailIsValid || passwordIssue != nil || busy
                    ? 0.55
                    : 1
            )

            Text(
                L10n.string(
                    "By creating an account, you can save opportunities and track applications privately."
                )
            )
            .font(.caption)
            .foregroundStyle(Theme.premiumMuted)
            .lineSpacing(3)
        }
    }

    private var createdState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 38))
                .foregroundStyle(Theme.premiumForest)

            Text(L10n.string("Account created"))
                .font(
                    .system(
                        size: 34,
                        weight: .regular,
                        design: .serif
                    )
                )
                .foregroundStyle(Theme.premiumInk)

            Text(
                L10n.string(
                    "Check your email to verify the account, then sign in."
                )
            )
            .font(.subheadline)
            .foregroundStyle(Theme.premiumMuted)
            .lineSpacing(3)

            Button {
                dismiss()
            } label: {
                Text(L10n.string("Done"))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.premiumForest)
                    .foregroundStyle(Theme.premiumIvory)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private extension View {
    func premiumSignupField() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(minHeight: 54)
            .background(Theme.premiumIvoryRaised)
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
                    Theme.premiumInk.opacity(0.07),
                    lineWidth: 1
                )
            )
    }
}
