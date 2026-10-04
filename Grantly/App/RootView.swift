import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Opening EduT…")
            } else if auth.userId == nil {
                WelcomeView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: auth.userId)
        .sheet(isPresented: Binding(
            get: { auth.needsPasswordReset },
            set: { if !$0 { auth.cancelPasswordReset() } }
        )) {
            PasswordResetView()
                .environment(auth)
                .interactiveDismissDisabled()
        }
    }
}

private struct PasswordResetView: View {
    @Environment(AuthStore.self) private var auth

    @State private var password = ""
    @State private var confirmation = ""
    @State private var busy = false

    private var passwordIssue: String? {
        AuthValidation.passwordIssue(password)
    }

    private var canSave: Bool {
        passwordIssue == nil &&
        password == confirmation &&
        !busy
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose a new password for your EduT account.")
                        .foregroundStyle(.secondary)
                }

                Section("New password") {
                    SecureField("At least 8 characters", text: $password)
                    SecureField("Confirm password", text: $confirmation)

                    if !password.isEmpty,
                       let passwordIssue {
                        Text(passwordIssue)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !confirmation.isEmpty && password != confirmation {
                        Text("Passwords do not match.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let error = auth.errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(busy ? "Updating…" : "Update password") {
                        Task {
                            busy = true
                            _ = await auth.updateRecoveredPassword(password)
                            busy = false
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        auth.cancelPasswordReset()
                    }
                    .disabled(busy)
                }
            }
        }
    }
}
