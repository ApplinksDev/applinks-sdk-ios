import XCTest
@testable import AppLinksSDK

final class AdvertisingIdTests: XCTestCase {
    func testAnIDFA() {
        XCTAssertEqual(AdvertisingId.parse("E621E1F8-C36C-495A-93FC-0C247A3E6E5F"), .id("E621E1F8-C36C-495A-93FC-0C247A3E6E5F"))
        XCTAssertEqual(AdvertisingId.parse(" e621e1f8-c36c-495a-93fc-0c247a3e6e5f\n"), .id("e621e1f8-c36c-495a-93fc-0c247a3e6e5f"))
    }

    func testNone() {
        XCTAssertEqual(AdvertisingId.parse(nil), .none)
        XCTAssertEqual(AdvertisingId.parse(""), .none)
        XCTAssertEqual(AdvertisingId.parse("  "), .none)
        XCTAssertEqual(AdvertisingId.parse("00000000-0000-0000-0000-000000000000"), .none)
    }

    func testNotAnIDFA() {
        for value in [
            "unavailable",
            "Optional(E621E1F8-C36C-495A-93FC-0C247A3E6E5F)",
            "{E621E1F8-C36C-495A-93FC-0C247A3E6E5F}",
            "E621E1F8C36C495A93FC0C247A3E6E5F",
            "E621E1F8-C36C-495A-93FC-0C247A3E6E5G",
            "E621E1F8-C36C-495A-93FC-0C247A3E6E5F0"
        ] {
            XCTAssertEqual(AdvertisingId.parse(value), .invalid, value)
        }
    }
}
