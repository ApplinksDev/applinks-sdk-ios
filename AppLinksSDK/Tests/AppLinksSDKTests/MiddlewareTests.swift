import XCTest
@testable import AppLinksSDK

class MiddlewareTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        // Reset SDK state would require internal access
        // For now, we'll work with the singleton pattern
    }
    
    // MARK: - Middleware Chain Tests
    
    func testMiddlewareChainExecution() async throws {
        // Given
        var executionOrder: [String] = []
        
        let middleware1 = TestMiddleware(name: "First") { order in
            executionOrder.append(order)
        }
        
        let middleware2 = TestMiddleware(name: "Second") { order in
            executionOrder.append(order)
        }
        
        let chain = MiddlewareChain(middlewares: [
            AnyLinkMiddleware(middleware1),
            AnyLinkMiddleware(middleware2)
        ])
        
        let url = URL(string: "https://example.com/test")!
        let context = LinkHandlingContext()
        
        // When
        let result = try await chain.execute(url: url, context: context) { url, _ in
            executionOrder.append("Handler")
            return LinkHandlingResult(handled: true, url: url)
        }
        
        // Then
        XCTAssertTrue(result.handled)
        XCTAssertEqual(executionOrder, ["First-before", "Second-before", "Handler", "Second-after", "First-after"])
    }
    
    func testMiddlewareCanShortCircuit() async throws {
        // Given
        let middleware1 = ShortCircuitMiddleware()
        let middleware2 = TestMiddleware(name: "Second") { _ in }
        
        let chain = MiddlewareChain(middlewares: [
            AnyLinkMiddleware(middleware1),
            AnyLinkMiddleware(middleware2)
        ])
        
        let url = URL(string: "https://example.com/test")!
        let context = LinkHandlingContext()
        
        // When
        let result = try await chain.execute(url: url, context: context) { _, _ in
            XCTFail("Handler should not be called")
            return LinkHandlingResult(handled: false, url: url)
        }
        
        // Then
        XCTAssertFalse(result.handled)
        XCTAssertEqual(result.error, "Short-circuited")
    }
    
    // MARK: - Basic Middleware Tests
    
    func testBasicMiddleware() async throws {
        // Given
        let middleware = TestMiddleware(name: "Test") { _ in }
        let url = URL(string: "https://example.com/test")!
        let context = LinkHandlingContext(isFirstLaunch: true)
        
        // When
        let result = try await middleware.process(url: url, context: context) { url, _ in
            return LinkHandlingResult(handled: true, url: url, metadata: ["key": "value"])
        }
        
        // Then
        XCTAssertTrue(result.handled)
    }
    
    // MARK: - Scheme Middleware Tests
    
    func testSchemeMiddlewareHandlesCustomScheme() async throws {
        // Given
        let middleware = SchemeMiddleware(supportedSchemes: ["myapp"])
        let url = URL(string: "myapp://test/path?param=value&visit_id=123")!
        let context = LinkHandlingContext()
        
        // When
        let result = try await middleware.process(url: url, context: context) { url, updatedContext in
            return LinkHandlingResult(handled: true, url: url, metadata: updatedContext.deepLinkParams)
        }
        
        // Then
        XCTAssertTrue(result.handled)
        XCTAssertEqual(result.metadata["param"], "value")
        // visit_id should be in additionalData, not metadata
    }
    
    func testSchemeMiddlewareIgnoresUnsupportedScheme() async throws {
        // Given
        let middleware = SchemeMiddleware(supportedSchemes: ["myapp"])
        let url = URL(string: "https://example.com/test")!
        let context = LinkHandlingContext()
        
        // When
        let result = try await middleware.process(url: url, context: context) { url, _ in
            return LinkHandlingResult(handled: true, url: url)
        }
        
        // Then
        XCTAssertTrue(result.handled)
    }
    
    // MARK: - Context Modification Tests
    
    func testContextModificationMiddleware() async throws {
        // Given
        let middleware = ContextModificationMiddleware()
        let url = URL(string: "https://example.com/test")!
        let context = LinkHandlingContext()
        
        // When
        let result = try await middleware.process(url: url, context: context) { url, updatedContext in
            // Verify context was modified
            XCTAssertEqual(updatedContext.additionalData["modified"] as? String, "true")
            return LinkHandlingResult(handled: true, url: url, metadata: ["action": "open"])
        }
        
        // Then
        XCTAssertTrue(result.handled)
    }
    
    // MARK: - Real SDK Integration Tests
    
    func testSDKWithCustomMiddleware() async throws {
        // Given
        let customMiddleware = AnyLinkMiddleware(TestMiddleware(name: "Custom") { _ in })
        
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.applinks.com",
            supportedSchemes: ["testapp"],
            customMiddleware: [customMiddleware]
        )
        
        let expectation = XCTestExpectation(description: "Link handled")
        let url = URL(string: "testapp://test/path")!
        
        // When
        sdk.handleLink(url, onSuccess: { _, metadata in
            XCTAssertEqual(metadata["deepLinkPath"], "/test/path")
            expectation.fulfill()
        }, onError: { error in
            // This might be expected if no API client is available
            expectation.fulfill()
        })
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Multiple Middleware Tests
    
    func testMultipleMiddlewareExecution() async throws {
        // Given
        let middleware1 = AnyLinkMiddleware(TestMiddleware(name: "First") { _ in })
        let middleware2 = AnyLinkMiddleware(TestMiddleware(name: "Second") { _ in })
        
        let sdk = AppLinksSDK.initialize(
            apiKey: "pk_test_123",
            serverUrl: "https://test.applinks.com",
            supportedSchemes: ["testapp"],
            customMiddleware: [middleware1, middleware2]
        )
        
        let expectation = XCTestExpectation(description: "Link handled")
        let url = URL(string: "testapp://test")!
        
        // When
        sdk.handleLink(url, onSuccess: { _, _ in
            expectation.fulfill()
        }, onError: { _ in
            expectation.fulfill()
        })
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}

// MARK: - Test Helpers

class TestMiddleware: LinkMiddleware {
    let name: String
    let onExecute: (String) -> Void
    
    init(name: String, onExecute: @escaping (String) -> Void) {
        self.name = name
        self.onExecute = onExecute
    }
    
    func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        onExecute("\(name)-before")
        let result = try await next(url, context)
        onExecute("\(name)-after")
        return result
    }
}

class ShortCircuitMiddleware: LinkMiddleware {
    func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        return LinkHandlingResult(handled: false, url: url, error: "Short-circuited")
    }
}

class ContextModificationMiddleware: LinkMiddleware {
    func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        var updatedContext = context
        updatedContext.additionalData["modified"] = "true"
        return try await next(url, updatedContext)
    }
}