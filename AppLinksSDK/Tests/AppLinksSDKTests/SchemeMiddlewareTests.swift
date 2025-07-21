//
//  SchemeMiddlewareTests.swift
//  AppLinksSDKTests
//
//  Created by Maxence Henneron on 7/21/25.
//

import XCTest
@testable import AppLinksSDK

final class SchemeMiddlewareTests: XCTestCase {
    
    // MARK: - Properties
    
    private var middleware: SchemeMiddleware!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        middleware = SchemeMiddleware(supportedSchemes: ["com.applinks.applinksdemo", "myapp", "testscheme"])
    }
    
    override func tearDown() {
        middleware = nil
        super.tearDown()
    }
    
    // MARK: - URL Parsing Tests
    
    func testParseCustomSchemeWithHostAndPath() async throws {
        let url = URL(string: "com.applinks.applinksdemo://product/special-offer?code=SAVE20&discount=20")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertNotNil(capturedContext)
        XCTAssertEqual(capturedContext?.deepLinkPath, "/product/special-offer")
        XCTAssertEqual(capturedContext?.deepLinkParams["code"], "SAVE20")
        XCTAssertEqual(capturedContext?.deepLinkParams["discount"], "20")
    }
    
    func testParseSimpleCustomScheme() async throws {
        let url = URL(string: "myapp://home")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkPath, "/home")
        XCTAssertTrue(capturedContext?.deepLinkParams.isEmpty == true)
    }
    
    func testParseCustomSchemeWithoutHost() async throws {
        let url = URL(string: "testscheme:///path/to/resource")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkPath, "/path/to/resource")
    }
    
    // MARK: - Query Parameter Tests
    
    func testParseMultipleQueryParameters() async throws {
        let url = URL(string: "myapp://shop?category=electronics&sort=price&order=asc")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkParams["category"], "electronics")
        XCTAssertEqual(capturedContext?.deepLinkParams["sort"], "price")
        XCTAssertEqual(capturedContext?.deepLinkParams["order"], "asc")
    }
    
    func testParseURLEncodedQueryParameters() async throws {
        let url = URL(string: "myapp://search?q=hello%20world&filter=new%26improved")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkParams["q"], "hello world")
        XCTAssertEqual(capturedContext?.deepLinkParams["filter"], "new&improved")
    }
    
    func testParseEmptyQueryParameter() async throws {
        let url = URL(string: "myapp://page?empty=&key=value")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkParams["empty"], "")
        XCTAssertEqual(capturedContext?.deepLinkParams["key"], "value")
    }
    
    // MARK: - Path Extraction Tests
    
    func testParseComplexPath() async throws {
        let url = URL(string: "myapp://store/category/electronics/product/12345")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkPath, "/store/category/electronics/product/12345")
    }
    
    func testParsePathWithTrailingSlash() async throws {
        let url = URL(string: "myapp://profile/settings/")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkPath, "/profile/settings")
    }
    
    // MARK: - Scheme Handling Tests
    
    func testUnsupportedSchemePassesThrough() async throws {
        let url = URL(string: "unsupported://path")!
        var nextCalled = false
        
        let result = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { passedURL, context in
            nextCalled = true
            XCTAssertEqual(passedURL, url)
            return LinkHandlingResult(
                handled: false,
                originalUrl: url,
                path: ""
            )
        }
        
        XCTAssertTrue(nextCalled)
        XCTAssertFalse(result.handled)
    }
    
    func testCaseInsensitiveSchemeMatching() async throws {
        let url = URL(string: "MYAPP://home")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkPath, "/home")
    }
    
    // MARK: - Edge Cases
    
    func testURLWithoutScheme() async throws {
        let url = URL(string: "//host/path")!
        var nextCalled = false
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, _ in
            nextCalled = true
            return LinkHandlingResult(
                handled: false,
                originalUrl: url,
                path: ""
            )
        }
        
        XCTAssertTrue(nextCalled)
    }
    
    func testURLWithSpecialCharactersInPath() async throws {
        let url = URL(string: "myapp://user/@john.doe/profile?tab=posts")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkPath, "/user/@john.doe/profile")
        XCTAssertEqual(capturedContext?.deepLinkParams["tab"], "posts")
    }
    
    func testURLWithFragment() async throws {
        let url = URL(string: "myapp://page?param=value#section")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        XCTAssertEqual(capturedContext?.deepLinkPath, "/page")
        XCTAssertEqual(capturedContext?.deepLinkParams["param"], "value")
    }
    
    func testPreservesExistingContext() async throws {
        let url = URL(string: "myapp://new/path?newParam=value")!
        var initialContext = LinkHandlingContext(additionalData: ["key": "value"])
        initialContext.deepLinkPath = "/old/path"
        initialContext.deepLinkParams = ["oldParam": "oldValue"]
        
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: initialContext
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        // Should replace path and params but preserve additional data
        XCTAssertEqual(capturedContext?.deepLinkPath, "/new/path")
        XCTAssertEqual(capturedContext?.deepLinkParams["newParam"], "value")
        XCTAssertNil(capturedContext?.deepLinkParams["oldParam"])
        XCTAssertEqual(capturedContext?.additionalData["key"] as? String, "value")
    }
    
    // MARK: - Integration Tests
    
    func testMiddlewareChainIntegration() async throws {
        let middleware1 = SchemeMiddleware(supportedSchemes: ["app1"])
        let middleware2 = SchemeMiddleware(supportedSchemes: ["app2"])
        
        let url1 = URL(string: "app1://test")!
        let url2 = URL(string: "app2://test")!
        
        var middleware1Handled = false
        var middleware2Handled = false
        
        // Test first middleware handles its scheme
        _ = try await middleware1.process(
            url: url1,
            context: LinkHandlingContext()
        ) { _, _ in
            middleware1Handled = true
            return LinkHandlingResult(
                handled: true,
                originalUrl: url1,
                path: "/test"
            )
        }
        
        XCTAssertTrue(middleware1Handled)
        
        // Test first middleware passes through other schemes
        _ = try await middleware1.process(
            url: url2,
            context: LinkHandlingContext()
        ) { _, _ in
            middleware2Handled = true
            return LinkHandlingResult(
                handled: true,
                originalUrl: url2,
                path: "/test"
            )
        }
        
        XCTAssertTrue(middleware2Handled)
    }
    
    // MARK: - Specific Bug Test
    
    func testBugReproduction_SpecialOfferURL() async throws {
        // This test specifically reproduces the bug mentioned by the user
        let url = URL(string: "com.applinks.applinksdemo://product/special-offer?code=SAVE20&discount=20")!
        var capturedContext: LinkHandlingContext?
        
        _ = try await middleware.process(
            url: url,
            context: LinkHandlingContext()
        ) { _, context in
            capturedContext = context
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: context.deepLinkPath ?? "",
                params: context.deepLinkParams
            )
        }
        
        // These assertions will show if the bug exists
        XCTAssertEqual(capturedContext?.deepLinkPath, "/product/special-offer", "Path should be correctly extracted")
        XCTAssertEqual(capturedContext?.deepLinkParams["code"], "SAVE20", "Query parameter 'code' should be parsed")
        XCTAssertEqual(capturedContext?.deepLinkParams["discount"], "20", "Query parameter 'discount' should be parsed")
        XCTAssertEqual(capturedContext?.deepLinkParams.count, 2, "Should have exactly 2 query parameters")
    }
}