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
    let leadingSystemImage: String?
    let showsRunningIndicator: Bool
    let showsAutomationIndicator: Bool
    let hasUnreadTurn: Bool

    var id: String { chat.id }
    var pinActionTitle: String { chat.isPinned == true ? "Unpin chat" : "Pin chat" }
    var readActionTitle: String { hasUnreadTurn ? "Mark as read" : "Mark as unread" }
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
            .map { row(for: $0, now: now, leadingSystemImage: nil) }
    }

    private static func row(for chat: CodexChat, now: Date, leadingSystemImage: String?) -> DashboardMenuChatRow {
        DashboardMenuChatRow(
            chat: chat,
            displayTitle: IPadChatListQuery.displayTitle(for: chat),
            projectName: IPadChatListQuery.projectName(for: chat),
            timeText: HandrailFormatters.relativeAge(since: sortDate(for: chat), to: now),
            leadingSystemImage: leadingSystemImage,
            showsRunningIndicator: chat.status == .running,
            showsAutomationIndicator: chat.isAutomationTarget == true,
            hasUnreadTurn: chat.hasUnreadTurn == true
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
    @State private var renamedRow: DashboardMenuChatRow?
    @State private var renamedTitle = ""
    let navigateToChat: (String) -> Void

    init(navigateToChat: @escaping (String) -> Void = { _ in }) {
        self.navigateToChat = navigateToChat
    }

    private var dashboardSnapshot: DashboardMenuSnapshot {
        DashboardMenuQuery.snapshot(from: store.chats)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    dashboardHeader

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
                .safeAreaPadding(.bottom, PhoneTabBarMetrics.contentBottomInset)
            }
            .refreshable {
                store.refreshChats()
            }
            .frame(
                width: proxy.size.width,
                height: max(0, proxy.size.height - PhoneTabBarMetrics.contentBottomInset),
                alignment: .top
            )
            .clipped()
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
        .alert("Rename chat", isPresented: Binding(
            get: { renamedRow != nil },
            set: { isPresented in
                if !isPresented {
                    renamedRow = nil
                    renamedTitle = ""
                }
            }
        )) {
            TextField("Name", text: $renamedTitle)
            Button("Cancel", role: .cancel) {
                renamedRow = nil
                renamedTitle = ""
            }
            Button("Rename") {
                if let renamedRow {
                    store.renameChat(chatId: renamedRow.id, title: renamedTitle)
                }
                renamedRow = nil
                renamedTitle = ""
            }
        }
        .onChange(of: store.lastStartedChatId) { _, chatId in
            if chatId != nil {
                showsStart = false
            }
        }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 12) {
            Button {
                showsStart = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .disabled(store.pairedMachine?.isOnline != true)
            .accessibilityLabel("New Chat")

            Text("Dashboard")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showsScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Scan QR Code")
        }
        .foregroundStyle(.primary)
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
                rowLeadingIndicator(row)

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
        .contextMenu {
            chatActionMenu(for: row)
        }
    }

    @ViewBuilder
    private func rowLeadingIndicator(_ row: DashboardMenuChatRow) -> some View {
        if let leadingSystemImage = row.leadingSystemImage {
            Image(systemName: leadingSystemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)
        } else {
            Circle()
                .fill(row.hasUnreadTurn ? Color.blue : Color.clear)
                .frame(width: 11, height: 11)
                .frame(width: 24)
                .accessibilityLabel(row.hasUnreadTurn ? "Unread" : "Read")
        }
    }

    @ViewBuilder
    private func chatActionMenu(for row: DashboardMenuChatRow) -> some View {
        Button {
            store.togglePin(chatId: row.id)
        } label: {
            Label(row.pinActionTitle, systemImage: "pin")
        }

        Button {
            renamedRow = row
            renamedTitle = row.displayTitle
        } label: {
            Label("Rename chat", systemImage: "pencil")
        }

        Button {
            store.archiveChat(chatId: row.id)
        } label: {
            Label("Archive chat", systemImage: "archivebox")
        }

        Button {
            store.setChatReadState(chatId: row.id, isRead: row.hasUnreadTurn)
        } label: {
            Label(
                row.readActionTitle,
                systemImage: row.hasUnreadTurn ? "envelope.open" : "envelope.badge"
            )
        }
    }
}

struct AutomationsView: View {
    @Environment(HandrailStore.self) private var store
    @State private var editedAutomation: AutomationRecord?

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
        .navigationDestination(item: $editedAutomation) { automation in
            AutomationConfigurationView(automation: automation)
        }
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
        .contextMenu {
            automationActionMenu(for: automation)
        }
    }

    @ViewBuilder
    private func automationActionMenu(for automation: AutomationRecord) -> some View {
        Button {
            store.runAutomationNow(id: automation.id)
        } label: {
            Label("Run now", systemImage: "play")
        }

        Button {
            editedAutomation = automation
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            store.pauseAutomation(id: automation.id)
        } label: {
            Label("Pause", systemImage: "pause.circle")
        }
        .disabled(automation.status == .paused)

        Button(role: .destructive) {
            store.deleteAutomation(id: automation.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func icon(for automation: AutomationRecord) -> String {
        automation.status == .active ? "circle" : "pause.circle"
    }
}

private struct AutomationConfigurationView: View {
    let automation: AutomationRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Status")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    optionRow("Status", value: statusTitle, badgeColor: automation.status == .active ? .green : .secondary)
                }

                VStack(alignment: .leading, spacing: 24) {
                    Text("Details")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    optionRow("Runs in", value: runsInTitle)
                    optionRow("Project", value: projectTitle)
                    optionRow("Repeats", value: repeatsTitle)
                    optionRow("Model", value: automation.model ?? "Not set")
                    optionRow("Reasoning", value: reasoningTitle)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Prompt")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(automation.prompt)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .safeAreaPadding(.bottom, 120)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(automation.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusTitle: String {
        automation.status == .active ? "Active" : "Paused"
    }

    private var runsInTitle: String {
        titleCase(automation.executionEnvironment ?? automation.kind)
    }

    private var projectTitle: String {
        automation.projectName ?? automation.contextText
    }

    private var repeatsTitle: String {
        automation.status == .paused ? scheduleTitle(from: automation.rrule) : automation.scheduleText
    }

    private var reasoningTitle: String {
        guard let reasoningEffort = automation.reasoningEffort else {
            return "Not set"
        }
        return titleCase(reasoningEffort)
    }

    private func optionRow(_ title: String, value: String, badgeColor: Color? = nil) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 24)

            HStack(spacing: 10) {
                if let badgeColor {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 12, height: 12)
                }
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
    }

    private func scheduleTitle(from rrule: String) -> String {
        let normalized = rrule.replacingOccurrences(of: "RRULE:", with: "")
        let fields = Dictionary(uniqueKeysWithValues: normalized.split(separator: ";").compactMap { field -> (String, String)? in
            let parts = field.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), String(parts[1]))
        })
        let frequency = fields["FREQ"] ?? "scheduled"
        let interval = Int(fields["INTERVAL"] ?? "1") ?? 1
        switch frequency {
        case "HOURLY":
            return interval == 1 ? "Hourly" : "Every \(interval)h"
        case "MINUTELY":
            return "Every \(interval)m"
        case "WEEKLY":
            return "Weekly"
        default:
            return titleCase(frequency)
        }
    }

    private func titleCase(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { part in
                let lowercased = part.lowercased()
                return lowercased.prefix(1).uppercased() + String(lowercased.dropFirst())
            }
            .joined(separator: " ")
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
