import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false

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
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }

                Section {
                    Button(busy ? "Signing in…" : "Sign in") {
                        Task {
                            busy = true
                            if await auth.signIn(email: email, password: password) { dismiss() }
                            busy = false
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || busy)
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
