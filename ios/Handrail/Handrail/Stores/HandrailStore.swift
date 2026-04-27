import Foundation
import Observation

@MainActor
@Observable
final class HandrailStore {
    var pairedMachine: PairedMachine?
    var sessions: [HandrailSession] = []
    var transcripts: [String: [String]] = [:]
    var latestApproval: ApprovalRequest?
    var activity: [ActivityItem] = []
    var notifications: [HandrailNotification] = []
    var connectionText = "Offline"
    var defaultRepo = ""
    var newChatOptions: NewChatOptions?
    var lastError: String?
    var lastStartedSessionId: String?
    var notificationSessionId: String?
    var showsApprovalFromNotification = false
    var pinnedSessionIds: Set<String> = []
    var dismissedAttentionSessionIds: Set<String> = []
    var isRefreshingSessions = false
    var lastSessionRefreshAt: Date?

    private let storageKey = "handrail.pairedMachine"
    private let pinnedStorageKey = "handrail.pinnedSessionIds"
    private let dismissedAttentionStorageKey = "handrail.dismissedAttentionSessionIds"
    private let client = HandrailWebSocketClient()
    private var awaitingStartedSession = false

    init(enableNetworking: Bool = true) {
        loadPairing()
        loadPinnedSessions()
        loadDismissedAttentionSessions()
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

    func startSession(repo: String, title: String, prompt: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Start the Handrail server and reconnect before starting a session.")
            return
        }
        lastError = nil
        awaitingStartedSession = true
        client.send(.startSession(repo: repo, title: title, prompt: prompt))
    }

