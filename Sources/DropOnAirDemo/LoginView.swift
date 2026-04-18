import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var userId      = ""
    @State private var displayName = ""
    @State private var isLoading   = false
    @State private var errorMsg: String?

    var onLoggedIn: (ChatViewModel) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Demo Login") {
                    TextField("User ID (e.g. alice)", text: $userId)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Display Name (optional)", text: $displayName)
                }

                Section {
                    Button {
                        guard !userId.trimmingCharacters(in: .whitespaces).isEmpty else {
                            errorMsg = "User ID is required"; return
                        }
                        Task { await login() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView() }
                            Text(isLoading ? "Connecting…" : "Sign In")
                        }
                    }
                    .disabled(isLoading)
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("DropOnAir Demo")
        }
    }

    private func login() async {
        isLoading = true
        errorMsg  = nil
        do {
            let vm = ChatViewModel(auth: auth)
            try await auth.login(
                userId:      userId.trimmingCharacters(in: .whitespaces),
                displayName: displayName.isEmpty ? nil : displayName
            )
            await vm.connect()
            onLoggedIn(vm)
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}
