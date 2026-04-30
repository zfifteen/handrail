import SwiftUI

struct IPadSettingsWorkspaceView: View {
    var body: some View {
        ContentUnavailableView("iPad Settings", systemImage: "gearshape", description: Text("Settings workspace scaffold."))
            .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        IPadSettingsWorkspaceView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