    func startChat(_ payload: StartChatPayload) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Start the Handrail server and reconnect before starting a chat.")
            return
        }
        lastError = nil
        awaitingStartedSession = true
        client.send(.startChat(payload))
    }

    func continueSession(sessionId: String, prompt: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Start the Handrail server and reconnect before continuing a chat.")
            return
        }
        lastError = nil
        awaitingStartedSession = true
        client.send(.continueSession(sessionId: sessionId, prompt: prompt))
    }

    func refreshSessions() {
        if pairedMachine?.isOnline != true {
            reconnect()
            return
        }
        guard let token = pairedMachine?.token else {
            isRefreshingSessions = false
            return
        }
        isRefreshingSessions = true
        client.send(.hello(token: token))
    }

    func reconnect() {
        guard let pairedMachine else {
            isRefreshingSessions = false
            return
        }
        connectionText = "Reconnecting"
        isRefreshingSessions = true
        client.connect(to: pairedMachine)
    }

    func sendInput(sessionId: String, text: String) {
        client.send(.sendInput(sessionId: sessionId, text: text))
    }

    func approve(_ approval: ApprovalRequest) {
        client.send(.approve(sessionId: approval.sessionId, approvalId: approval.approvalId))
        latestApproval = nil
    }

    func deny(_ approval: ApprovalRequest, reason: String) {
        client.send(.deny(sessionId: approval.sessionId, approvalId: approval.approvalId, reason: reason))
        latestApproval = nil
    }

    func stop(sessionId: String) {
        client.send(.stopSession(sessionId: sessionId))
    }

    func session(id: String) -> HandrailSession? {
        sessions.first { $0.id == id }
    }

    func isPinned(sessionId: String) -> Bool {
        if let session = session(id: sessionId), session.source == "codex" {
            return session.isPinned == true
        }
        return pinnedSessionIds.contains(sessionId)
    }

    func togglePin(sessionId: String) {
        if let session = session(id: sessionId), session.source == "codex" {
            return
        }
        if pinnedSessionIds.contains(sessionId) {
            pinnedSessionIds.remove(sessionId)
        } else {
            pinnedSessionIds.insert(sessionId)
        }
        savePinnedSessions()
    }

    func isAttentionDismissed(sessionId: String) -> Bool {
        dismissedAttentionSessionIds.contains(sessionId)
    }

    func dismissAttention(sessionId: String) {
        dismissedAttentionSessionIds.insert(sessionId)
        saveDismissedAttentionSessions()
    }

    func dismissAllAttention() {
        dismissedAttentionSessionIds.formUnion(sessions.filter(needsAttention).map(\.id))
        saveDismissedAttentionSessions()
    }

    func restoreAttention(sessionId: String) {
        dismissedAttentionSessionIds.remove(sessionId)
        saveDismissedAttentionSessions()
    }

    func needsAttention(_ session: HandrailSession) -> Bool {
        session.status == .waitingForApproval || session.status == .failed
    }

    func consumeLastStartedSessionId() {
        lastStartedSessionId = nil
    }

    func consumeNotificationSessionId() {
        notificationSessionId = nil
    }

    func approveFromNotification(sessionId: String, approvalId: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before approving from a notification.")
            return
        }
        client.send(.approve(sessionId: sessionId, approvalId: approvalId))
        if latestApproval?.approvalId == approvalId {
            latestApproval = nil
        }
    }

    func denyFromNotification(sessionId: String, approvalId: String) {
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before denying from a notification.")
            return
        }
        client.send(.deny(sessionId: sessionId, approvalId: approvalId, reason: "Denied from Handrail notification."))
        if latestApproval?.approvalId == approvalId {
            latestApproval = nil
        }
    }

    func replyFromNotification(sessionId: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard pairedMachine?.isOnline == true else {
            reportError("Mac is offline. Reconnect before replying from a notification.")
            return
        }
        client.send(.sendInput(sessionId: sessionId, text: trimmed))
        notificationSessionId = sessionId
    }

    func openSessionFromNotification(sessionId: String) {
        notificationSessionId = sessionId
    }

    func openApprovalFromNotification(sessionId: String) {
        notificationSessionId = sessionId
        showsApprovalFromNotification = latestApproval?.sessionId == sessionId
    }

    private func handle(_ message: ServerMessage) {
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
        case .newChatOptions(let options):
            newChatOptions = options
        case .sessionList(let sessions):
            self.sessions = sessions
            pruneDismissedAttentionSessions(against: sessions)
            isRefreshingSessions = false
            lastSessionRefreshAt = Date()
            for session in sessions {
                if let transcript = session.transcript, !transcript.isEmpty {
                    transcripts[session.id] = transcript
                }
            }
        case .sessionStarted(let session):
            lastError = nil
            upsert(session)
            if awaitingStartedSession {
                awaitingStartedSession = false
                lastStartedSessionId = session.id
            }
            addActivity("Session started", session.title, sessionId: session.id)
        case .sessionEvent(let sessionId, let event):
            handleEvent(sessionId: sessionId, event: event)
        case .approvalRequired(let approval):
            latestApproval = approval
            markWaiting(sessionId: approval.sessionId, files: approval.files)
            addActivity("Approval requested", approval.summary, sessionId: approval.sessionId)
            if !approval.files.isEmpty {
                addActivity("Files detected", approval.files.joined(separator: ", "), sessionId: approval.sessionId)
            }
            notifications.insert(HandrailNotification(title: "Approval required", detail: approval.summary, date: Date(), sessionId: approval.sessionId), at: 0)
            HandrailNotificationCoordinator.shared.notifyApproval(
                approval,
                sessionTitle: session(id: approval.sessionId)?.title ?? approval.title
            )
        case .error(let message):
            awaitingStartedSession = false
            isRefreshingSessions = false
            reportError(message)
        case .ignored:
            break
        }
    }

    private func handleEvent(sessionId: String, event: SessionEvent) {
        let date = event.at ?? Date()
        switch event.kind {
        case "output":
            let text = event.text ?? ""
            transcripts[sessionId, default: []].append(text)
            classifyOutput(sessionId: sessionId, text: text, date: date)
        case "session_completed":
            updateStatus(sessionId: sessionId, status: .completed)
            appendTranscript(sessionId: sessionId, text: event.text)
            addActivity("Session completed", event.text ?? sessionId, date: date, sessionId: sessionId)
            notifications.insert(HandrailNotification(title: "Task completed", detail: event.text ?? sessionId, date: date, sessionId: sessionId), at: 0)
            HandrailNotificationCoordinator.shared.notifySessionCompleted(sessionId: sessionId, text: event.text ?? sessionId)
        case "session_failed":
            updateStatus(sessionId: sessionId, status: .failed)
            appendTranscript(sessionId: sessionId, text: event.text)
            addActivity("Session failed", event.text ?? sessionId, date: date, sessionId: sessionId)
            notifications.insert(HandrailNotification(title: "Task failed", detail: event.text ?? sessionId, date: date, sessionId: sessionId), at: 0)
            HandrailNotificationCoordinator.shared.notifySessionFailed(sessionId: sessionId, text: event.text ?? sessionId)
        case "session_stopped":
            updateStatus(sessionId: sessionId, status: .stopped)
            appendTranscript(sessionId: sessionId, text: event.text)
            addActivity("Session stopped", event.text ?? sessionId, date: date, sessionId: sessionId)
        case "approval_approved", "approval_denied":
            updateStatus(sessionId: sessionId, status: .running)
            addActivity(event.kind == "approval_approved" ? "Approval sent" : "Denial sent", event.text ?? sessionId, date: date, sessionId: sessionId)
        default:
            addActivity(event.kind.replacingOccurrences(of: "_", with: " "), event.text ?? sessionId, date: date, sessionId: sessionId)
        }
    }

    private func upsert(_ session: HandrailSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        if let transcript = session.transcript, !transcript.isEmpty {
            transcripts[session.id] = transcript
        }
    }

    private func updateStatus(sessionId: String, status: SessionStatus) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].status = status
        }
    }

    private func markWaiting(sessionId: String, files: [String]) {
        restoreAttention(sessionId: sessionId)
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].status = .waitingForApproval
            sessions[index].files = files
        }
    }

    private func classifyOutput(sessionId: String, text: String, date: Date) {
        let lowercased = text.lowercased()
        if lowercased.contains("input required") {
            notifications.insert(HandrailNotification(title: "Input required", detail: text, date: date, sessionId: sessionId), at: 0)
            HandrailNotificationCoordinator.shared.notifyInputRequired(sessionId: sessionId, text: text)
        }
        if lowercased.contains("test failed") || lowercased.contains("tests failed") {
            notifications.insert(HandrailNotification(title: "Tests failed", detail: text, date: date, sessionId: sessionId), at: 0)
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("$ ") {
            addActivity("Command run", text, date: date, sessionId: sessionId)
        }
    }

    private func addActivity(_ title: String, _ detail: String, date: Date = Date(), sessionId: String? = nil) {
        activity.insert(ActivityItem(title: title, detail: detail, date: date, sessionId: sessionId), at: 0)
    }

    private func appendTranscript(sessionId: String, text: String?) {
        guard let text, !text.isEmpty else { return }
        transcripts[sessionId, default: []].append(text.hasSuffix("\n") ? text : "\(text)\n")
    }

    private func reportError(_ message: String) {
        lastError = message
        notifications.insert(HandrailNotification(title: "Handrail error", detail: message, date: Date(), sessionId: nil), at: 0)
    }

    private func loadPairing() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        pairedMachine = try? JSONDecoder().decode(PairedMachine.self, from: data)
    }

    private func savePairing(_ machine: PairedMachine) {
        let data = try? JSONEncoder().encode(machine)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadPinnedSessions() {
        let ids = UserDefaults.standard.stringArray(forKey: pinnedStorageKey) ?? []
        pinnedSessionIds = Set(ids)
    }

    private func savePinnedSessions() {
        UserDefaults.standard.set(Array(pinnedSessionIds).sorted(), forKey: pinnedStorageKey)
    }

    private func loadDismissedAttentionSessions() {
        let ids = UserDefaults.standard.stringArray(forKey: dismissedAttentionStorageKey) ?? []
        dismissedAttentionSessionIds = Set(ids)
    }

    private func saveDismissedAttentionSessions() {
        UserDefaults.standard.set(Array(dismissedAttentionSessionIds).sorted(), forKey: dismissedAttentionStorageKey)
    }

    private func pruneDismissedAttentionSessions(against sessions: [HandrailSession]) {
        let activeAttentionIds = Set(sessions.filter(needsAttention).map(\.id))
        dismissedAttentionSessionIds = dismissedAttentionSessionIds.intersection(activeAttentionIds)
        saveDismissedAttentionSessions()
    }
}
