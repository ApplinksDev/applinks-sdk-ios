import XCTest
@testable import AppLinksSDK

final class AppLinksConfigTests: XCTestCase {
    
    // MARK: - Default Configuration Tests
    
    func testDefaultConfiguration() {
        let config = AppLinksConfig()
        
        XCTAssertTrue(config.autoHandleLinks)
        XCTAssertTrue(config.enableLogging)
        XCTAssertEqual(config.serverUrl, "https://applinks.com")
        XCTAssertNil(config.apiKey)
        XCTAssertTrue(config.supportedDomains.isEmpty)
        XCTAssertTrue(config.supportedSchemes.isEmpty)
    }
    
    // MARK: - Custom Configuration Tests
    
    func testCustomConfiguration() {
        let domains: Set<String> = ["example.com", "test.com"]
        let schemes: Set<String> = ["myapp", "testapp"]
        
        let config = AppLinksConfig(
            autoHandleLinks: false,
            enableLogging: false,
            serverUrl: "https://custom-server.com",
            apiKey: "pk_test_123456",
            supportedDomains: domains,
            supportedSchemes: schemes
        )
        
        XCTAssertFalse(config.autoHandleLinks)
        XCTAssertFalse(config.enableLogging)
        XCTAssertEqual(config.serverUrl, "https://custom-server.com")
        XCTAssertEqual(config.apiKey, "pk_test_123456")
        XCTAssertEqual(config.supportedDomains, domains)
        XCTAssertEqual(config.supportedSchemes, schemes)
    }
    
    func testPartialConfiguration() {
        let config = AppLinksConfig(
            serverUrl: "https://partial-config.com",
            apiKey: "pk_partial_123"
        )
        
        // Should use defaults for unspecified values
        XCTAssertTrue(config.autoHandleLinks)
        XCTAssertTrue(config.enableLogging)
        XCTAssertEqual(config.serverUrl, "https://partial-config.com")
        XCTAssertEqual(config.apiKey, "pk_partial_123")
        XCTAssertTrue(config.supportedDomains.isEmpty)
        XCTAssertTrue(config.supportedSchemes.isEmpty)
    }
    
    // MARK: - Server URL Tests
    
    func testHTTPSServerURL() {
        let config = AppLinksConfig(serverUrl: "https://secure.applinks.com")
        XCTAssertEqual(config.serverUrl, "https://secure.applinks.com")
    }
    
    func testHTTPServerURL() {
        let config = AppLinksConfig(serverUrl: "http://insecure.applinks.com")
        XCTAssertEqual(config.serverUrl, "http://insecure.applinks.com")
    }
    
    func testServerURLWithPath() {
        let config = AppLinksConfig(serverUrl: "https://api.applinks.com/v1")
        XCTAssertEqual(config.serverUrl, "https://api.applinks.com/v1")
    }
    
    func testServerURLWithPort() {
        let config = AppLinksConfig(serverUrl: "https://localhost:8080")
        XCTAssertEqual(config.serverUrl, "https://localhost:8080")
    }
    
    func testEmptyServerURL() {
        let config = AppLinksConfig(serverUrl: "")
        XCTAssertEqual(config.serverUrl, "")
    }
    
    // MARK: - API Key Tests
    
    func testValidPublicAPIKey() {
        let config = AppLinksConfig(apiKey: "pk_test_1234567890abcdef")
        XCTAssertEqual(config.apiKey, "pk_test_1234567890abcdef")
    }
    
    func testValidLiveAPIKey() {
        let config = AppLinksConfig(apiKey: "pk_live_1234567890abcdef")
        XCTAssertEqual(config.apiKey, "pk_live_1234567890abcdef")
    }
    
    func testCustomAPIKey() {
        let config = AppLinksConfig(apiKey: "custom_api_key_format")
        XCTAssertEqual(config.apiKey, "custom_api_key_format")
    }
    
    func testNilAPIKey() {
        let config = AppLinksConfig(apiKey: nil)
        XCTAssertNil(config.apiKey)
    }
    
    func testEmptyAPIKey() {
        let config = AppLinksConfig(apiKey: "")
        XCTAssertEqual(config.apiKey, "")
    }
    
    // MARK: - Supported Domains Tests
    
    func testSingleDomain() {
        let domains: Set<String> = ["example.com"]
        let config = AppLinksConfig(supportedDomains: domains)
        XCTAssertEqual(config.supportedDomains, domains)
    }
    
    func testMultipleDomains() {
        let domains: Set<String> = ["example.com", "test.com", "app.example.org"]
        let config = AppLinksConfig(supportedDomains: domains)
        XCTAssertEqual(config.supportedDomains, domains)
    }
    
    func testDomainsWithSubdomains() {
        let domains: Set<String> = ["app.example.com", "api.example.com", "cdn.example.com"]
        let config = AppLinksConfig(supportedDomains: domains)
        XCTAssertEqual(config.supportedDomains, domains)
    }
    
