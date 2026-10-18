import MenuBarKit
import XCTest
@testable import ClaudePulse

final class SmokeTests: XCTestCase {
    func testAppVersionLabelNotEmpty() {
        XCTAssertFalse(AppVersion.label().isEmpty)
    }
}
