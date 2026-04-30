import SwiftUI

struct IPadDashboardWorkspaceView: View {
    var body: some View {
        ContentUnavailableView("iPad Dashboard", systemImage: "gauge.with.dots.needle.67percent", description: Text("Dashboard workspace scaffold."))
            .navigationTitle("Dashboard")
    }
}

#Preview {
    NavigationStack {
        IPadDashboardWorkspaceView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
