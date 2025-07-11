import XCTest
@testable import AppLinksSDK

// MARK: - Mock Pasteboard

class MockPasteboard: MockablePasteboard {
    var string: String?
    var hasURLs: Bool = false
    
    init(string: String? = nil, hasURLs: Bool = false) {
        self.string = string
        self.hasURLs = hasURLs
    }
}

final class ClipboardManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    private var clipboardManager: ClipboardManager!
    private var mockPasteboard: MockPasteboard!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockPasteboard = MockPasteboard()
        clipboardManager = ClipboardManager(pasteboard: mockPasteboard)
    }
    
    override func tearDown() {
        clipboardManager = nil
        mockPasteboard = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(clipboardManager)
    }
    
    // MARK: - retrieveDeferredDeepLink Tests
    
    func testRetrieveDeferredDeepLinkWithEmptyClipboard() async {
        // Set empty clipboard
        mockPasteboard.string = ""
        mockPasteboard.hasURLs = false
        
        let result = await clipboardManager.retrieveDeferredDeepLink()
        XCTAssertNil(result.url)
    }
    
    func testRetrieveDeferredDeepLinkWithValidURL() async {
        // Set a valid URL in clipboard
        let testURL = "https://example.com/test"
        mockPasteboard.string = testURL
        mockPasteboard.hasURLs = true
        
        let result = await clipboardManager.retrieveDeferredDeepLink()
        XCTAssertNotNil(result.url)
        XCTAssertEqual(result.url?.absoluteString, testURL)
        
        // Verify clipboard was cleared
        XCTAssertEqual(mockPasteboard.string, "")
    }
    
    func testRetrieveDeferredDeepLinkWithCustomScheme() async {
        // Set a custom scheme URL in clipboard
        let testURL = "myapp://action/test"
        mockPasteboard.string = testURL
        mockPasteboard.hasURLs = true
        
        let result = await clipboardManager.retrieveDeferredDeepLink()
        XCTAssertNotNil(result.url)
        XCTAssertEqual(result.url?.absoluteString, testURL)
        
        // Verify clipboard was cleared
        XCTAssertEqual(mockPasteboard.string, "")
    }
    
    func testRetrieveDeferredDeepLinkWithWhitespace() async {
        // Set URL with whitespace
        mockPasteboard.string = "  https://example.com/test  "
        mockPasteboard.hasURLs = true
        
        let result = await clipboardManager.retrieveDeferredDeepLink()
        XCTAssertNotNil(result.url)
        XCTAssertEqual(result.url?.absoluteString, "https://example.com/test")
        
        // Verify clipboard was cleared
        XCTAssertEqual(mockPasteboard.string, "")
    }
    
    func testRetrieveDeferredDeepLinkWithNoURLsDetected() async {
        // Set content but hasURLs = false
        mockPasteboard.string = "https://example.com/test"
        mockPasteboard.hasURLs = false
        
        let result = await clipboardManager.retrieveDeferredDeepLink()
        XCTAssertNil(result.url)
    }
    
    func testRetrieveDeferredDeepLinkWithURLsDetectedButNoContent() async {
        // Set hasURLs = true but no content
        mockPasteboard.string = nil
        mockPasteboard.hasURLs = true
        
        let result = await clipboardManager.retrieveDeferredDeepLink()
        XCTAssertNil(result.url)
    }
    
    func testRetrieveDeferredDeepLinkWithURLsDetectedButEmptyContent() async {
        // Set hasURLs = true but empty content
        mockPasteboard.string = ""
        mockPasteboard.hasURLs = true
        
        let result = await clipboardManager.retrieveDeferredDeepLink()
        XCTAssertNil(result.url)
    }
    
    // MARK: - ClipboardResult Tests
    
    func testClipboardResultCreation() {
        let url = URL(string: "myapp://test")!
        
        let result = ClipboardResult(url: url)
        
        XCTAssertEqual(result.url, url)
    }
    
    func testClipboardResultWithNilUrl() {
        let result = ClipboardResult(url: nil)
        
        XCTAssertNil(result.url)
    }
}

