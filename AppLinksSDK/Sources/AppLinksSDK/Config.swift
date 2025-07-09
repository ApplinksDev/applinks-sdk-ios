import Foundation

/// Configuration for AppLinksSDK
public struct AppLinksConfig {
    /// Enable automatic link handling
    public let autoHandleLinks: Bool
    
    /// Logging level throughout the SDK
    public let logLevel: AppLinksSDKLogLevel
    
    /// AppLinks server URL
    public let serverUrl: String
    
    /// API key for authentication (use public keys only)
    public let apiKey: String?
    
    /// Supported domains for universal links
    public let supportedDomains: Set<String>
    
    /// Supported custom URL schemes
    public let supportedSchemes: Set<String>
    
    /// Default configuration
    public init(
        autoHandleLinks: Bool = true,
        logLevel: AppLinksSDKLogLevel = .info,
        serverUrl: String = "https://applinks.com",
        apiKey: String? = nil,
        supportedDomains: Set<String> = [],
        supportedSchemes: Set<String> = []
    ) {
        self.autoHandleLinks = autoHandleLinks
        self.logLevel = logLevel
        self.serverUrl = serverUrl
        self.apiKey = apiKey
        self.supportedDomains = supportedDomains
        self.supportedSchemes = supportedSchemes
    }
}
