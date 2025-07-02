import XCTest
@testable import AppLinksSDK

final class ClipboardManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    private var clipboardManager: ClipboardManager!
    private var mockApiClient: MockAppLinksApiClient!
    private var mockPreferences: MockAppLinksPreferences!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockApiClient = MockAppLinksApiClient()
        mockPreferences = MockAppLinksPreferences()
        clipboardManager = ClipboardManager(
            apiClient: mockApiClient,
            preferences: mockPreferences,
            enableLogging: false
        )
    }
    
    override func tearDown() {
        clipboardManager = nil
        mockApiClient = nil
        mockPreferences = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(clipboardManager)
    }
    
    // MARK: - retrieveDeferredDeepLink Tests
    
    func testRetrieveDeferredDeepLinkWithEmptyClipboard() async throws {
        // Test when clipboard is empty
        // Note: Since we can't easily mock UIPasteboard.general, 
        // we'll test the business logic components
        
        let result = try await clipboardManager.retrieveDeferredDeepLink()
        XCTAssertNil(result.url)
        XCTAssertTrue(result.metadata.isEmpty)
    }
    
    func testVisitIdAlreadyProcessed() async {
        mockPreferences.visitIds = ["test-visit-id"]
        
        do {
            let _ = try await clipboardManager.retrieveDeferredDeepLink()
            XCTFail("Should throw visitAlreadyProcessed error")
        } catch {
            if case AppLinksError.visitAlreadyProcessed = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testNoLinkDataInVisit() async {
        mockApiClient.mockVisitDetailsResponse = VisitDetailsResponse(
            id: "test-visit-id",
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            lastSeenAt: "2024-01-01T00:00:00Z",
            expiresAt: "2024-12-31T23:59:59Z",
            ipAddress: "127.0.0.1",
            userAgent: "Test User Agent",
            browserFingerprint: nil,
            link: nil // No link data
        )
        
        do {
            let _ = try await clipboardManager.retrieveDeferredDeepLink()
            XCTFail("Should throw noLinkDataInVisit error")
        } catch {
            if case AppLinksError.noLinkDataInVisit = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testLinkExpired() async {
        let expiredDate = "2020-01-01T00:00:00Z" // Past date
        
        mockApiClient.mockVisitDetailsResponse = VisitDetailsResponse(
            id: "test-visit-id",
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            lastSeenAt: "2024-01-01T00:00:00Z",
            expiresAt: "2024-12-31T23:59:59Z",
            ipAddress: "127.0.0.1",
            userAgent: "Test User Agent",
            browserFingerprint: nil,
            link: LinkResponse(
                id: "link-id",
                title: "Test Link",
                aliasPath: "/test",
                domain: "example.com",
                originalUrl: "https://example.com/original",
                deepLinkPath: "myapp://test",
                deepLinkParams: ["key": "value"],
                expiresAt: expiredDate,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                fullUrl: "https://example.com/test"
            )
        )
        
        do {
            let _ = try await clipboardManager.retrieveDeferredDeepLink()
            XCTFail("Should throw linkExpired error")
        } catch {
            if case AppLinksError.linkExpired = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - ClipboardResult Tests
    
    func testClipboardResultCreation() {
        let url = URL(string: "myapp://test")!
        let metadata = ["key": "value"]
        
        let result = ClipboardResult(url: url, metadata: metadata)
        
        XCTAssertEqual(result.url, url)
        XCTAssertEqual(result.metadata, metadata)
    }
    
    func testClipboardResultWithNilUrl() {
        let metadata = ["key": "value"]
        
        let result = ClipboardResult(url: nil, metadata: metadata)
        
        XCTAssertNil(result.url)
        XCTAssertEqual(result.metadata, metadata)
    }
}

// MARK: - Mock Classes

class MockAppLinksApiClient: AppLinksApiClient {
    var mockLinkResponse: LinkResponse?
    var mockVisitDetailsResponse: VisitDetailsResponse?
    var shouldThrowError = false
    var errorToThrow: Error = AppLinksError.networkError("Mock error")
    
    init() {
        super.init(serverUrl: "https://mock.api.com", apiKey: "mock_key", enableLogging: false)
    }
    
    override func fetchLink(linkId: String) async throws -> LinkResponse {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockLinkResponse ?? LinkResponse(
            id: linkId,
            title: "Mock Link",
            aliasPath: "/mock",
            domain: "mock.com",
            originalUrl: "https://mock.com/original",
            deepLinkPath: "mockapp://test",
            deepLinkParams: [:],
            expiresAt: "2024-12-31T23:59:59Z",
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            fullUrl: "https://mock.com/test"
        )
    }
    
    override func fetchVisitDetails(visitId: String) async throws -> VisitDetailsResponse {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockVisitDetailsResponse ?? VisitDetailsResponse(
            id: visitId,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            lastSeenAt: "2024-01-01T00:00:00Z",
            expiresAt: "2024-12-31T23:59:59Z",
            ipAddress: "127.0.0.1",
            userAgent: "Mock User Agent",
            browserFingerprint: nil,
            link: LinkResponse(
                id: "mock-link-id",
                title: "Mock Link",
                aliasPath: "/mock",
                domain: "mock.com",
                originalUrl: "https://mock.com/original",
                deepLinkPath: "mockapp://test",
                deepLinkParams: ["mock": "value"],
                expiresAt: "2024-12-31T23:59:59Z",
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                fullUrl: "https://mock.com/test"
            )
        )
    }
}

class MockAppLinksPreferences: AppLinksPreferences {
    private var _sessionId: String?
    private var _isFirstLaunchCompleted = false
    var visitIds: [String] = []
    
    override init() {
        super.init()
    }
    
    override var sessionId: String? {
        get { _sessionId }
        set { _sessionId = newValue }
    }
    
    override var isFirstLaunchCompleted: Bool {
        get { _isFirstLaunchCompleted }
        set { _isFirstLaunchCompleted = newValue }
    }
    
    override var isFirstLaunch: Bool {
        !_isFirstLaunchCompleted
    }
    
    override func markFirstLaunchCompleted() {
        _isFirstLaunchCompleted = true
    }
    
    override func addVisitId(_ visitId: String) {
        if !visitIds.contains(visitId) {
            visitIds.append(visitId)
        }
    }
    
    override func hasVisitId(_ visitId: String) -> Bool {
        visitIds.contains(visitId)
    }
    
    override var visitIdCount: Int {
        visitIds.count
    }
    
    override func clearVisitIds() {
        visitIds.removeAll()
    }
    
    override func clear() {
        _sessionId = nil
        _isFirstLaunchCompleted = false
        visitIds.removeAll()
    }
}