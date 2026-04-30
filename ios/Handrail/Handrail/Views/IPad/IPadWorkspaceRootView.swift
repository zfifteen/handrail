import SwiftUI

struct IPadWorkspaceRootView: View {
    @Binding var selection: IPadWorkspaceSelection

    init(selection: Binding<IPadWorkspaceSelection> = .constant(IPadWorkspaceSelection())) {
        self._selection = selection
    }

    var body: some View {
        NavigationSplitView {
            IPadSidebarView(selection: $selection)
        } content: {
            placeholderContent
        } detail: {
            placeholderDetail
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var placeholderContent: some View {
        switch selection.selectedSection {
        case .dashboard:
            IPadDashboardWorkspaceView()
        case .chats:
            IPadChatListWorkspaceView(selection: $selection)
        case .attention:
            IPadApprovalReviewWorkspaceView(selection: $selection)
        case .activity:
            ContentUnavailableView("Activity", systemImage: "waveform.path.ecg", description: Text("iPad activity workspace scaffold."))
        case .alerts:
            ContentUnavailableView("Alerts", systemImage: "bell", description: Text("iPad alerts workspace scaffold."))
        case .settings:
            IPadSettingsWorkspaceView()
        }
    }

    @ViewBuilder
    private var placeholderDetail: some View {
        if selection.selectedApprovalId != nil {
            IPadApprovalReviewWorkspaceView(selection: $selection)
        } else if selection.selectedChatId != nil {
            IPadChatDetailWorkspaceView(selection: $selection)
        } else {
            ContentUnavailableView("No Selection", systemImage: "rectangle.split.3x1", description: Text("Select a chat or approval after Phase Three implementation."))
        }
    }
}

#Preview {
    IPadWorkspaceRootView()
        .environment(PreviewData.store)
        .preferredColorScheme(.dark)
}
