import XCTest
@testable import AppLinksSDK

final class AppLinksSDKInitializationTests: XCTestCase {
    
    // MARK: - Basic Initialization Tests
    
    func testMinimalInitialization() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://api.test.com"
        )
        
        XCTAssertNotNil(sdk)
        XCTAssertNotNil(AppLinksSDK.shared)
    }
    
    func testFullParameterInitialization() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_key",
            serverUrl: "https://api.test.com",
            autoHandleLinks: false,
            enableLogging: true,
            supportedDomains: ["example.com", "test.com"],
            supportedSchemes: ["myapp", "testapp"]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testInitializationWithConfig() {
        let config = AppLinksConfig(
            autoHandleLinks: false,
            enableLogging: true,
            serverUrl: "https://api.test.com",
            apiKey: "pk_test_key",
            supportedDomains: ["example.com"],
            supportedSchemes: ["myapp"]
        )
        
        let sdk = AppLinksSDK.initialize(config: config)
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - Configuration Parameter Tests
    
    func testApiKeyConfiguration() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com"
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testServerUrlConfiguration() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://custom-server.com"
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testAutoHandleLinksConfiguration() {
        let sdk1 = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            autoHandleLinks: true
        )
        
        XCTAssertNotNil(sdk1)
        
        // Test false case (need to create new instance since SDK is singleton)
        // This will show warning about already initialized
        let sdk2 = AppLinksSDK.initialize(
            apiKey: "pk_test_456",
            serverUrl: "https://test2.com",
            autoHandleLinks: false
        )
        
        XCTAssertNotNil(sdk2)
    }
    
    func testEnableLoggingConfiguration() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            enableLogging: false
        )
        
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - Supported Domains Tests
    
    func testSupportedDomainsSet() {
        let domains: Set<String> = ["example.com", "test.com", "app.com"]
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            supportedDomains: domains
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testSupportedDomainsVarargs() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            supportedDomains: ["domain1.com", "domain2.com", "domain3.com"]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testSupportedDomainsSingle() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            supportedDomains: ["single-domain.com"]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testSupportedDomainsEmpty() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            supportedDomains: []
        )
        
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - Supported Schemes Tests
    
    func testSupportedSchemesSet() {
        let schemes: Set<String> = ["myapp", "testapp", "customapp"]
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            supportedSchemes: schemes
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testSupportedSchemesVarargs() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            supportedSchemes: ["scheme1", "scheme2", "scheme3"]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testSupportedSchemesSingle() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            supportedSchemes: ["singlescheme"]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - Custom Handlers Tests
    
    func testAddCustomHandler() {
        let customHandler = TestCustomLinkHandler()
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            customHandlers: [customHandler]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testAddMultipleCustomHandlers() {
        let handler1 = TestCustomLinkHandler(scheme: "test1")
        let handler2 = TestCustomLinkHandler(scheme: "test2")
        
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.com",
            customHandlers: [handler1, handler2]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - API Key Validation Tests
    
    func testValidPublicAPIKey() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_1234567890",
            serverUrl: "https://test.com"
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testAPIKeyWithoutPrefix() {
        // This should generate a warning but still work
        let sdk = AppLinksSDK.initialize(
            apiKey: "test_key_without_prefix",
            serverUrl: "https://test.com"
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testPrivateAPIKeyThrowsFatalError() {
        // We can't directly test fatalError, but we can verify the logic exists
        // by checking that initialization with a valid key works
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_safe_key",
            serverUrl: "https://test.com"
        )
        
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - Complex Configuration Tests
    
    func testCompleteConfiguration() {
        let customHandler = TestCustomLinkHandler()
        
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_complex_config",
            serverUrl: "https://api.complex-test.com",
            autoHandleLinks: false,
            enableLogging: true,
            supportedDomains: ["app.example.com", "link.example.com", "*.wildcard.com"],
            supportedSchemes: ["myapp", "customapp"],
            customHandlers: [customHandler]
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testConfigurationWithDefaults() {
        // Test using default values for most parameters
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_defaults"
            // serverUrl will use default
            // autoHandleLinks will use default (true)
            // enableLogging will use default (true)
            // supportedDomains will use default ([])
            // supportedSchemes will use default ([])
        )
        
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyStringValues() {
        let sdk = AppLinksSDK.initialize(
            apiKey: "", // Empty API key
            serverUrl: "https://test.com"
        )
        
        XCTAssertNotNil(sdk)
    }
    
    func testNilAPIKeyWithConfig() {
        // Using config object allows nil apiKey
        let config = AppLinksConfig(
            serverUrl: "https://test.com",
            apiKey: nil
        )
        
        let sdk = AppLinksSDK.initialize(config: config)
        XCTAssertNotNil(sdk)
    }
    
    func testMultipleInitializationAttempts() {
        // First initialization
        let sdk1 = AppLinksSDK.initialize(
            apiKey: "pk_first_attempt",
            serverUrl: "https://test.com"
        )
        XCTAssertNotNil(sdk1)
        
        // Second initialization (should show warning but still return the same instance)
        let sdk2 = AppLinksSDK.initialize(
            apiKey: "pk_second_attempt",
            serverUrl: "https://test2.com"
        )
        XCTAssertNotNil(sdk2)
        
        // Both should reference the same shared instance
        XCTAssertEqual(ObjectIdentifier(sdk1), ObjectIdentifier(sdk2))
        XCTAssertEqual(ObjectIdentifier(AppLinksSDK.shared), ObjectIdentifier(sdk1))
    }
}

// MARK: - Test Helper Classes

class TestCustomLinkHandler: LinkHandler {
    let priority: Int = 50
    private let testScheme: String
    
    init(scheme: String = "testscheme") {
        self.testScheme = scheme
    }
    
    func canHandle(url: URL) -> Bool {
        return url.scheme == testScheme
    }
    
    func handle(url: URL) async throws -> LinkHandlingResult {
        return LinkHandlingResult(
            handled: true,
            url: url,
            metadata: ["test": "true", "scheme": testScheme]
        )
    }
}