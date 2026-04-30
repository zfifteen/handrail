import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct StatusBadge: View {
    let status: ChatStatus

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(status.title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var color: Color {
        switch status {
        case .running: .green
        case .waitingForApproval: .purple
        case .completed: .blue
        case .failed: .red
        case .stopped: .orange
        case .idle: .secondary
        }
    }

    private var icon: String {
        switch status {
        case .running: "play.fill"
        case .waitingForApproval: "exclamationmark.triangle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .stopped: "stop.fill"
        case .idle: "pause.circle"
        }
    }
}

struct EmptyState: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.purple)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct SyncStatusRow: View {
    let isRefreshing: Bool
    let lastRefreshAt: Date?
    let isOnline: Bool
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isRefreshing ? .purple : iconColor)
            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button(isOnline ? "Refresh" : "Reconnect") {
                refresh()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(.purple)
        }
        .accessibilityLabel(statusText)
    }

    private var statusText: String {
        if isRefreshing {
            return "Refreshing from Mac..."
        }
        if !isOnline {
            guard let lastRefreshAt else {
                return "Offline. Not synced yet"
            }
            return "Offline. Last synced \(HandrailFormatters.time.string(from: lastRefreshAt))"
        }
        guard let lastRefreshAt else {
            return "Not synced yet"
        }
        if Date().timeIntervalSince(lastRefreshAt) < 60 {
            return "Synced just now"
        }
        return "Last synced \(HandrailFormatters.time.string(from: lastRefreshAt))"
    }

    private var icon: String {
        if isRefreshing {
            return "arrow.triangle.2.circlepath"
        }
        return isOnline ? "checkmark.circle" : "wifi.slash"
    }

    private var iconColor: Color {
        isOnline ? .secondary : .orange
    }
}
