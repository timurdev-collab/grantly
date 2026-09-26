import SwiftUI

struct SignupView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var created = false

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
                    }

                    if let error = auth.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.caption) }
                    }

                    Section {
                        Button(busy ? "Creating…" : "Create account") {
                            Task {
                                busy = true
                                created = await auth.signUp(email: email, password: password)
                                busy = false
                            }
                        }
                        .disabled(email.isEmpty || password.count < 8 || busy)
                    }
                }
            }
            .navigationTitle("Create account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
