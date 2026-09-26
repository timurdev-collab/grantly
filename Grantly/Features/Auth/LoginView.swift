import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var showingForgotPassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $password)
                }

                if let error = auth.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(busy ? "Signing in…" : "Sign in") {
                        Task {
                            busy = true
                            if await auth.signIn(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password
                            ) {
                                dismiss()
                            }
                            busy = false
                        }
                    }
                    .disabled(
                        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        password.isEmpty ||
                        busy
                    )

                    Button("Forgot password?") {
                        showingForgotPassword = true
                    }
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView(
                    initialEmail: email
                )
                .environment(auth)
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

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label(
                            "Check your email",
                            systemImage: "envelope.badge"
                        )
                        .font(.headline)

                        Text("Open the password reset link on this iPhone. Grantly will open and ask you to choose a new password.")
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button("Done") {
                            dismiss()
                        }
                    }
                } else {
                    Section {
                        Text("Enter the email address used for your Grantly account.")
                            .foregroundStyle(.secondary)

                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    }

                    if let error = auth.errorMessage {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button(busy ? "Sending…" : "Send reset email") {
                            Task {
                                busy = true
                                sent = await auth.requestPasswordReset(
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                                busy = false
                            }
                        }
                        .disabled(
                            email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            busy
                        )
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
