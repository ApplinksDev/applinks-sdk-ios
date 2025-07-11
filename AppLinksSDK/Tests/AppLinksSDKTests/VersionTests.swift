import XCTest
@testable import AppLinksSDK

final class VersionTests: XCTestCase {
    
    func testVersionConstants() {
        // Test that version constants are accessible
        XCTAssertEqual(AppLinksSDKVersion.current, "1.0.0")
        XCTAssertEqual(AppLinksSDKVersion.name, "AppLinksSDK")
        XCTAssertEqual(AppLinksSDKVersion.fullName, "AppLinksSDK/1.0.0")
    }
    
    func testUserAgentFormat() {
        // Test that user agent is properly formatted
        let userAgent = AppLinksSDKVersion.userAgent
        XCTAssertTrue(userAgent.hasPrefix("AppLinksSDK/1.0.0"))
        XCTAssertTrue(userAgent.contains("iOS/"))
    }
    
    func testVersionDictionary() {
        // Test version dictionary contains required keys
        let dict = AppLinksSDKVersion.asDictionary
        XCTAssertEqual(dict["name"], "AppLinksSDK")
        XCTAssertEqual(dict["version"], "1.0.0")
        XCTAssertEqual(dict["platform"], "iOS")
        XCTAssertNotNil(dict["platformVersion"])
    }
    
    func testSDKVersionAccess() {
        // Test that SDK provides version access
        XCTAssertEqual(AppLinksSDK.version, "1.0.0")
        
        let versionInfo = AppLinksSDK.versionInfo
        XCTAssertEqual(versionInfo["name"], "AppLinksSDK")
        XCTAssertEqual(versionInfo["version"], "1.0.0")
    }
}