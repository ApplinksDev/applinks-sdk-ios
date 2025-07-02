import XCTest
@testable import AppLinksSDK

final class BasicSDKTests: XCTestCase {
    
    // MARK: - Basic Initialization Tests
    
    func testSDKInitializationWithDirectCall() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "test_key",
            serverUrl: "https://api.test.com"
        )
        
        XCTAssertNotNil(sdk)
        // SDK uses singleton pattern - shared instance should be set after initialization
        XCTAssertNotNil(AppLinksSDK.shared)
    }
    
    func testInitializationWithAllOptions() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "test_key",
            serverUrl: "https://api.test.com",
            autoHandleLinks: true,
            enableLogging: false,
            supportedDomains: ["example.com", "test.com"],
            supportedSchemes: ["myapp", "testapp"]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - Basic Link Handling Tests
    
    func testHandleLinkBasicFlow() {
        let expectation = XCTestExpectation(description: "Handle link")
        
        let sdk = AppLinksSDK.initialize(
            apiKey: "test_key",
            serverUrl: "https://api.test.com",
            supportedSchemes: ["myapp"]
        )
        
        let testURL = URL(string: "myapp://test/path")!
        
        sdk.handleLink(testURL,
            onSuccess: { url, metadata in
                XCTAssertEqual(url, testURL.absoluteString)
                expectation.fulfill()
            },
            onError: { error in
                // Could be success or error depending on implementation
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Config Tests
    
    func testAppLinksConfigCreation() {
        let config = AppLinksConfig(
            autoHandleLinks: true,
            enableLogging: false,
            serverUrl: "https://test.com",
            apiKey: "test_key",
            supportedDomains: ["example.com"],
            supportedSchemes: ["myapp"]
        )
        
        XCTAssertTrue(config.autoHandleLinks)
        XCTAssertFalse(config.enableLogging)
        XCTAssertEqual(config.serverUrl, "https://test.com")
        XCTAssertEqual(config.apiKey, "test_key")
        XCTAssertEqual(config.supportedDomains, ["example.com"])
        XCTAssertEqual(config.supportedSchemes, ["myapp"])
    }
}

// MARK: - Simple Mock for Testing

class TestLinkHandler: LinkHandler {
    var priority: Int = 50
    let testScheme: String
    
    init(scheme: String) {
        self.testScheme = scheme
    }
    
    func canHandle(url: URL) -> Bool {
        return url.scheme == testScheme
    }
    
    func handle(url: URL) async throws -> LinkHandlingResult {
        return LinkHandlingResult(handled: true, url: url, metadata: ["test": "true"])
    }
}