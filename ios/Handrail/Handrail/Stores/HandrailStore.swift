import Foundation
import Observation

@MainActor
@Observable
final class HandrailStore {
    var pairedMachine: PairedMachine?
    var chats: [CodexChat] = []
    var automations: [AutomationRecord] = []
    var transcripts: [String: [String]] = [:]
    var latestApproval: ApprovalRequest?
    var activity: [ActivityItem] = []
    var notifications: [HandrailNotification] = []
    var connectionText = "Offline"
    var defaultRepo = ""
    var newChatOptions: NewChatOptions?
    var lastError: String?
    var newChatError: String?
    var chatErrors: [String: String] = [:]
    var lastStartedChatId: String?
    var notificationChatId: String?
    var showsApprovalFromNotification = false
    var pinnedChatIds: Set<String> = []
    var dismissedAttentionChatIds: Set<String> = []
    var isRefreshingChats = false
    var lastChatRefreshAt: Date?

    private let storageKey = "handrail.pairedMachine"
    private let pairingTokenAccount = "paired-machine-token"
    private let pinnedStorageKey = "handrail.pinnedChatIds"
    private let dismissedAttentionStorageKey = "handrail.dismissedAttentionChatIds"
    private let client = HandrailWebSocketClient()
    private var awaitingStartedChat = false
    private var pendingErrorTarget: PendingErrorTarget?
    private var pushTokenRegistration: PushTokenRegistration?
    private var viewingChatCounts: [String: Int] = [:]

    init(enableNetworking: Bool = true) {
        loadPairing()
        loadPinnedChats()
        loadDismissedAttentionChats()
        client.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
        client.onConnectionChange = { [weak self] isOnline in
            Task { @MainActor in
                self?.connectionText = isOnline ? "Online" : "Offline"
                if var machine = self?.pairedMachine {
                    machine.isOnline = isOnline
                    self?.pairedMachine = machine
                }
            }
        }
        if enableNetworking, let pairedMachine {
            client.connect(to: pairedMachine)
        }
    }

    func pair(with payload: PairingPayload) {
        let machine = PairedMachine(
            protocolVersion: payload.protocolVersion,
            host: payload.host,
            port: payload.port,
            token: payload.token,
            machineName: payload.machineName,
            isOnline: false
        )
        pairedMachine = machine
        savePairing(machine)
        client.connect(to: machine)
    }

    func registerPushToken(_ registration: PushTokenRegistration) {
        pushTokenRegistration = registration
        sendPushTokenIfConnected()
    }

    func startChat(_ payload: StartChatPayload) {
        guard pairedMachine?.isOnline == true else {
            reportNewChatError("Mac is offline. Start the Handrail server and reconnect before starting a chat.")
            return
        }
        newChatError = nil
        pendingErrorTarget = .newChat
        awaitingStartedChat = true
        client.send(.startChat(payload))
    }

    func continueChat(chatId: String, prompt: String) {
        guard pairedMachine?.isOnline == true else {
            reportChatError("Mac is offline. Start the Handrail server and reconnect before continuing a chat.", chatId: chatId)
            return
        }
        chatErrors[chatId] = nil
        pendingErrorTarget = .chat(chatId)
        awaitingStartedChat = true
        client.send(.continueChat(chatId: chatId, prompt: prompt))
    }

    func refreshChats() {
        if pairedMachine?.isOnline != true {
            reconnect()
            return
        }
        guard let token = pairedMachine?.token else {
            isRefreshingChats = false
            return
        }
        isRefreshingChats = true
        client.send(.hello(token: token))
    }

    func refreshChatDetail(chatId: String) {
        guard pairedMachine?.isOnline == true else {
            return
        }
        client.send(.getChatDetail(chatId: chatId))
    }

    func clearNewChatError() {
        newChatError = nil
    }

    func clearChatError(chatId: String) {
        chatErrors[chatId] = nil
    }

