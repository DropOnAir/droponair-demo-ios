import SwiftUI

@main
struct DropOnAirDemoApp: App {
    @StateObject private var auth = AuthService()
    @State private var chatVM: ChatViewModel?

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if let vm = chatVM {
                    ChatView(vm: vm)
                        .environmentObject(auth)
                } else {
                    LoginView { vm in
                        // LoginView already called connect(); just keep the vm.
                        chatVM = vm
                    }
                    .environmentObject(auth)
                }
            }
        }
    }
}
