import SwiftUI

struct IPadDashboardWorkspaceView: View {
    @Environment(HandrailStore.self) private var store
    @Binding var selection: IPadWorkspaceSelection
    @State private var showsNewChat = false

    init(selection: Binding<IPadWorkspaceSelection> = .constant(IPadWorkspaceSelection())) {
        self._selection = selection
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let machine = store.pairedMachine {
                    machineStatus(machine)
                    summaryGrid
                    activeChatsSection
                    attentionSection
                    recentOutcomesSection
                } else {
                    EmptyState(
                        title: "No machine paired",
                        detail: "Pair Handrail with your Mac from Settings.",
                        systemImage: "macbook.and.iphone"
                    )
                }
            }
            .padding(20)
            .safeAreaPadding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsNewChat = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(store.pairedMachine?.isOnline != true)
                .accessibilityLabel("New chat")
            }
        }
        .sheet(isPresented: $showsNewChat) {
            NavigationStack {
                IPadNewChatPanel()
            }
            .environment(store)
        }
    }

    private func machineStatus(_ machine: PairedMachine) -> some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: machine.isOnline ? "wifi" : "wifi.slash")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(machine.isOnline ? .green : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 6) {
                    Text(machine.machineName)
                        .font(.headline)
                    Text("\(machine.host):\(machine.port)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Commands run on this paired Mac over the local Handrail connection. No cloud execution is used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(store.connectionText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(machine.isOnline ? .green : .secondary)
                    Text(syncText(machine: machine))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var summaryGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                metric("Running", runningChats.count, "play.fill", .green)
                metric("Attention", visibleAttentionChats.count, "exclamationmark.triangle.fill", .orange)
                metric("Failed", failedChats.count, "xmark.octagon.fill", .red)
                metric("Completed Today", completedToday.count, "checkmark.circle.fill", .blue)
            }
        }
    }

    private func metric(_ title: String, _ value: Int, _ icon: String, _ color: Color) -> some View {
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
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var activeChatsSection: some View {
        dashboardSection(title: "Active Chats", emptyTitle: "No active chats", chats: activeChats) { chat in
            activeRow(chat)
        }
    }

    private var attentionSection: some View {
        dashboardSection(title: "Attention Queue", emptyTitle: "No approvals or failures", chats: visibleAttentionChats) { chat in
            chatRow(chat, icon: attentionIcon(for: chat), color: attentionColor(for: chat))
        }
    }

    private var recentOutcomesSection: some View {
        dashboardSection(title: "Recent Outcomes", emptyTitle: "No recent completions or failures", chats: recentOutcomeChats) { chat in
            chatRow(chat, icon: outcomeIcon(for: chat), color: outcomeColor(for: chat))
        }
    }

    private func dashboardSection<Row: View>(
        title: String,
        emptyTitle: String,
        chats: [CodexChat],
        @ViewBuilder row: @escaping (CodexChat) -> Row
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
            if chats.isEmpty {
                Text(emptyTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ForEach(chats.prefix(6)) { chat in
                    row(chat)
                }
            }
        }
    }

    private func activeRow(_ chat: CodexChat) -> some View {
        HStack(spacing: 10) {
            chatRowButton(chat, icon: "play.fill", color: .green)

            if HandrailCommandAvailability.resolve(
                pairedMachine: store.pairedMachine,
                selectedChat: chat,
                selectedApprovalId: selection.selectedApprovalId,
                latestApproval: store.latestApproval
            ).canStopSelectedChat {
                Button {
                    store.stop(chatId: chat.id)
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Stop \(IPadChatListQuery.displayTitle(for: chat))")
            }
        }
    }

    private func chatRow(_ chat: CodexChat, icon: String, color: Color) -> some View {
        chatRowButton(chat, icon: icon, color: color)
    }

    private func chatRowButton(_ chat: CodexChat, icon: String, color: Color) -> some View {
        Button {
            selection.selectChat(id: chat.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(IPadChatListQuery.displayTitle(for: chat))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(IPadChatListQuery.projectName(for: chat))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(status: chat.status)

                Text(HandrailFormatters.relativeAge(since: sortDate(for: chat)))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func syncText(machine: PairedMachine) -> String {
        if store.isRefreshingChats {
            return "Refreshing"
        }
        guard let lastChatRefreshAt = store.lastChatRefreshAt else {
            return machine.isOnline ? "Not synced yet" : "Offline, not synced yet"
        }
        return "Last sync \(HandrailFormatters.time.string(from: lastChatRefreshAt))"
    }

    private var runningChats: [CodexChat] {
        store.chats.filter { $0.status == .running }
    }

    private var failedChats: [CodexChat] {
        store.chats.filter { $0.status == .failed }
    }

    private var activeChats: [CodexChat] {
        sorted(store.chats.filter { $0.status == .running || $0.status == .waitingForApproval })
    }

    private var visibleAttentionChats: [CodexChat] {
        sorted(store.chats.filter { store.needsAttention($0) && !store.isAttentionDismissed(chatId: $0.id) })
            .sorted { left, right in
                if left.status != right.status {
                    return left.status == .waitingForApproval
                }
                return sortDate(for: left) > sortDate(for: right)
            }
    }

    private var completedToday: [CodexChat] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return store.chats.filter { $0.status == .completed && sortDate(for: $0) >= startOfToday }
    }

    private var recentOutcomeChats: [CodexChat] {
        sorted(store.chats.filter { $0.status == .completed || $0.status == .failed })
    }

    private func sorted(_ chats: [CodexChat]) -> [CodexChat] {
        chats.sorted { sortDate(for: $0) > sortDate(for: $1) }
    }

    private func sortDate(for chat: CodexChat) -> Date {
        chat.updatedAt ?? chat.endedAt ?? chat.startedAt
    }

    private func attentionIcon(for chat: CodexChat) -> String {
        chat.status == .failed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    private func attentionColor(for chat: CodexChat) -> Color {
        chat.status == .failed ? .red : .orange
    }

    private func outcomeIcon(for chat: CodexChat) -> String {
        chat.status == .failed ? "xmark.octagon.fill" : "checkmark.circle.fill"
    }

    private func outcomeColor(for chat: CodexChat) -> Color {
        chat.status == .failed ? .red : .blue
    }
}

#Preview {
    NavigationStack {
        IPadDashboardWorkspaceView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
