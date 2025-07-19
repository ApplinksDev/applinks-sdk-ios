import Foundation

/// Public API for creating shortened links
public class LinkShortener {
    private let apiClient: AppLinksApiClient
    private let logger = AppLinksSDKLogger.shared.withCategory("link-shortener")
    
    internal init(apiClient: AppLinksApiClient) {
        self.apiClient = apiClient
    }
    
    /// Create a new shortened link
    /// - Parameters:
    ///   - domain: The domain to create the link on
    ///   - title: Title for the link
    ///   - deepLinkPath: The in-app path/route to navigate to
    ///   - originalUrl: The web URL to redirect to if app is not installed
    ///   - deepLinkParams: Additional parameters for deep linking
    ///   - expiresAt: Optional expiration date for the link
    ///   - pathType: Type of path to generate (unguessable or short)
    /// - Returns: Created link details
    public func createLink(
        domain: String,
        title: String,
        deepLinkPath: String,
        originalUrl: String? = nil,
        deepLinkParams: [String: String]? = nil,
        expiresAt: Date? = nil,
        pathType: LinkPathType = .unguessable
    ) async throws -> CreatedLink {
        logger.debug("[AppLinksSDK] Creating link with title: \(title)")
        
        // Build the request
        let linkData = CreateLinkRequest.LinkData(
            title: title,
            originalUrl: originalUrl,
            deepLinkPath: deepLinkPath,
            deepLinkParams: deepLinkParams,
            expiresAt: expiresAt,
            aliasPathAttributes: CreateLinkRequest.AliasPathAttributes(
                type: pathType.toInternalType()
            )
        )
        
        // Make the API call
        let response = try await apiClient.createLink(domain: domain, linkData: linkData)
        
        // Convert to public model
        return CreatedLink(
            id: response.id,
            title: response.title,
            aliasPath: response.aliasPath,
            domain: response.domain,
            originalUrl: response.originalUrl,
            deepLinkPath: response.deepLinkPath,
            deepLinkParams: response.deepLinkParams,
            expiresAt: response.expiresAt,
            createdAt: response.createdAt,
            updatedAt: response.updatedAt,
            fullUrl: response.fullUrl
        )
    }
}

// MARK: - Public Types

/// Type of path to generate for the link
public enum LinkPathType {
    /// Generate a 32-character unguessable path
    case unguessable
    /// Generate a 4-6 character short path
    case short
    
    internal func toInternalType() -> CreateLinkRequest.AliasPathAttributes.PathType {
        switch self {
        case .unguessable:
            return .unguessable
        case .short:
            return .short
        }
    }
}

/// Result of creating a link
public struct CreatedLink {
    /// Unique identifier of the link
    public let id: String
    /// Title of the link
    public let title: String
    /// Generated path for the link
    public let aliasPath: String
    /// Domain hosting the link
    public let domain: String
    /// Web URL to redirect to if app is not installed
    public let originalUrl: String?
    /// In-app path/route to navigate to
    public let deepLinkPath: String
    /// Additional parameters for deep linking
    public let deepLinkParams: [String: String]?
    /// When the link expires (if set)
    public let expiresAt: Date?
    /// When the link was created
    public let createdAt: Date
    /// When the link was last updated
    public let updatedAt: Date
    /// Complete URL for this link
    public let fullUrl: String
}