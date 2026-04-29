import Foundation
import UIKit
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
            chatCategory
        ])
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    @MainActor
    func notifyApproval(_ approval: ApprovalRequest, chatTitle: String) {
        let content = baseContent(
            title: "Approval required",
            body: approval.summary,
            category: "HANDRAIL_APPROVAL",
            chatId: approval.chatId
        )
        content.subtitle = chatTitle
        content.userInfo["approvalId"] = approval.approvalId
        schedule(content, identifier: "handrail.approval.\(approval.approvalId)")
    }

    @MainActor
    func notifyInputRequired(chatId: String, text: String) {
        let content = baseContent(
            title: "Input required",
            body: text,
            category: "HANDRAIL_INPUT",
            chatId: chatId
        )
        schedule(content, identifier: "handrail.input.\(chatId)")
    }

    @MainActor
    func notifyChatFailed(chatId: String, text: String) {
        let content = baseContent(
            title: "Task failed",
            body: text,
            category: "HANDRAIL_CHAT",
            chatId: chatId
        )
        schedule(content, identifier: "handrail.failed.\(chatId)")
    }

    @MainActor
    func notifyChatCompleted(chatId: String, text: String) {
        let content = baseContent(
            title: "Task completed",
            body: text,
            category: "HANDRAIL_CHAT",
            chatId: chatId
        )
        content.sound = nil
        schedule(content, identifier: "handrail.completed.\(chatId)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let chatId = notification.request.content.userInfo["chatId"] as? String
        Task { @MainActor in
            if let chatId, store?.isViewingChat(chatId: chatId) == true {
                completionHandler([])
                return
            }
            completionHandler([.banner, .list, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let chatId = userInfo["chatId"] as? String
        let approvalId = userInfo["approvalId"] as? String

        Task { @MainActor in
            switch response.actionIdentifier {
            case "HANDRAIL_APPROVE":
                if let chatId, let approvalId {
                    store?.approveFromNotification(chatId: chatId, approvalId: approvalId)
                }
            case "HANDRAIL_DENY":
                if let chatId, let approvalId {
                    store?.denyFromNotification(chatId: chatId, approvalId: approvalId)
                }
            case "HANDRAIL_OPEN_DIFF":
                if let chatId {
                    store?.openApprovalFromNotification(chatId: chatId)
                }
            case "HANDRAIL_REPLY":
                if let chatId, let response = response as? UNTextInputNotificationResponse {
                    store?.replyFromNotification(chatId: chatId, text: response.userText)
                }
            default:
                if let chatId {
                    store?.openChatFromNotification(chatId: chatId)
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

    private var chatCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: "HANDRAIL_CHAT",
            actions: [
                UNNotificationAction(
                    identifier: "HANDRAIL_OPEN_CHAT",
                    title: "Open Chat",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    private func baseContent(title: String, body: String, category: String, chatId: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.sound = .default
        content.userInfo = ["chatId": chatId]
        return content
    }

    @MainActor
    private func schedule(_ content: UNMutableNotificationContent, identifier: String) {
        let chatId = content.userInfo["chatId"] as? String
        if UIApplication.shared.applicationState == .active,
           let chatId,
           store?.isViewingChat(chatId: chatId) == true {
            return
        }
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
