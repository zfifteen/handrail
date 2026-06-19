import XCTest
@testable import Handrail

/// Exercises a real WebSocket handshake from the iOS Simulator to a running `handrail serve` on the Mac host.
/// Skip when HANDRAIL_PAIRING_TOKEN is unset (CI without a live server).
@MainActor
final class LiveServerConnectivityTests: XCTestCase {
    private var store: HandrailStore?

    override func tearDown() {
        store?.resetPairing()
        store = nil
        super.tearDown()
    }

    func testSimulatorConnectsToLiveHandrailServer() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let token = environment["HANDRAIL_PAIRING_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set HANDRAIL_PAIRING_TOKEN to run live simulator connectivity tests.")
        }

        let host = environment["HANDRAIL_HOST"] ?? "127.0.0.1"
        let port = Int(environment["HANDRAIL_PORT"] ?? "8788") ?? 8788

        let store = HandrailStore(loadStoredPairing: false)
        self.store = store
        store.pair(with: PairingPayload(
            protocolVersion: 1,
            host: host,
            port: port,
            token: token,
            machineName: "MacBookPro.lan"
        ))

        try await waitUntil(seconds: 20) {
            store.pairedMachine?.isOnline == true && !store.chats.isEmpty
        }

        XCTAssertEqual(store.connectionText, "Online")
        XCTAssertGreaterThan(store.chats.count, 0)
        XCTAssertTrue(store.chats.allSatisfy { $0.id.hasPrefix("grok:") })
    }

    private func waitUntil(seconds: TimeInterval, condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        XCTFail("Timed out waiting for live Handrail server connectivity from the simulator.")
    }
}