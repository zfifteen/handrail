import SwiftUI

struct DashboardMenuSnapshot: Equatable {
    let shortcuts: [DashboardMenuShortcut]
    let pinnedRows: [DashboardMenuChatRow]
    let allChatRows: [DashboardMenuChatRow]
}

enum DashboardMenuShortcut: String, CaseIterable, Equatable {
    case newChat
    case search
    case plugins
    case automations

    var title: String {
        switch self {
        case .newChat: "New chat"
        case .search: "Search"
        case .plugins: "Plugins"
        case .automations: "Automations"
        }
    }

    var systemImage: String {
        switch self {
        case .newChat: "square.and.pencil"
        case .search: "magnifyingglass"
        case .plugins: "puzzlepiece.extension"
        case .automations: "clock"
        }
    }

    var isEnabled: Bool {
        self == .newChat || self == .automations
    }
}

struct DashboardMenuChatRow: Identifiable, Equatable {
    let chat: CodexChat
    let displayTitle: String
    let projectName: String
    let timeText: String
    let leadingSystemImage: String
    let showsRunningIndicator: Bool
    let showsAutomationIndicator: Bool

    var id: String { chat.id }
}

enum DashboardMenuQuery {
    static func snapshot(from chats: [CodexChat], now: Date = Date()) -> DashboardMenuSnapshot {
        DashboardMenuSnapshot(
            shortcuts: DashboardMenuShortcut.allCases,
            pinnedRows: pinnedRows(from: chats, now: now),
            allChatRows: allChatRows(from: chats, now: now)
        )
    }

    private static func pinnedRows(from chats: [CodexChat], now: Date) -> [DashboardMenuChatRow] {
        chats
            .filter { $0.isPinned == true }
            .sorted { left, right in
                let leftOrder = left.pinnedOrder ?? Int.max
                let rightOrder = right.pinnedOrder ?? Int.max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return sortDate(for: left) > sortDate(for: right)
            }
            .map { row(for: $0, now: now, leadingSystemImage: "pin.fill") }
    }

    private static func allChatRows(from chats: [CodexChat], now: Date) -> [DashboardMenuChatRow] {
        chats
            .filter { $0.isPinned != true }
            .sorted { sortDate(for: $0) > sortDate(for: $1) }
            .map { row(for: $0, now: now, leadingSystemImage: "message.fill") }
    }

    private static func row(for chat: CodexChat, now: Date, leadingSystemImage: String) -> DashboardMenuChatRow {
        DashboardMenuChatRow(
            chat: chat,
            displayTitle: IPadChatListQuery.displayTitle(for: chat),
            projectName: IPadChatListQuery.projectName(for: chat),
            timeText: HandrailFormatters.relativeAge(since: sortDate(for: chat), to: now),
            leadingSystemImage: leadingSystemImage,
            showsRunningIndicator: chat.status == .running || chat.status == .waitingForApproval,
            showsAutomationIndicator: chat.isAutomationTarget == true
        )
    }

    private static func sortDate(for chat: CodexChat) -> Date {
        chat.updatedAt ?? chat.endedAt ?? chat.startedAt
    }
}

struct DashboardView: View {
    @Environment(HandrailStore.self) private var store
    @State private var showsScanner = false
    @State private var showsStart = false
    @State private var showsAutomations = false
    let navigateToChat: (String) -> Void

    init(navigateToChat: @escaping (String) -> Void = { _ in }) {
        self.navigateToChat = navigateToChat
    }

    private var dashboardSnapshot: DashboardMenuSnapshot {
        DashboardMenuQuery.snapshot(from: store.chats)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let machine = store.pairedMachine {
                    machineStatus(machine)
                    SyncStatusRow(
                        isRefreshing: store.isRefreshingChats,
                        lastRefreshAt: store.lastChatRefreshAt,
                        isOnline: machine.isOnline,
                        refresh: store.refreshChats
                    )
                    shortcutSection
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
            store.refreshChats()
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
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
            ChatDetailView(chatId: id)
        }
        .navigationDestination(isPresented: $showsAutomations) {
            AutomationsView()
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
        .onChange(of: store.lastStartedChatId) { _, chatId in
            if chatId != nil {
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

    private var shortcutSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
            ForEach(dashboardSnapshot.shortcuts, id: \.rawValue) { shortcut in
                shortcutButton(shortcut)
            }
        }
    }

    private func shortcutButton(_ shortcut: DashboardMenuShortcut) -> some View {
        Button {
            switch shortcut {
            case .newChat:
                showsStart = true
            case .automations:
                showsAutomations = true
            case .search, .plugins:
                break
            }
        } label: {
            Label(shortcut.title, systemImage: shortcut.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(shortcut.isEnabled ? .primary : .secondary)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled((shortcut == .newChat && store.pairedMachine?.isOnline != true) || !shortcut.isEnabled)
        .accessibilityLabel(shortcut.title)
    }

    private var pinnedChatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Pinned")
            if dashboardSnapshot.pinnedRows.isEmpty {
                quietRow("No pinned chats")
            } else {
                ForEach(dashboardSnapshot.pinnedRows.prefix(5)) { row in
                    dashboardRow(row)
                }
            }
        }
    }

    private var allChatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("All chats")
            if dashboardSnapshot.allChatRows.isEmpty {
                quietRow("No Codex chats found")
            } else {
                ForEach(dashboardSnapshot.allChatRows.prefix(5)) { row in
                    dashboardRow(row)
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

    private func dashboardRow(_ row: DashboardMenuChatRow) -> some View {
        NavigationLink(value: row.id) {
            HStack(spacing: 12) {
                Image(systemName: row.leadingSystemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(rowIconColor(for: row))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.displayTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(row.projectName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if row.showsAutomationIndicator {
                    Image(systemName: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Automation target")
                }

                if row.showsRunningIndicator {
                    TimelineView(.animation) { timeline in
                        let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .rotationEffect(.degrees(phase * 360))
                    }
                    .frame(width: 18, height: 18)
                    .accessibilityLabel("Running")
                }

                Text(row.timeText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 34, alignment: .trailing)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func rowIconColor(for row: DashboardMenuChatRow) -> Color {
        row.leadingSystemImage == "pin.fill" ? .secondary : .purple
    }
}

struct AutomationsView: View {
    @Environment(HandrailStore.self) private var store

    private var currentAutomations: [AutomationRecord] {
        store.automations
            .filter { $0.status == .active }
            .sorted { left, right in
                if left.kind != right.kind {
                    return left.kind == "cron"
                }
                return false
            }
    }

    private var pausedAutomations: [AutomationRecord] {
        store.automations.filter { $0.status == .paused }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                automationSection(title: "Current", automations: currentAutomations)
                automationSection(title: "Paused", automations: pausedAutomations)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .safeAreaPadding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Automations")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            store.refreshChats()
        }
    }

    private func automationSection(title: String, automations: [AutomationRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 18)

            sectionDivider

            if automations.isEmpty {
                Text("No \(title.lowercased()) automations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            } else {
                ForEach(automations) { automation in
                    automationRow(automation)
                }
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    private func automationRow(_ automation: AutomationRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon(for: automation))
                .font(.title3.weight(.regular))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            HStack(spacing: 8) {
                Text(automation.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(automation.contextText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(automation.scheduleText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(automation.name), \(automation.contextText), \(automation.scheduleText)")
    }

    private func icon(for automation: AutomationRecord) -> String {
        automation.status == .active ? "circle" : "pause.circle"
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}

#Preview("Automations") {
    NavigationStack {
        AutomationsView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
