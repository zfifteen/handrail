import Foundation

enum HandrailFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    static func duration(from start: Date, to end: Date? = nil) -> String {
        let totalSeconds = max(0, Int((end ?? Date()).timeIntervalSince(start)))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    static func relativeAge(since date: Date, to end: Date = Date()) -> String {
        let totalSeconds = max(0, Int(end.timeIntervalSince(date)))
        let days = totalSeconds / 86_400
        let hours = totalSeconds / 3_600
        let minutes = totalSeconds / 60

        if days > 0 {
            return "\(days)d"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "now"
    }

    static let assistantTitlePrefixes = ["Grok: ", "Codex: "]

    static func strippedAssistantTitle(_ title: String) -> String {
        for prefix in assistantTitlePrefixes where title.hasPrefix(prefix) {
            return String(title.dropFirst(prefix.count))
        }
        return title
    }

    static func isRawGrokChatIdentifier(_ value: String) -> Bool {
        let lowered = value.lowercased()
        let candidate: String
        if lowered.hasPrefix("grok:") {
            candidate = String(value.dropFirst("grok:".count))
        } else if lowered.hasPrefix("codex:") {
            candidate = String(value.dropFirst("codex:".count))
        } else {
            candidate = value
        }
        return candidate.range(
            of: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
