import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var showingForgotPassword = false

    private var normalizedEmail: String {
        AuthValidation.normalizedEmail(email)
    }

    private var emailIsValid: Bool {
        AuthValidation.isValidEmail(email)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.premiumIvory
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(L10n.string("Welcome back"))
                                .font(
                                    .system(
                                        size: 36,
                                        weight: .regular,
                                        design: .serif
                                    )
                                )
                                .tracking(-0.9)
                                .foregroundStyle(Theme.premiumInk)

                            Text(
                                L10n.string(
                                    "Sign in to continue your applications and recommendations."
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
                            }
                            .premiumAuthField()

                            HStack(spacing: 10) {
                                Image(systemName: "lock")
                                    .foregroundStyle(Theme.premiumMuted)

                                SecureField(
                                    L10n.string("Password"),
                                    text: $password
                                )
                            }
                            .premiumAuthField()

                            if !email.isEmpty && !emailIsValid {
                                Text(
                                    L10n.string(
                                        "Enter a valid email address."
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(Theme.premiumBlush)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                            }
                        }

                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Theme.danger)
                                .padding(12)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
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
                                if await auth.signIn(
                                    email: normalizedEmail,
                                    password: password
                                ) {
                                    dismiss()
                                }
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
                                        ? L10n.string("Signing in…")
                                        : L10n.string("Sign in")
                                )
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
                            password.isEmpty ||
                            busy
                        )
                        .opacity(
                            !emailIsValid || password.isEmpty || busy
                                ? 0.55
                                : 1
                        )

                        Button {
                            showingForgotPassword = true
                        } label: {
                            Text(L10n.string("Forgot password?"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.premiumForest)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)

                        HStack {
                            Rectangle()
                                .fill(Theme.premiumInk.opacity(0.08))
                                .frame(height: 1)

                            Text(verbatim: "EduT")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.premiumMuted)

                            Rectangle()
                                .fill(Theme.premiumInk.opacity(0.08))
                                .frame(height: 1)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 34)
                    .padding(.bottom, 30)
                }
            }
            .preferredColorScheme(.light)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.premiumForest)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView(
                    initialEmail: email
                )
                .environment(auth)
                .preferredColorScheme(.light)
            }
        }
    }
}

private struct ForgotPasswordView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var busy = false
    @State private var sent = false

    private var normalizedEmail: String {
        AuthValidation.normalizedEmail(email)
    }

    private var emailIsValid: Bool {
        AuthValidation.isValidEmail(email)
    }

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.premiumIvory
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    if sent {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.premiumForest)

                        Text(L10n.string("Check your email"))
                            .font(
                                .system(
                                    size: 30,
                                    weight: .regular,
                                    design: .serif
                                )
                            )
                            .foregroundStyle(Theme.premiumInk)

                        Text(
                            L10n.string(
                                "Open the password reset link on this iPhone. EduT will open and ask you to choose a new password."
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
                                .frame(height: 52)
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
                    } else {
                        Text(L10n.string("Reset password"))
                            .font(
                                .system(
                                    size: 32,
                                    weight: .regular,
                                    design: .serif
                                )
                            )
                            .foregroundStyle(Theme.premiumInk)

                        Text(
                            L10n.string(
                                "Enter the email address used for your EduT account."
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(Theme.premiumMuted)

                        HStack(spacing: 10) {
                            Image(systemName: "envelope")
                                .foregroundStyle(Theme.premiumMuted)

                            TextField(
                                L10n.string("Email"),
                                text: $email
                            )
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        }
                        .premiumAuthField()

                        if !email.isEmpty && !emailIsValid {
                            Text(
                                L10n.string(
                                    "Enter a valid email address."
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(Theme.premiumBlush)
                        }

                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Theme.danger)
                        }

                        Button {
                            Task {
                                busy = true
                                sent = await auth.requestPasswordReset(
                                    email: normalizedEmail
                                )
                                busy = false
                            }
                        } label: {
                            Text(
                                busy
                                    ? L10n.string("Sending…")
                                    : L10n.string("Send reset email")
                            )
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
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
                        .disabled(!emailIsValid || busy)
                        .opacity(!emailIsValid || busy ? 0.55 : 1)
                    }

                    Spacer()
                }
                .padding(22)
                .padding(.top, 16)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Close")) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.premiumForest)
                }
            }
        }
    }
}

private extension View {
    func premiumAuthField() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 54)
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
