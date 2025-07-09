import Foundation

/// Protocol for middleware components in the link handling chain
public protocol LinkMiddleware {
    /// Process the link through this middleware
    /// - Parameters:
    ///   - url: The URL being processed
    ///   - context: The current handling context
    ///   - next: The next middleware in the chain
    /// - Returns: The result after processing through this middleware and subsequent ones
    func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult
}

/// A type-erased wrapper for LinkMiddleware
public struct AnyLinkMiddleware: LinkMiddleware {
    private let _process: (URL, LinkHandlingContext, @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult) async throws -> LinkHandlingResult
    
    public init<M: LinkMiddleware>(_ middleware: M) {
        self._process = middleware.process
    }
    
    public func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        return try await _process(url, context, next)
    }
}

/// Combines multiple middleware into a single processing chain
public struct MiddlewareChain {
    private let _middlewares: [AnyLinkMiddleware]
    
    /// Access to the middleware array for combining chains
    public var middlewares: [AnyLinkMiddleware] {
        _middlewares
    }
    
    public init(middlewares: [AnyLinkMiddleware] = []) {
        self._middlewares = middlewares
    }
    
    /// Execute the middleware chain
    /// - Parameters:
    ///   - url: The URL to process
    ///   - context: The handling context
    ///   - finalHandler: The final handler to execute after all middleware
    /// - Returns: The result after processing through all middleware and the final handler
    public func execute(
        url: URL,
        context: LinkHandlingContext,
        finalHandler: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        return try await executeMiddleware(
            at: 0,
            url: url,
            context: context,
            finalHandler: finalHandler
        )
    }
    
    private func executeMiddleware(
        at index: Int,
        url: URL,
        context: LinkHandlingContext,
        finalHandler: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        guard index < _middlewares.count else {
            return try await finalHandler(url, context)
        }
        
        let middleware = _middlewares[index]
        return try await middleware.process(url: url, context: context) { nextUrl, nextContext in
            return try await executeMiddleware(
                at: index + 1,
                url: nextUrl,
                context: nextContext,
                finalHandler: finalHandler
            )
        }
    }
}