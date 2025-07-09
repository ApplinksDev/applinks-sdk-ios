import Foundation
import OSLog


/// Result of link handling
public struct LinkHandlingResult {
    public let handled: Bool
    public let originalUrl: URL
    public let path: String
    public let params: [String: String]
    public let metadata: [String: Any]
    public let error: String?
    
    public init(
        handled: Bool,
        originalUrl: URL,
        path: String,
        params: [String: String] = [:],
        metadata: [String: Any] = [:],
        error: String? = nil
    ) {
        self.handled = handled
        self.originalUrl = originalUrl
        self.path = path
        self.params = params
        self.metadata = metadata
        self.error = error
    }
}

/// Context for link handling
public struct LinkHandlingContext {
    public let isFirstLaunch: Bool
    public let launchTimestamp: Date
    public var appLinksLogLevel: OSLogType
    public var deepLinkPath: String?
    public var deepLinkParams: [String: String]
    public var additionalData: [String: Any]
    
    public init(
        isFirstLaunch: Bool = false,
        launchTimestamp: Date = Date(),
        additionalData: [String: Any] = [:]
    ) {
        self.isFirstLaunch = isFirstLaunch
        self.launchTimestamp = launchTimestamp
        self.deepLinkPath = nil
        self.deepLinkParams = [:]
        self.additionalData = additionalData
        self.appLinksLogLevel = .info
    }
}