    func reconnect() {
        guard let pairedMachine else {
            isRefreshingChats = false
            return
        }
        connectionText = "Reconnecting"
        isRefreshingChats = true
        client.connect(to: pairedMachine)
    }

    func sendInput(chatId: String, text: String) {
        chatErrors[chatId] = nil
        pendingErrorTarget = .chat(chatId)
        client.send(.sendChatInput(chatId: chatId, text: text))
    }

    func approve(_ approval: ApprovalRequest) {
        client.send(.approve(chatId: approval.chatId, approvalId: approval.approvalId))
        latestApproval = nil
    }

    func deny(_ approval: ApprovalRequest, reason: String) {
        client.send(.deny(chatId: approval.chatId, approvalId: approval.approvalId, reason: reason))
        latestApproval = nil
    }

    func stop(chatId: String) {
        chatErrors[chatId] = nil
        pendingErrorTarget = .chat(chatId)
        client.send(.stopChat(chatId: chatId))
    }

    func runAutomationNow(id: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before running an automation.")
            return
        }
        client.send(.runAutomation(automationId: id))
    }

    func pauseAutomation(id: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before pausing an automation.")
            return
        }
        client.send(.pauseAutomation(automationId: id))
    }

    func deleteAutomation(id: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before deleting an automation.")
            return
        }
        client.send(.deleteAutomation(automationId: id))
    }

    func deleteNotifications(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            notifications.remove(at: index)
        }
    }

    func clearNotifications() {
        notifications.removeAll()
    }

    func chat(id: String) -> CodexChat? {
        chats.first { $0.id == id }
    }

    func isPinned(chatId: String) -> Bool {
        chat(id: chatId)?.isPinned == true
    }

    func togglePin(chatId: String) {
        reportError("Pinning is owned by Codex Desktop. Change pinned chats in Codex Desktop, then refresh Handrail.")
    }

    func renameChat(chatId: String, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        reportError("Renaming is owned by Codex Desktop. Rename chats in Codex Desktop, then refresh Handrail.")
    }

    func archiveChat(chatId: String) {
        reportError("Archiving is owned by Codex Desktop. Archive chats in Codex Desktop, then refresh Handrail.")
    }

    func setChatReadState(chatId: String, isRead: Bool) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else {
            return
        }
        chats[index].hasUnreadTurn = !isRead
    }

    func isAttentionDismissed(chatId: String) -> Bool {
        dismissedAttentionChatIds.contains(chatId)
    }

    func dismissAttention(chatId: String) {
        dismissedAttentionChatIds.insert(chatId)
        saveDismissedAttentionChats()
    }

    func dismissAllAttention() {
        dismissedAttentionChatIds.formUnion(chats.filter(needsAttention).map(\.id))
        saveDismissedAttentionChats()
    }

    func restoreAttention(chatId: String) {
        dismissedAttentionChatIds.remove(chatId)
        saveDismissedAttentionChats()
    }

    func needsAttention(_ chat: CodexChat) -> Bool {
        chat.status == .waitingForApproval || chat.status == .failed
    }

    func consumeLastStartedChatId() {
        lastStartedChatId = nil
    }

    func consumeNotificationChatId() {
        notificationChatId = nil
    }

    func enterChat(chatId: String) {
        viewingChatCounts[chatId, default: 0] += 1
    }

    func leaveChat(chatId: String) {
        guard let count = viewingChatCounts[chatId] else {
            return
        }
        if count > 1 {
            viewingChatCounts[chatId] = count - 1
        } else {
            viewingChatCounts.removeValue(forKey: chatId)
        }
    }

    func isViewingChat(chatId: String) -> Bool {
        viewingChatCounts[chatId, default: 0] > 0
    }

    func approveFromNotification(chatId: String, approvalId: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before approving from a notification.")
            return
        }
        client.send(.approve(chatId: chatId, approvalId: approvalId))
        if latestApproval?.approvalId == approvalId {
            latestApproval = nil
        }
    }

    func denyFromNotification(chatId: String, approvalId: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before denying from a notification.")
            return
        }
        client.send(.deny(chatId: chatId, approvalId: approvalId, reason: "Denied from Handrail notification."))
        if latestApproval?.approvalId == approvalId {
            latestApproval = nil
        }
    }

    func replyFromNotification(chatId: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before replying from a notification.")
            return
        }
        client.send(.sendChatInput(chatId: chatId, text: trimmed))
        notificationChatId = chatId
    }

    func openChatFromNotification(chatId: String) {
        notificationChatId = chatId
    }

    func openApprovalFromNotification(chatId: String) {
        notificationChatId = chatId
        showsApprovalFromNotification = latestApproval?.chatId == chatId
    }

    func handle(_ message: ServerMessage) {
        switch message {
        case .machineStatus(let machineName, let online, let defaultRepo):
            connectionText = online ? "Online" : "Offline"
            if let defaultRepo {
                self.defaultRepo = defaultRepo
            }
            if var machine = pairedMachine {
                machine.isOnline = online
                pairedMachine = machine
            }
            addActivity("Machine online", machineName)
            sendPushTokenIfConnected()
        case .newChatOptions(let options):
            newChatOptions = options
        case .automationList(let automations):
            self.automations = automations
        case .chatList(let chats):
            self.chats = mergeChatListSummaries(chats, into: self.chats)
            pruneDismissedAttentionChats(against: chats)
            isRefreshingChats = false
            lastChatRefreshAt = Date()
            for chat in chats {
                if let transcript = chat.transcript {
                    transcripts[chat.id] = transcript
                }
            }
        case .chatDetail(let chat):
            upsert(chat)
        case .chatStarted(let chat):
            lastError = nil
            newChatError = nil
            chatErrors[chat.id] = nil
            pendingErrorTarget = nil
            upsert(chat)
            if awaitingStartedChat {
                awaitingStartedChat = false
                lastStartedChatId = chat.id
            }
            addActivity("Chat started", chat.title, chatId: chat.id)
        case .chatEvent(let chatId, let event):
            handleEvent(chatId: chatId, event: event)
        case .approvalRequired(let approval):
            latestApproval = approval
            markWaiting(chatId: approval.chatId, files: approval.files)
            addActivity("Approval requested", approval.summary, chatId: approval.chatId)
            if !approval.files.isEmpty {
                addActivity("Files detected", approval.files.joined(separator: ", "), chatId: approval.chatId)
            }
            insertNotification(title: "Approval required", detail: approval.summary, date: Date(), chatId: approval.chatId)
            HandrailNotificationCoordinator.shared.notifyApproval(
                approval,
                chatTitle: chat(id: approval.chatId)?.title ?? approval.title
            )
        case .commandResult(let ok, let message):
            if ok {
                addActivity("Command result", message)
            } else {
                reportPendingError(message)
            }
        case .error(let message):
            awaitingStartedChat = false
            isRefreshingChats = false
            reportPendingError(message)
        }
    }

    private func handleEvent(chatId: String, event: ChatEvent) {
        let date = event.at ?? Date()
        if case .chat(let pendingChatId) = pendingErrorTarget, pendingChatId == chatId {
            pendingErrorTarget = nil
            chatErrors[chatId] = nil
        }
        switch event.kind {
        case "output":
            let text = event.text ?? ""
            transcripts[chatId, default: []].append(text)
            classifyOutput(chatId: chatId, text: text, date: date)
        case "chat_completed":
            updateStatus(chatId: chatId, status: .completed)
            appendTranscript(chatId: chatId, text: event.text)
            let detail = notificationDetail(chatId: chatId, eventText: event.text)
            addActivity("Chat completed", detail, date: date, chatId: chatId)
            insertNotification(title: "Task completed", detail: detail, date: date, chatId: chatId)
            HandrailNotificationCoordinator.shared.notifyChatCompleted(chatId: chatId, text: detail)
        case "chat_failed":
            updateStatus(chatId: chatId, status: .failed)
            appendTranscript(chatId: chatId, text: event.text)
            let detail = notificationDetail(chatId: chatId, eventText: event.text)
            addActivity("Chat failed", detail, date: date, chatId: chatId)
            insertNotification(title: "Task failed", detail: detail, date: date, chatId: chatId)
            HandrailNotificationCoordinator.shared.notifyChatFailed(chatId: chatId, text: detail)
        case "chat_stopped":
            updateStatus(chatId: chatId, status: .stopped)
            appendTranscript(chatId: chatId, text: event.text)
            addActivity("Chat stopped", event.text ?? chatId, date: date, chatId: chatId)
        case "approval_approved", "approval_denied":
            updateStatus(chatId: chatId, status: .running)
            addActivity(event.kind == "approval_approved" ? "Approval sent" : "Denial sent", event.text ?? chatId, date: date, chatId: chatId)
        default:
            addActivity(event.kind.replacingOccurrences(of: "_", with: " "), event.text ?? chatId, date: date, chatId: chatId)
        }
    }

    private func upsert(_ chat: CodexChat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
        } else {
            chats.insert(chat, at: 0)
        }
        if let transcript = chat.transcript, !transcript.isEmpty {
            transcripts[chat.id] = transcript
        }
    }

    private func updateStatus(chatId: String, status: ChatStatus) {
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            chats[index].status = status
        }
    }

    private func markWaiting(chatId: String, files: [String]) {
        restoreAttention(chatId: chatId)
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            chats[index].status = .waitingForApproval
            chats[index].files = files
        }
    }

    private func classifyOutput(chatId: String, text: String, date: Date) {
        let lowercased = text.lowercased()
        if lowercased.contains("input required") {
            insertNotification(title: "Input required", detail: text, date: date, chatId: chatId)
            HandrailNotificationCoordinator.shared.notifyInputRequired(chatId: chatId, text: text)
        }
        if lowercased.contains("test failed") || lowercased.contains("tests failed") {
            insertNotification(title: "Tests failed", detail: text, date: date, chatId: chatId)
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("$ ") {
            addActivity("Command run", text, date: date, chatId: chatId)
        }
    }

    private func addActivity(_ title: String, _ detail: String, date: Date = Date(), chatId: String? = nil) {
        activity.insert(ActivityItem(title: title, detail: detail, date: date, chatId: chatId), at: 0)
    }

    private func appendTranscript(chatId: String, text: String?) {
        guard let text, !text.isEmpty else { return }
        transcripts[chatId, default: []].append(text.hasSuffix("\n") ? text : "\(text)\n")
    }

    private func notificationDetail(chatId: String, eventText: String?) -> String {
        let text = eventText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !text.isEmpty && !isRawCodexIdentifier(text) {
            return text
        }
        return humanChatLabel(chatId: chatId)
    }

    private func humanChatLabel(chatId: String) -> String {
        guard let chat = chat(id: chatId) else {
            return "Codex chat"
        }
        for candidate in [
            chat.title,
            chat.projectName ?? "",
            URL(fileURLWithPath: chat.repo).lastPathComponent
        ] {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !isRawCodexIdentifier(trimmed) {
                return trimmed
            }
        }
        return "Codex chat"
    }

    private func isRawCodexIdentifier(_ value: String) -> Bool {
        let candidate = value.replacingOccurrences(of: "^codex:", with: "", options: [.regularExpression, .caseInsensitive])
        return candidate.range(
            of: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func reportError(_ message: String) {
        lastError = message
        insertNotification(title: "Handrail error", detail: message, date: Date(), chatId: nil)
    }

    private func reportNewChatError(_ message: String) {
        newChatError = message
        insertNotification(title: "Handrail error", detail: message, date: Date(), chatId: nil)
    }

    private func reportChatError(_ message: String, chatId: String) {
        chatErrors[chatId] = message
        insertNotification(title: "Handrail error", detail: message, date: Date(), chatId: chatId)
    }

    private func reportPendingError(_ message: String) {
        switch pendingErrorTarget {
        case .newChat:
            reportNewChatError(message)
        case .chat(let chatId):
            reportChatError(message, chatId: chatId)
        case nil:
            reportError(message)
        }
        pendingErrorTarget = nil
    }

    private func sendPushTokenIfConnected() {
        guard pairedMachine?.isOnline == true, let pushTokenRegistration else { return }
        client.send(.registerPushToken(pushTokenRegistration))
    }

    private func insertNotification(title: String, detail: String, date: Date, chatId: String?) {
        if let chatId, isViewingChat(chatId: chatId) {
            return
        }
        notifications.removeAll { notification in
            notification.title == title &&
            notification.detail == detail &&
            notification.chatId == chatId
        }
        notifications.insert(HandrailNotification(title: title, detail: detail, date: date, chatId: chatId), at: 0)
    }

    private func loadPairing() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let metadata = try? JSONDecoder().decode(PairedMachineMetadata.self, from: data) {
            do {
                if let token = try KeychainStore.load(account: pairingTokenAccount) {
                    pairedMachine = metadata.machine(token: token)
                    return
                }
            } catch {
                reportError("Could not read pairing token from Keychain: \(error.localizedDescription)")
                return
            }
        }
        if let legacyMachine = try? JSONDecoder().decode(PairedMachine.self, from: data) {
            pairedMachine = legacyMachine
            savePairing(legacyMachine)
        }
    }

    private func savePairing(_ machine: PairedMachine) {
        do {
            try KeychainStore.save(machine.token, account: pairingTokenAccount)
            let metadata = PairedMachineMetadata(machine: machine)
            let data = try JSONEncoder().encode(metadata)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            reportError("Could not save pairing token to Keychain: \(error.localizedDescription)")
        }
    }

    private func loadPinnedChats() {
        let ids = UserDefaults.standard.stringArray(forKey: pinnedStorageKey) ?? []
        pinnedChatIds = Set(ids)
    }

    private func savePinnedChats() {
        UserDefaults.standard.set(Array(pinnedChatIds).sorted(), forKey: pinnedStorageKey)
    }

    private func loadDismissedAttentionChats() {
        let ids = UserDefaults.standard.stringArray(forKey: dismissedAttentionStorageKey) ?? []
        dismissedAttentionChatIds = Set(ids)
    }

    private func saveDismissedAttentionChats() {
        UserDefaults.standard.set(Array(dismissedAttentionChatIds).sorted(), forKey: dismissedAttentionStorageKey)
    }

    private func pruneDismissedAttentionChats(against chats: [CodexChat]) {
        let activeAttentionIds = Set(chats.filter(needsAttention).map(\.id))
        dismissedAttentionChatIds = dismissedAttentionChatIds.intersection(activeAttentionIds)
        saveDismissedAttentionChats()
    }
}

func mergeChatListSummaries(_ summaries: [CodexChat], into existingChats: [CodexChat]) -> [CodexChat] {
    let existingById = Dictionary(uniqueKeysWithValues: existingChats.map { ($0.id, $0) })
    return summaries.map { summary in
        guard let existing = existingById[summary.id] else {
            return summary
        }
        var merged = summary
        if merged.files == nil {
            merged.files = existing.files
        }
        if merged.transcript == nil {
            merged.transcript = existing.transcript
        }
        if merged.thinking == nil {
            merged.thinking = existing.thinking
        }
        if merged.acceptsInput == nil {
            merged.acceptsInput = existing.acceptsInput
        }
        return merged
    }
}

private enum PendingErrorTarget {
    case newChat
    case chat(String)
}

private struct PairedMachineMetadata: Codable {
    let protocolVersion: Int
    let host: String
    let port: Int
    let machineName: String

    init(machine: PairedMachine) {
        protocolVersion = machine.protocolVersion
        host = machine.host
        port = machine.port
        machineName = machine.machineName
    }

    func machine(token: String) -> PairedMachine {
        PairedMachine(
            protocolVersion: protocolVersion,
            host: host,
            port: port,
            token: token,
            machineName: machineName,
            isOnline: false
        )
    }
}
