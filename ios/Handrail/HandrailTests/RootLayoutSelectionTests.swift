import XCTest
import SwiftUI
import UIKit
@testable import Handrail

final class RootLayoutSelectionTests: XCTestCase {
    func testCompactRootSelectionUsesPhoneRoot() {
        XCTAssertEqual(
            HandrailRootLayoutResolver.mode(userInterfaceIdiom: .pad, horizontalSizeClass: .compact),
            .phone
        )
        XCTAssertEqual(
            HandrailRootLayoutResolver.mode(userInterfaceIdiom: .phone, horizontalSizeClass: .regular),
            .phone
        )
    }

    func testRegularWidthIPadRootSelectionUsesIPadWorkspace() {
        XCTAssertEqual(
            HandrailRootLayoutResolver.mode(userInterfaceIdiom: .pad, horizontalSizeClass: .regular),
            .iPadRegular
        )
    }
}
