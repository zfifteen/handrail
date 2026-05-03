import XCTest
@testable import Handrail

final class PairedMachineFormattingTests: XCTestCase {
    func testAddressUsesLiteralPortDigits() {
        let machine = PairedMachine(
            protocolVersion: 1,
            host: "127.0.0.1",
            port: 8788,
            token: "token",
            machineName: "MacBookPro.lan",
            isOnline: true
        )

        XCTAssertEqual(machine.address, "127.0.0.1:8788")
        XCTAssertFalse(machine.address.contains(","))
    }
}
