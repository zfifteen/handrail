import SwiftUI

struct IPadSidebarView: View {
    @Binding var selection: IPadWorkspaceSelection

    var body: some View {
        List {
            ForEach(HandrailSection.allCases) { section in
                Button {
                    selection.selectedSection = section
                } label: {
                    Label(section.title, systemImage: systemImage(for: section))
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Handrail")
    }

    private func systemImage(for section: HandrailSection) -> String {
        switch section {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .chats: "rectangle.stack"
        case .attention: "exclamationmark.triangle"
        case .activity: "waveform.path.ecg"
        case .alerts: "bell"
        case .settings: "gearshape"
        }
    }
}

#Preview {
    NavigationStack {
        IPadSidebarView(selection: .constant(IPadWorkspaceSelection()))
    }
    .preferredColorScheme(.dark)
}
