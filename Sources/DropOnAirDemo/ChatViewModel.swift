import Foundation
import DropOnAirSDK

struct ChatItem: Identifiable {
    let id: String
    let fromUserId: String
    let text: String
    let timestamp: Int64
    let isSelf: Bool
    let groupId: String?

    init(id: String, fromUserId: String, text: String, timestamp: Int64, isSelf: Bool, groupId: String? = nil) {
        self.id = id; self.fromUserId = fromUserId; self.text = text
        self.timestamp = timestamp; self.isSelf = isSelf; self.groupId = groupId
    }
}

@MainActor
final class ChatViewModel: ObservableObject, DropOnAirDelegate {
    @Published private(set) var messages: [ChatItem] = []
    @Published private(set) var isConnected = false
    @Published private(set) var statusText  = "Connecting…"
    @Published var errorMessage: String?

    // Call state
    @Published var activeCallId: String?
    @Published var incomingCallFrom: String?
    @Published var showIncomingCall = false

    // Group state
    @Published var groups: [DOAGroup] = []
    @Published var activeGroupId: String?
    @Published var groupMessages: [ChatItem] = []

    private var client: DropOnAirClient?
    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    func connect() async {
        let sdk = DropOnAir.initialize(config: DropOnAirConfig(
            appId:                droponairAppId,
            publicApiKey:         droponairPublicApiKey,
            getUserJwt:           { [weak self] in try await self!.auth.getJwt() },
            tokenExchangeEndpoint: "\(backendURL)/api/droponair/token",
            keyDirectoryEndpoint:  "\(backendURL)/api/droponair/keys"
        ))
        sdk.delegate = self
        client = sdk

        do {
            try await sdk.connect(userId: auth.userId ?? "")
        } catch {
            errorMessage = error.localizedDescription
            statusText   = "Error: \(error.localizedDescription)"
        }
    }

    func send(to toUserId: String, text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let myId = auth.userId ?? ""
        Task {
            do {
                _ = try await client?.sendMessage(to: toUserId, text: text)
                messages.append(ChatItem(
                    id:         UUID().uuidString,
                    fromUserId: myId,
                    text:       text,
                    timestamp:  Int64(Date().timeIntervalSince1970 * 1000),
                    isSelf:     true
                ))
            } catch {
                errorMessage = "Send failed: \(error.localizedDescription)"
            }
        }
    }

    func disconnect() async {
        await DropOnAir.destroy()
        client = nil
        isConnected = false
        messages.removeAll()
    }

    // ── DropOnAirDelegate ────────────────────────────────────────────────────

    func dropOnAirDidConnect(_ client: DropOnAirClient) {
        isConnected = true
        statusText  = "Connected"
    }

    func dropOnAirDidDisconnect(_ client: DropOnAirClient, reason: String?, willReconnect: Bool) {
        isConnected = false
        statusText  = willReconnect ? "Reconnecting…" : "Offline"
    }

    func dropOnAir(_ client: DropOnAirClient, didReceiveMessage message: DOAMessage) {
        messages.append(ChatItem(
            id:         message.messageId,
            fromUserId: message.fromUserId,
            text:       message.text,
            timestamp:  message.timestamp,
            isSelf:     false
        ))
    }

    func dropOnAir(_ client: DropOnAirClient, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    // ── Call management ──────────────────────────────────────────────────────

    func startCall(to userId: String) {
        Task {
            do {
                let callId = try await client?.startCall(targetUserId: userId)
                activeCallId = callId
                statusText = "📞 Calling \(userId)…"
            } catch {
                errorMessage = "Call failed: \(error.localizedDescription)"
            }
        }
    }

    func acceptCall() {
        guard let callId = activeCallId else { return }
        Task {
            do {
                try await client?.acceptCall(callId: callId)
                showIncomingCall = false
                statusText = "📞 In call"
            } catch {
                errorMessage = "Accept failed: \(error.localizedDescription)"
            }
        }
    }

    func rejectCall() {
        guard let callId = activeCallId else { return }
        Task {
            do {
                try await client?.rejectCall(callId: callId)
                showIncomingCall = false
                activeCallId = nil
                statusText = "Connected"
            } catch {
                errorMessage = "Reject failed: \(error.localizedDescription)"
            }
        }
    }

    func endCall() {
        guard let callId = activeCallId else { return }
        Task {
            do {
                try await client?.endCall(callId: callId)
                activeCallId = nil
                statusText = "Connected"
            } catch {
                errorMessage = "End failed: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func dropOnAir(_ client: DropOnAirClient, didReceiveCallEvent event: DOACallEvent) {
        Task { @MainActor in
            switch event.type {
            case "CALL_INVITE":
                activeCallId = event.callId
                incomingCallFrom = event.targetUserId
                showIncomingCall = true
                statusText = "📞 Incoming call…"
            case "CALL_ACCEPTED":
                statusText = "📞 Call active"
            case "CALL_RINGING":
                statusText = "📞 Ringing…"
            case "CALL_ENDED", "CALL_REJECTED", "CALL_CANCELLED":
                activeCallId = nil
                showIncomingCall = false
                statusText = "Connected"
            case "CALL_DENIED_LIMIT_REACHED":
                activeCallId = nil
                statusText = "⚠ Call limit reached"
            default:
                break
            }
        }
    }

    // ── Group delegate ───────────────────────────────────────────────────────

    func dropOnAir(_ client: DropOnAirClient, didReceiveGroupMessage message: DOAGroupMessage) {
        groupMessages.append(ChatItem(
            id: message.messageId,
            fromUserId: message.fromUserId,
            text: message.text,
            timestamp: message.timestamp,
            isSelf: false,
            groupId: message.groupId
        ))
    }

    func dropOnAir(_ client: DropOnAirClient, didAcknowledgeGroupMessage messageId: String, groupId: String, ackType: String) {}
    func dropOnAir(_ client: DropOnAirClient, didReceiveGroupCallEvent event: DOAGroupCallEvent) {}

    // ── Group management ─────────────────────────────────────────────────────

    func loadGroups() {
        Task {
            do {
                groups = try await client?.getGroups() ?? []
            } catch {
                errorMessage = "Load groups failed: \(error.localizedDescription)"
            }
        }
    }

    func createGroup(name: String) {
        Task {
            do {
                let group = try await client?.createGroup(name: name, memberUserIds: [])
                if let g = group { groups.append(g) }
            } catch {
                errorMessage = "Create group failed: \(error.localizedDescription)"
            }
        }
    }

    func sendGroupMessage(text: String) {
        guard let gid = activeGroupId, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let myId = auth.userId ?? ""
        Task {
            do {
                try await client?.sendCleartextGroupMessage(groupId: gid, text: text)
                groupMessages.append(ChatItem(
                    id: UUID().uuidString,
                    fromUserId: myId,
                    text: text,
                    timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                    isSelf: true,
                    groupId: gid
                ))
            } catch {
                errorMessage = "Group send failed: \(error.localizedDescription)"
            }
        }
    }
}
