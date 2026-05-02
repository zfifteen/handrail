import XCTest
@testable import Handrail

@MainActor
final class PairingPersistenceTests: XCTestCase {
    private let pairingStorageKey = "handrail.pairedMachine"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: pairingStorageKey)
        try? KeychainStore.delete(account: "paired-machine-token")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: pairingStorageKey)
        try? KeychainStore.delete(account: "paired-machine-token")
        super.tearDown()
    }

    func testCorruptStoredPairingReportsRepairPath() {
        UserDefaults.standard.set(Data("{".utf8), forKey: pairingStorageKey)

        let store = HandrailStore(enableNetworking: false)

        XCTAssertNil(store.pairedMachine)
        XCTAssertEqual(store.pairingError, "Stored pairing data is corrupt. Reset pairing, then pair Handrail with your Mac again.")
        XCTAssertEqual(store.lastError, "Stored pairing data is corrupt. Reset pairing, then pair Handrail with your Mac again.")
        XCTAssertEqual(store.notifications.first?.title, "Handrail error")
        XCTAssertEqual(store.notifications.first?.detail, "Stored pairing data is corrupt. Reset pairing, then pair Handrail with your Mac again.")
    }

    func testInvalidStoredPairingTypeReportsRepairPath() {
        UserDefaults.standard.set("corrupt", forKey: pairingStorageKey)

        let store = HandrailStore(enableNetworking: false)

        XCTAssertNil(store.pairedMachine)
        XCTAssertEqual(store.pairingError, "Stored pairing data is corrupt. Reset pairing, then pair Handrail with your Mac again.")
        XCTAssertEqual(store.lastError, "Stored pairing data is corrupt. Reset pairing, then pair Handrail with your Mac again.")
    }

    func testStoredPairingMetadataWithoutKeychainTokenReportsRepairPath() throws {
        let metadata = StoredPairingMetadata(
            protocolVersion: 1,
            host: "127.0.0.1",
            port: 8788,
            machineName: "MacBookPro.lan"
        )
        UserDefaults.standard.set(try JSONEncoder().encode(metadata), forKey: pairingStorageKey)

        let store = HandrailStore(enableNetworking: false)

        XCTAssertNil(store.pairedMachine)
        XCTAssertEqual(store.pairingError, "Stored pairing metadata is missing its Keychain token. Reset pairing, then pair Handrail with your Mac again.")
        XCTAssertEqual(store.lastError, "Stored pairing metadata is missing its Keychain token. Reset pairing, then pair Handrail with your Mac again.")
    }

    func testResetPairingClearsCorruptStoredPairing() {
        UserDefaults.standard.set(Data("{".utf8), forKey: pairingStorageKey)
        let store = HandrailStore(enableNetworking: false)

        store.resetPairing()

        XCTAssertNotEqual(UserDefaults.standard.data(forKey: pairingStorageKey), Data("{".utf8))
        XCTAssertNil(store.pairedMachine)
        XCTAssertNil(store.pairingError)
        XCTAssertNil(store.lastError)
    }
}

private struct StoredPairingMetadata: Encodable {
    let protocolVersion: Int
    let host: String
    let port: Int
    let machineName: String
}
