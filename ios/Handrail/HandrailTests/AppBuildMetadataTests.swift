import XCTest
@testable import Handrail

final class AppBuildMetadataTests: XCTestCase {
    func testAboutTextUsesVersionAndLastUpdatedValues() {
        let metadata = AppBuildMetadata(
            version: "0.1.1",
            lastUpdated: "May 9, 2026 at 10:05 PM"
        )

        XCTAssertEqual(metadata.versionText, "Version 0.1.1")
        XCTAssertEqual(metadata.lastUpdatedText, "Last updated May 9, 2026 at 10:05 PM")
    }
}
