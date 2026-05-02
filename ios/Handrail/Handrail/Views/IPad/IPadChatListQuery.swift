import Foundation

struct IPadChatListRow: Identifiable, Hashable {
    let chat: CodexChat
    let displayTitle: String
    let projectName: String
    let statusTitle: String
    let sortDate: Date
    let isPinned: Bool
    let pinnedOrder: Int?

    var id: String { chat.id }
}

struct IPadChatListProjectGroup: Identifiable, Hashable {
    let project: String
    let rows: [IPadChatListRow]

    var id: String { project }
}

enum IPadChatListQuery {
    static func rows(
        from chats: [CodexChat],
        searchText: String = "",
        filter: ChatListFilter = .all,
        sort: ChatListSort = .updated
    ) -> [IPadChatListRow] {
        chats
            .filter { matches(filter: filter, chat: $0) }
            .map { row(for: $0, sort: sort) }
            .filter { matches(searchText: searchText, row: $0) }
            .sorted { left, right in
                compare(left, right)
            }
    }

    static func groupedRows(
        from chats: [CodexChat],
        searchText: String = "",
        filter: ChatListFilter = .all,
        sort: ChatListSort = .updated
    ) -> [IPadChatListProjectGroup] {
        let rows = rows(from: chats, searchText: searchText, filter: filter, sort: sort)
        let grouped = Dictionary(grouping: rows, by: \.projectName)
        return grouped
            .map { project, rows in
                IPadChatListProjectGroup(project: project, rows: rows)
            }
            .sorted { left, right in
                guard let leftFirst = left.rows.first, let rightFirst = right.rows.first else {
                    return left.project < right.project
                }
                return compare(leftFirst, rightFirst)
            }
    }

    static func displayTitle(for chat: CodexChat) -> String {
        let strippedTitle = chat.title.hasPrefix("Codex: ")
            ? String(chat.title.dropFirst("Codex: ".count))
            : chat.title
        let trimmedTitle = strippedTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !isRawCodexIdentifier(trimmedTitle) else {
            return projectName(for: chat)
        }
        return trimmedTitle
    }

    static func projectName(for chat: CodexChat) -> String {
        let rawName: String
        if let projectName = chat.projectName?.trimmingCharacters(in: .whitespacesAndNewlines), !projectName.isEmpty {
            rawName = projectName
        } else {
            let lastPathComponent = URL(fileURLWithPath: chat.repo).lastPathComponent
            rawName = lastPathComponent.isEmpty ? "Unknown Project" : lastPathComponent
        }
        return displayProjectName(rawName)
    }

    private static func displayProjectName(_ value: String) -> String {
        let parts = value.split { character in
            character == "-" || character == "_"
        }
        guard parts.count > 1 else {
            return value
        }
        return parts.map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined(separator: " ")
    }

    private static func row(for chat: CodexChat, sort: ChatListSort) -> IPadChatListRow {
        IPadChatListRow(
            chat: chat,
            displayTitle: displayTitle(for: chat),
            projectName: projectName(for: chat),
            statusTitle: chat.status.title,
            sortDate: sortDate(for: chat, sort: sort),
            isPinned: chat.isPinned == true,
            pinnedOrder: chat.pinnedOrder
        )
    }

    private static func sortDate(for chat: CodexChat, sort: ChatListSort) -> Date {
        switch sort {
        case .updated:
            chat.updatedAt ?? chat.endedAt ?? chat.startedAt
        case .created:
            chat.startedAt
        }
    }

    private static func matches(filter: ChatListFilter, chat: CodexChat) -> Bool {
        switch filter {
        case .all:
            true
        case .running:
            chat.status == .running
        case .waitingForApproval:
            chat.status == .waitingForApproval
        case .failed:
            chat.status == .failed
        case .completed:
            chat.status == .completed
        case .stopped:
            chat.status == .stopped
        case .idle:
            chat.status == .idle
        }
    }

    private static func matches(searchText: String, row: IPadChatListRow) -> Bool {
        let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }

        return row.displayTitle.lowercased().contains(normalized)
            || row.projectName.lowercased().contains(normalized)
            || row.statusTitle.lowercased().contains(normalized)
    }

    private static func compare(_ left: IPadChatListRow, _ right: IPadChatListRow) -> Bool {
        if left.isPinned != right.isPinned {
            return left.isPinned
        }
        if left.isPinned, right.isPinned {
            let leftOrder = left.pinnedOrder ?? Int.max
            let rightOrder = right.pinnedOrder ?? Int.max
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }
        }
        if left.sortDate != right.sortDate {
            return left.sortDate > right.sortDate
        }
        return left.displayTitle < right.displayTitle
    }

    private static func isRawCodexIdentifier(_ value: String) -> Bool {
        if value.lowercased().hasPrefix("codex:") {
            return true
        }
        return UUID(uuidString: value) != nil
    }
}
