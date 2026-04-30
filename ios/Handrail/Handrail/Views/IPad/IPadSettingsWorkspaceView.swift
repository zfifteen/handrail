import SwiftUI

struct IPadSettingsWorkspaceView: View {
    @Environment(HandrailStore.self) private var store
    @State private var showsScanner = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                machineSection
                pairingSection
                aboutSection
            }
            .padding(20)
            .safeAreaPadding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Settings")
        .sheet(isPresented: $showsScanner) {
            QRScannerView { payload in
                store.pair(with: payload)
                showsScanner = false
            }
        }
    }

    @ViewBuilder
    private var machineSection: some View {
        if let machine = store.pairedMachine {
            Card {
                VStack(alignment: .leading, spacing: 14) {
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
                            Text("Protocol \(machine.protocolVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 16)

                        Text(store.connectionText)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(machine.isOnline ? .green : .secondary)
                    }

                    SyncStatusRow(
                        isRefreshing: store.isRefreshingChats,
                        lastRefreshAt: store.lastChatRefreshAt,
                        isOnline: machine.isOnline,
                        refresh: store.refreshChats
                    )
                }
            }
        } else {
            EmptyState(
                title: "No machine paired",
                detail: "Run handrail pair on your Mac, then scan its QR code from this iPad.",
                systemImage: "macbook.and.iphone"
            )
        }
    }

    private var pairingSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Pair with your Mac", systemImage: "qrcode")
                    .font(.headline)

                Text("Run this on your Mac:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("handrail pair")
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("Handrail connects to your paired Mac on the local network. It does not use a cloud relay.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showsScanner = true
                } label: {
                    Label("Scan QR", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .hoverEffect(.highlight)
            }
        }
    }

    private var aboutSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("About", systemImage: "info.circle")
                    .font(.headline)
                Text("Version 0.1.0")
                    .foregroundStyle(.secondary)
                Text("Works with OpenAI Codex Desktop. Not affiliated with OpenAI.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        IPadSettingsWorkspaceView()
    }
    .environment(PreviewData.store)
    .preferredColorScheme(.dark)
}
