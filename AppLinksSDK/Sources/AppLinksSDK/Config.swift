import Foundation

/// Configuration for AppLinksSDK
public struct AppLinksConfig {
    /// Enable automatic link handling
    public let autoHandleLinks: Bool
    
    /// Enable debug logging
    public let enableLogging: Bool
    
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
        enableLogging: Bool = true,
        serverUrl: String = "https://applinks.com",
        apiKey: String? = nil,
        supportedDomains: Set<String> = [],
        supportedSchemes: Set<String> = []
    ) {
        self.autoHandleLinks = autoHandleLinks
        self.enableLogging = enableLogging
        self.serverUrl = serverUrl
        self.apiKey = apiKey
        self.supportedDomains = supportedDomains
        self.supportedSchemes = supportedSchemes
    }
}