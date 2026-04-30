import SwiftUI

struct IPadWorkspaceRootView: View {
    @Binding var selection: IPadWorkspaceSelection
    @Binding var showsNewChat: Bool
    @Binding var focusesChatSearch: Bool

    init(
        selection: Binding<IPadWorkspaceSelection> = .constant(IPadWorkspaceSelection()),
        showsNewChat: Binding<Bool> = .constant(false),
        focusesChatSearch: Binding<Bool> = .constant(false)
    ) {
        self._selection = selection
        self._showsNewChat = showsNewChat
        self._focusesChatSearch = focusesChatSearch
    }

    var body: some View {
        if usesWideWorkspace {
            NavigationSplitView {
                sidebar
            } detail: {
                wideWorkspace
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationSplitView {
                sidebar
            } content: {
                columnWorkspace
            } detail: {
                detailWorkspace
            }
            .navigationSplitViewStyle(.balanced)
        }
    }

    private var usesWideWorkspace: Bool {
        switch selection.selectedSection {
        case .dashboard, .activity, .alerts, .settings:
            true
        case .chats, .attention:
            false
        }
    }

    private var sidebar: some View {
        IPadSidebarView(selection: $selection)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
    }

    @ViewBuilder
    private var wideWorkspace: some View {
        switch selection.selectedSection {
        case .dashboard:
            IPadDashboardWorkspaceView(selection: $selection, showsNewChat: $showsNewChat)
        case .activity:
            IPadActivityWorkspaceView(selection: $selection)
        case .alerts:
            ContentUnavailableView("Alerts", systemImage: "bell", description: Text("Alerts from the paired Mac will appear here."))
        case .settings:
            IPadSettingsWorkspaceView()
        case .chats, .attention:
            EmptyView()
        }
    }

    @ViewBuilder
    private var columnWorkspace: some View {
        switch selection.selectedSection {
        case .dashboard:
            IPadDashboardWorkspaceView(selection: $selection, showsNewChat: $showsNewChat)
                .navigationSplitViewColumnWidth(min: 420, ideal: 480, max: 560)
        case .chats:
            IPadChatListWorkspaceView(selection: $selection, focusesSearch: $focusesChatSearch)
                .navigationSplitViewColumnWidth(min: 420, ideal: 480, max: 560)
        case .attention:
            IPadApprovalReviewWorkspaceView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 420, ideal: 480, max: 560)
        case .activity:
            IPadActivityWorkspaceView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 420, ideal: 480, max: 560)
        case .alerts:
            ContentUnavailableView("Alerts", systemImage: "bell", description: Text("iPad alerts workspace scaffold."))
        case .settings:
            IPadSettingsWorkspaceView()
        }
    }

    @ViewBuilder
    private var detailWorkspace: some View {
        if selection.selectedApprovalId != nil {
            IPadApprovalReviewWorkspaceView(selection: $selection)
        } else if selection.selectedChatId != nil {
            IPadChatDetailWorkspaceView(selection: $selection)
        } else {
            ContentUnavailableView("No Selection", systemImage: "rectangle.split.3x1", description: Text("Select a chat or approval to inspect it here."))
        }
    }
}

#Preview {
    IPadWorkspaceRootView()
        .environment(PreviewData.store)
        .preferredColorScheme(.dark)
}
