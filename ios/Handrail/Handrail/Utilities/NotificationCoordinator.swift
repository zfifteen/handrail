import Foundation
import UserNotifications

final class HandrailNotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = HandrailNotificationCoordinator()

    private weak var store: HandrailStore?

    private override init() {}

    func attach(store: HandrailStore) {
        self.store = store
    }

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            approvalCategory,
            inputCategory,
            sessionCategory
        ])
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func notifyApproval(_ approval: ApprovalRequest, sessionTitle: String) {
        let content = baseContent(
            title: "Approval required",
            body: approval.summary,
            category: "HANDRAIL_APPROVAL",
            sessionId: approval.sessionId
        )
        content.subtitle = sessionTitle
        content.userInfo["approvalId"] = approval.approvalId
        schedule(content, identifier: "handrail.approval.\(approval.approvalId)")
    }

    func notifyInputRequired(sessionId: String, text: String) {
        let content = baseContent(
            title: "Input required",
            body: text,
            category: "HANDRAIL_INPUT",
            sessionId: sessionId
        )
        schedule(content, identifier: "handrail.input.\(sessionId)")
    }

    func notifySessionFailed(sessionId: String, text: String) {
        let content = baseContent(
            title: "Task failed",
            body: text,
            category: "HANDRAIL_SESSION",
            sessionId: sessionId
        )
        schedule(content, identifier: "handrail.failed.\(sessionId)")
    }

    func notifySessionCompleted(sessionId: String, text: String) {
        let content = baseContent(
            title: "Task completed",
            body: text,
            category: "HANDRAIL_SESSION",
            sessionId: sessionId
        )
        content.sound = nil
        schedule(content, identifier: "handrail.completed.\(sessionId)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let sessionId = userInfo["sessionId"] as? String
        let approvalId = userInfo["approvalId"] as? String

        Task { @MainActor in
            switch response.actionIdentifier {
            case "HANDRAIL_APPROVE":
                if let sessionId, let approvalId {
                    store?.approveFromNotification(sessionId: sessionId, approvalId: approvalId)
                }
            case "HANDRAIL_DENY":
                if let sessionId, let approvalId {
                    store?.denyFromNotification(sessionId: sessionId, approvalId: approvalId)
                }
            case "HANDRAIL_OPEN_DIFF":
                if let sessionId {
                    store?.openApprovalFromNotification(sessionId: sessionId)
                }
            case "HANDRAIL_REPLY":
                if let sessionId, let response = response as? UNTextInputNotificationResponse {
                    store?.replyFromNotification(sessionId: sessionId, text: response.userText)
                }
            default:
                if let sessionId {
                    store?.openSessionFromNotification(sessionId: sessionId)
                }
            }
            completionHandler()
        }
    }

    private var approvalCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: "HANDRAIL_APPROVAL",
            actions: [
                UNNotificationAction(
                    identifier: "HANDRAIL_APPROVE",
                    title: "Approve",
                    options: [.authenticationRequired]
                ),
                UNNotificationAction(
                    identifier: "HANDRAIL_DENY",
                    title: "Deny",
                    options: [.authenticationRequired, .destructive]
                ),
                UNNotificationAction(
                    identifier: "HANDRAIL_OPEN_DIFF",
                    title: "Open Diff",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    private var inputCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: "HANDRAIL_INPUT",
            actions: [
                UNTextInputNotificationAction(
                    identifier: "HANDRAIL_REPLY",
                    title: "Reply",
                    options: [.authenticationRequired],
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Reply to Codex"
                )
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    private var sessionCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: "HANDRAIL_SESSION",
            actions: [
                UNNotificationAction(
                    identifier: "HANDRAIL_OPEN_SESSION",
                    title: "Open Session",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    private func baseContent(title: String, body: String, category: String, sessionId: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.sound = .default
        content.userInfo = ["sessionId": sessionId]
        return content
    }

    private func schedule(_ content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
