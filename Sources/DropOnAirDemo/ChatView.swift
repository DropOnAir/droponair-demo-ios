import SwiftUI

struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    @EnvironmentObject var auth: AuthService
    @State private var toUserId   = ""
    @State private var messageText = ""
    @State private var tab: Tab = .dm
    @State private var groupMessageText = ""
    @State private var newGroupName = ""
    @State private var editTarget: ChatItem?
    @State private var editDraft = ""

    enum Tab { case dm, groups }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                Circle()
                    .fill(vm.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(vm.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Me: \(auth.userId ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))

            // Tab picker
            Picker("", selection: $tab) {
                Text("DM").tag(Tab.dm)
                Text("Groups").tag(Tab.groups)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 4)

            Divider()

            if tab == .dm {
                dmContent
            } else {
                groupContent
            }
        }
        .navigationTitle("Chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Incoming Call", isPresented: $vm.showIncomingCall) {
            Button("Accept") { vm.acceptCall() }
            Button("Reject", role: .destructive) { vm.rejectCall() }
        } message: {
            Text("Call from \(vm.incomingCallFrom ?? "unknown")")
        }
        .alert("Error", isPresented: Binding(
            get:  { vm.errorMessage != nil },
            set:  { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Edit message", isPresented: Binding(
            get: { editTarget != nil },
            set: { if !$0 { editTarget = nil } }
        )) {
            TextField("New text", text: $editDraft)
            Button("Cancel", role: .cancel) { editTarget = nil }
            Button("Save") {
                if let target = editTarget, let to = target.toUserId {
                    let next = editDraft.trimmingCharacters(in: .whitespaces)
                    if !next.isEmpty && next != target.text {
                        vm.edit(messageId: target.id, to: to, newText: next)
                    }
                }
                editTarget = nil
            }
        } message: {
            Text("Update the message text. Recipients see the new content; the relay never sees plaintext.")
        }
    }

    // ── DM tab ───────────────────────────────────────────────────────────────

    private var dmContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(vm.messages) { item in
                            MessageBubble(item: item)
                                .id(item.id)
                                .contextMenu {
                                    if item.isSelf && !item.deleted, let to = item.toUserId {
                                        Button {
                                            editTarget = item
                                            editDraft = item.text
                                        } label: { Label("Edit", systemImage: "pencil") }
                                        Button(role: .destructive) {
                                            vm.delete(messageId: item.id, to: to, scope: "FOR_EVERYONE")
                                        } label: { Label("Delete for everyone", systemImage: "trash") }
                                        Button {
                                            vm.delete(messageId: item.id, to: to, scope: "FOR_ME")
                                        } label: { Label("Delete for me", systemImage: "trash.slash") }
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) { _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("To user ID", text: $toUserId)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                TextField("Message…", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let text = messageText.trimmingCharacters(in: .whitespaces)
                    let to   = toUserId.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty, !to.isEmpty else { return }
                    vm.send(to: to, text: text)
                    messageText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    if vm.activeCallId != nil {
                        vm.endCall()
                    } else {
                        let to = toUserId.trimmingCharacters(in: .whitespaces)
                        guard !to.isEmpty else { return }
                        vm.startCall(to: to)
                    }
                } label: {
                    Image(systemName: vm.activeCallId != nil ? "phone.down.fill" : "phone.fill")
                        .foregroundColor(vm.activeCallId != nil ? .red : .green)
                }
            }
            .padding()
        }
    }

    // ── Groups tab ───────────────────────────────────────────────────────────

    private var groupContent: some View {
        VStack(spacing: 0) {
            if vm.activeGroupId == nil {
                // Create group bar
                HStack {
                    TextField("Group name", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let name = newGroupName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        vm.createGroup(name: name)
                        newGroupName = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .padding()

                // Group list
                List(vm.groups, id: \.groupId) { group in
                    Button {
                        vm.activeGroupId = group.groupId
                        vm.groupMessages = []
                    } label: {
                        HStack {
                            Image(systemName: "person.3.fill")
                            VStack(alignment: .leading) {
                                Text(group.name ?? group.groupId)
                                    .font(.headline)
                                Text("\(group.members.count) members")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onAppear { vm.loadGroups() }
            } else {
                // Group chat view
                HStack {
                    Button {
                        vm.activeGroupId = nil
                    } label: {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    Spacer()
                    Text(vm.activeGroupId ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(vm.groupMessages) { item in
                                MessageBubble(item: item)
                                    .id(item.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: vm.groupMessages.count) { _ in
                        if let last = vm.groupMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    TextField("Group message…", text: $groupMessageText)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let text = groupMessageText.trimmingCharacters(in: .whitespaces)
                        guard !text.isEmpty else { return }
                        vm.sendGroupMessage(text: text)
                        groupMessageText = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(groupMessageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
        }
    }
}

private struct MessageBubble: View {
    let item: ChatItem

    var body: some View {
        HStack {
            if item.isSelf { Spacer() }
            VStack(alignment: item.isSelf ? .trailing : .leading, spacing: 2) {
                if !item.isSelf {
                    Text(item.fromUserId)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(item.text)
                    .italic(item.deleted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleBackground)
                    .foregroundColor(item.deleted ? .secondary : (item.isSelf ? .white : .primary))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                HStack(spacing: 4) {
                    Text(formattedTime(item.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if item.edited && !item.deleted {
                        Text("· edited")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if !item.isSelf { Spacer() }
        }
    }

    private var bubbleBackground: Color {
        if item.deleted { return Color.gray.opacity(0.15) }
        return item.isSelf ? Color.blue : Color.gray.opacity(0.2)
    }

    private func formattedTime(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(ms) / 1000)
        let fmt  = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}