    func testDomainsWithWildcards() {
        let domains: Set<String> = ["*.example.com", "*.test.org", "specific.domain.com"]
        let config = AppLinksConfig(supportedDomains: domains)
        XCTAssertEqual(config.supportedDomains, domains)
    }
    
    func testEmptyDomains() {
        let config = AppLinksConfig(supportedDomains: Set<String>())
        XCTAssertTrue(config.supportedDomains.isEmpty)
    }
    
    // MARK: - Supported Schemes Tests
    
    func testSingleScheme() {
        let schemes: Set<String> = ["myapp"]
        let config = AppLinksConfig(supportedSchemes: schemes)
        XCTAssertEqual(config.supportedSchemes, schemes)
    }
    
    func testMultipleSchemes() {
        let schemes: Set<String> = ["myapp", "testapp", "customapp"]
        let config = AppLinksConfig(supportedSchemes: schemes)
        XCTAssertEqual(config.supportedSchemes, schemes)
    }
    
    func testSchemesWithDifferentFormats() {
        let schemes: Set<String> = ["simple", "app-with-dash", "app_with_underscore", "app123"]
        let config = AppLinksConfig(supportedSchemes: schemes)
        XCTAssertEqual(config.supportedSchemes, schemes)
    }
    
    func testEmptySchemes() {
        let config = AppLinksConfig(supportedSchemes: Set<String>())
        XCTAssertTrue(config.supportedSchemes.isEmpty)
    }
    
    // MARK: - Boolean Configuration Tests
    
    func testAutoHandleLinksTrue() {
        let config = AppLinksConfig(autoHandleLinks: true)
        XCTAssertTrue(config.autoHandleLinks)
    }
    
    func testAutoHandleLinksFalse() {
        let config = AppLinksConfig(autoHandleLinks: false)
        XCTAssertFalse(config.autoHandleLinks)
    }
    
    func testEnableLoggingTrue() {
        let config = AppLinksConfig(enableLogging: true)
        XCTAssertTrue(config.enableLogging)
    }
    
    func testEnableLoggingFalse() {
        let config = AppLinksConfig(enableLogging: false)
        XCTAssertFalse(config.enableLogging)
    }
    
    // MARK: - Complex Configuration Tests
    
    func testProductionConfiguration() {
        let config = AppLinksConfig(
            autoHandleLinks: true,
            enableLogging: false,
            serverUrl: "https://api.applinks.com",
            apiKey: "pk_live_production_key",
            supportedDomains: ["myapp.com", "*.myapp.com"],
            supportedSchemes: ["myapp"]
        )
        
        XCTAssertTrue(config.autoHandleLinks)
        XCTAssertFalse(config.enableLogging)
        XCTAssertEqual(config.serverUrl, "https://api.applinks.com")
        XCTAssertEqual(config.apiKey, "pk_live_production_key")
        XCTAssertTrue(config.supportedDomains.contains("myapp.com"))
        XCTAssertTrue(config.supportedDomains.contains("*.myapp.com"))
        XCTAssertTrue(config.supportedSchemes.contains("myapp"))
    }
    
    func testDevelopmentConfiguration() {
        let config = AppLinksConfig(
            autoHandleLinks: true,
            enableLogging: true,
            serverUrl: "https://staging-api.applinks.com",
            apiKey: "pk_test_development_key",
            supportedDomains: ["staging.myapp.com", "dev.myapp.com"],
            supportedSchemes: ["myapp-dev", "myapp-staging"]
        )
        
        XCTAssertTrue(config.autoHandleLinks)
        XCTAssertTrue(config.enableLogging)
        XCTAssertEqual(config.serverUrl, "https://staging-api.applinks.com")
        XCTAssertEqual(config.apiKey, "pk_test_development_key")
        XCTAssertEqual(config.supportedDomains.count, 2)
        XCTAssertEqual(config.supportedSchemes.count, 2)
    }
    
    // MARK: - Edge Cases
    
    func testConfigurationWithSpecialCharacters() {
        let domains: Set<String> = ["test-domain.com", "test_domain.com", "test.domain-name.com"]
        let schemes: Set<String> = ["test-scheme", "test_scheme", "testscheme123"]
        
        let config = AppLinksConfig(
            serverUrl: "https://api-test.example-domain.com:8080/v1",
            apiKey: "pk_test_special-chars_123_abc",
            supportedDomains: domains,
            supportedSchemes: schemes
        )
        
        XCTAssertEqual(config.serverUrl, "https://api-test.example-domain.com:8080/v1")
        XCTAssertEqual(config.apiKey, "pk_test_special-chars_123_abc")
        XCTAssertEqual(config.supportedDomains, domains)
        XCTAssertEqual(config.supportedSchemes, schemes)
    }
    
    func testConfigurationImmutability() {
        let domains: Set<String> = ["example.com"]
        let schemes: Set<String> = ["myapp"]
        
        let config = AppLinksConfig(
            supportedDomains: domains,
            supportedSchemes: schemes
        )
        
        // Config properties are let constants, so they're immutable by design
        XCTAssertEqual(config.supportedDomains, domains)
        XCTAssertEqual(config.supportedSchemes, schemes)
    }
}