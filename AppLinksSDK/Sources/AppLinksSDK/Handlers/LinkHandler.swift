import Foundation

/// Protocol for handling different types of links
public protocol LinkHandler {
    /// Check if this handler can process the given URL
    func canHandle(url: URL) -> Bool
    
    /// Handle the link and return the result
    func handle(url: URL) async throws -> LinkHandlingResult
    
    /// Get the priority of this handler (higher values are tried first)
    var priority: Int { get }
}

/// Result of link handling
public struct LinkHandlingResult {
    public let handled: Bool
    public let url: URL
    public let metadata: [String: String]
    public let error: String?
    
    public init(
        handled: Bool,
        url: URL,
        metadata: [String: String] = [:],
        error: String? = nil
    ) {
        self.handled = handled
        self.url = url
        self.metadata = metadata
        self.error = error
    }
}

/// Context for link handling
public struct LinkHandlingContext {
    public let isFirstLaunch: Bool
    public let launchTimestamp: Date
    public let additionalData: [String: Any]
    
    public init(
        isFirstLaunch: Bool = false,
        launchTimestamp: Date = Date(),
        additionalData: [String: Any] = [:]
    ) {
        self.isFirstLaunch = isFirstLaunch
        self.launchTimestamp = launchTimestamp
        self.additionalData = additionalData
    }
}