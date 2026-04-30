import SwiftUI

struct IPadApprovalReviewWorkspaceView: View {
    @Binding var selection: IPadWorkspaceSelection

    var body: some View {
        ContentUnavailableView("iPad Approval Review", systemImage: "checkmark.seal", description: Text("Approval review workspace scaffold."))
            .navigationTitle("Attention")
    }
}

#Preview {
    NavigationStack {
        IPadApprovalReviewWorkspaceView(selection: .constant(IPadWorkspaceSelection(selectedSection: .attention, selectedApprovalId: "approval")))
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
