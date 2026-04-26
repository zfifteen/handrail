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
}
