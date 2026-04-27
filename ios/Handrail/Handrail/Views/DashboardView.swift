import SwiftUI

struct DashboardView: View {
    @Environment(HandrailStore.self) private var store
    @State private var showsScanner = false
    @State private var showsStart = false
    let navigateToSession: (String) -> Void

    init(navigateToSession: @escaping (String) -> Void = { _ in }) {
        self.navigateToSession = navigateToSession
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let machine = store.pairedMachine {
                    machineStatus(machine)
                    SyncStatusRow(
                        isRefreshing: store.isRefreshingSessions,
                        lastRefreshAt: store.lastSessionRefreshAt,
                        isOnline: machine.isOnline,
                        reconnect: store.reconnect
                    )
                    todaySummary
                    attentionSection
                    sectionDivider
                    runningNowSection
                    sectionDivider
                    pinnedChatsSection
                    sectionDivider
                    allChatsSection
                    sectionDivider
                } else {
                    Card {
                        EmptyState(
                            title: "No machine paired",
                            detail: "Run handrail pair on your Mac, then scan the QR code here.",
                            systemImage: "qrcode.viewfinder"
                        )
                        Button {
                            showsScanner = true
                        } label: {
                            Label("Scan Pairing QR", systemImage: "camera.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .safeAreaPadding(.bottom, 96)
        }
        .background(Color.black.ignoresSafeArea())
        .refreshable {
            store.refreshSessions()
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showsStart = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(store.pairedMachine?.isOnline != true)
                .accessibilityLabel("New chat")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
                .accessibilityLabel("Pair machine")
            }
        }
        .navigationDestination(for: String.self) { id in
            SessionDetailView(sessionId: id)
        }
        .sheet(isPresented: $showsScanner) {
            QRScannerView { payload in
                store.pair(with: payload)
                showsScanner = false
            }
        }
        .sheet(isPresented: $showsStart) {
            NewChatView()
        }
        .onChange(of: store.lastStartedSessionId) { _, sessionId in
            if sessionId != nil {
                showsStart = false
            }
        }
    }

    private func machineStatus(_ machine: PairedMachine) -> some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: machine.isOnline ? "wifi" : "wifi.slash")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(machine.isOnline ? .green : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(machine.machineName)
                        .font(.headline)
                    Text("\(machine.host):\(machine.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(store.connectionText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(machine.isOnline ? .green : .secondary)
            }
        }
    }

    private var todaySummary: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Today", systemImage: "sun.max.fill")
                        .font(.headline)
                    Spacer()
                    Text(HandrailFormatters.time.string(from: Date()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    metric("Running", activeSessions.count, .green, "play.fill")
                    metric("Needs attention", visibleAttentionSessions.count, .orange, "exclamationmark.triangle.fill")
                    metric("Done", completedToday.count, .blue, "checkmark.circle.fill")
                }
            }
        }
    }

    private func metric(_ title: String, _ value: Int, _ color: Color, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Needs attention")
            if visibleAttentionSessions.isEmpty {
                quietRow("No approvals or failures")
            } else {
                ForEach(visibleAttentionSessions.prefix(3)) { session in
                    dashboardRow(session, icon: attentionIcon(for: session), color: attentionColor(for: session))
                        .contextMenu {
                            Button {
                                store.dismissAttention(sessionId: session.id)
                            } label: {
                                Label("Dismiss", systemImage: "xmark.circle")
                            }
                        }
                }
            }
        }
    }

    private var runningNowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Running now")
            if activeSessions.isEmpty {
                quietRow("No running Codex chats")
            } else {
                ForEach(activeSessions.prefix(3)) { session in
                    dashboardRow(session, icon: "play.fill", color: .green)
                }
            }
        }
    }

    private var pinnedChatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Pinned")
            if pinnedChats.isEmpty {
                quietRow("No pinned chats")
            } else {
                ForEach(pinnedChats.prefix(5)) { session in
                    dashboardRow(session, icon: "pin.fill", color: .secondary)
                }
            }
        }
    }

    private var allChatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("All chats")
            if allChats.isEmpty {
                quietRow("No Codex chats found")
            } else {
                ForEach(allChats.prefix(5)) { session in
                    dashboardRow(session, icon: "message.fill", color: .purple)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.82))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private func quietRow(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
    }

    private func dashboardRow(_ session: HandrailSession, icon: String, color: Color) -> some View {
        NavigationLink(value: session.id) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle(for: session))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(projectName(for: session))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(HandrailFormatters.relativeAge(since: sortDate(for: session)))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var activeSessions: [HandrailSession] {
        sorted(store.sessions.filter {
            $0.source != "handrail" && ($0.status == .running || $0.status == .waitingForApproval)
        })
    }

    private var attentionSessions: [HandrailSession] {
        sorted(store.sessions.filter { $0.source != "handrail" && store.needsAttention($0) })
    }

    private var visibleAttentionSessions: [HandrailSession] {
        attentionSessions.filter { !store.isAttentionDismissed(sessionId: $0.id) }
    }

    private var completedToday: [HandrailSession] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return store.sessions.filter {
            $0.source != "handrail" && $0.status == .completed && sortDate(for: $0) >= startOfToday
        }
    }

    private var pinnedChats: [HandrailSession] {
        store.sessions
            .filter { $0.source != "handrail" && store.isPinned(sessionId: $0.id) }
            .sorted {
                let leftOrder = $0.pinnedOrder ?? Int.max
                let rightOrder = $1.pinnedOrder ?? Int.max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return sortDate(for: $0) > sortDate(for: $1)
            }
    }

    private var allChats: [HandrailSession] {
        sorted(store.sessions.filter { $0.source != "handrail" && !store.isPinned(sessionId: $0.id) })
    }

    private func sorted(_ sessions: [HandrailSession]) -> [HandrailSession] {
        sessions.sorted { sortDate(for: $0) > sortDate(for: $1) }
    }

    private func displayTitle(for session: HandrailSession) -> String {
        if session.title.hasPrefix("Codex: ") {
            return String(session.title.dropFirst("Codex: ".count))
        }
        return session.title
    }

    private func projectName(for session: HandrailSession) -> String {
        URL(fileURLWithPath: session.repo).lastPathComponent
    }

    private func sortDate(for session: HandrailSession) -> Date {
        session.updatedAt ?? session.endedAt ?? session.startedAt
    }

    private func attentionIcon(for session: HandrailSession) -> String {
        session.status == .failed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    private func attentionColor(for session: HandrailSession) -> Color {
        session.status == .failed ? .red : .orange
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
