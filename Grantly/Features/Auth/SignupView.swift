import SwiftUI

struct SignupView: View {
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
            Form {
                if created {
                    Section {
                        Label("Account created", systemImage: "envelope.badge")
                            .font(.headline)
                        Text("Check your email to verify the account, then sign in.")
                            .foregroundStyle(.secondary)
                    }
                    Section { Button("Done") { dismiss() } }
                } else {
                    Section {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        SecureField("Password — at least 8 characters", text: $password)

                        if !email.isEmpty && !emailIsValid {
                            Text("Enter a valid email address.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if !password.isEmpty,
                           let passwordIssue {
                            Text(passwordIssue)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    if let error = auth.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.caption) }
                    }

                    Section {
                        Button(busy ? "Creating…" : "Create account") {
                            Task {
                                busy = true
                                created = await auth.signUp(
                                    email: normalizedEmail,
                                    password: password
                                )
                                busy = false
                            }
                        }
                        .disabled(
                            !emailIsValid ||
                            passwordIssue != nil ||
                            busy
                        )
                    }
                }
            }
            .navigationTitle("Create account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
