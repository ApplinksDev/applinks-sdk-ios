import XCTest
@testable import AppLinksSDK

final class ClickIdTests: XCTestCase {
    private let clickId = "9b2e4c1a-7f3d-4e8b-a2c6-5d1f0e9b8a7c"

    // MARK: - extract

    func testCkAsTheOnlyQueryParam() {
        XCTAssertEqual(ClickId.extract(from: "https://go.acme.com/promo?ck=\(clickId)"), clickId)
    }

    func testCkAfterOtherParams() {
        XCTAssertEqual(ClickId.extract(from: "com.example.app://products/42?ref=ad&ck=\(clickId)"), clickId)
    }

    func testCkBeforeOtherParams() {
        XCTAssertEqual(ClickId.extract(from: "https://go.acme.com/promo?ck=\(clickId)&ref=ad"), clickId)
    }

    func testCkBeforeAFragment() {
        XCTAssertEqual(ClickId.extract(from: "com.example.app://products/42?ck=\(clickId)#reviews"), clickId)
    }

    func testPathWithSpacesOrAccentedLetters() {
        XCTAssertEqual(ClickId.extract(from: "com.example.app://shop/café crème?ck=\(clickId)"), clickId)
        XCTAssertEqual(ClickId.extract(from: "https://go.acme.com/caf%C3%A9%20cr%C3%A8me?ck=\(clickId)"), clickId)
    }

    func testPercentEncodedReferrerDoesNotMatch() {
        // The encoded "?" and "=" aren't the query's: iOS never sees an encoded
        // referrer, and the server's CK_PARAM doesn't match it either
        XCTAssertNil(ClickId.extract(from: "com.example.app%3A%2F%2Fproducts%2F42%3Fck%3D\(clickId)"))
    }

    func testUppercaseHexIsLowercased() {
        XCTAssertEqual(ClickId.extract(from: "https://go.acme.com/promo?ck=\(clickId.uppercased())"), clickId)
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertEqual(ClickId.extract(from: "  https://go.acme.com/promo?ck=\(clickId)\n"), clickId)
    }

    func testNonUUIDValue() {
        XCTAssertNil(ClickId.extract(from: "https://go.acme.com/promo?ck=abc123"))
        XCTAssertNil(ClickId.extract(from: "https://go.acme.com/promo?ck=\(clickId)0"))
        XCTAssertNil(ClickId.extract(from: "https://go.acme.com/promo?ck=\(clickId)x&ref=ad"))
    }

    func testCkAsASubstringOfAnotherParamName() {
        XCTAssertNil(ClickId.extract(from: "https://go.acme.com/promo?back=\(clickId)"))
        XCTAssertNil(ClickId.extract(from: "https://go.acme.com/promo?ref=ad&back=\(clickId)"))
    }

    func testCkInThePathDoesNotMatch() {
        XCTAssertNil(ClickId.extract(from: "https://go.acme.com/ck=\(clickId)"))
    }

    func testNoCk() {
        XCTAssertNil(ClickId.extract(from: "https://go.acme.com/promo"))
        XCTAssertNil(ClickId.extract(from: "com.example.app://products/42?ref=ad"))
        XCTAssertNil(ClickId.extract(from: ""))
    }

    // MARK: - removingClickId

    func testRemovesAUUIDCk() {
        let params = ClickId.removingClickId(from: ["ref": "ad", "ck": clickId])
        XCTAssertEqual(params, ["ref": "ad"])
    }

    func testRemovesAnUppercaseUUIDCk() {
        XCTAssertEqual(ClickId.removingClickId(from: ["ck": clickId.uppercased()]), [:])
    }

    func testKeepsANonUUIDCk() {
        let params = ["ref": "ad", "ck": "summer-sale"]
        XCTAssertEqual(ClickId.removingClickId(from: params), params)
    }

    func testKeepsParamsWithoutCk() {
        let params = ["ref": "ad", "back": clickId]
        XCTAssertEqual(ClickId.removingClickId(from: params), params)
    }
}
