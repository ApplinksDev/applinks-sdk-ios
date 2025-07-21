import Foundation

/// Public API for creating shortened links
public class LinkShortener {
    private let apiClient: AppLinksApiClient
    private let logger = AppLinksSDKLogger.shared.withCategory("link-shortener")
    
    internal init(apiClient: AppLinksApiClient) {
        self.apiClient = apiClient
    }
    
    /// Create a new shortened link using parameters struct
    /// - Parameter params: Link creation parameters
    /// - Returns: Created link details
    public func createLink(_ params: LinkCreationParams) async throws -> CreatedLink {
        logger.debug("[AppLinksSDK] Creating link with title: \(params.title)")
        
        // Build the request
        let linkData = CreateLinkRequest.LinkData(
            title: params.title,
            originalUrl: params.webLink,
            deepLinkPath: params.deepLinkPath,
            deepLinkParams: params.deepLinkParams,
            expiresAt: params.expiresAt,
            aliasPathAttributes: CreateLinkRequest.AliasPathAttributes(
                type: params.linkType.toInternalType()
            )
        )
        
        // Make the API call
        let response = try await apiClient.createLink(domain: params.domain, linkData: linkData)
        
        // Convert to public model
        return CreatedLink(
            id: response.id,
            title: response.title,
            aliasPath: response.aliasPath,
            domain: response.domain,
            webLink: response.originalUrl,
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

/// Type of link to generate
public enum LinkType {
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

/// Parameters for creating a shortened link
public struct LinkCreationParams {
    /// The domain to create the link on
    public let domain: String
    /// Title for the link
    public let title: String
    /// The in-app path/route to navigate to
    public let deepLinkPath: String
    /// The web URL to redirect to if app is not installed
    public let webLink: String?
    /// Additional parameters for deep linking
    public let deepLinkParams: [String: String]?
    /// Optional expiration date for the link
    public let expiresAt: Date?
    /// Type of link to generate (unguessable or short)
    public let linkType: LinkType
    
    /// Initialize with all parameters
    public init(
        domain: String,
        title: String,
        deepLinkPath: String,
        webLink: String? = nil,
        deepLinkParams: [String: String]? = nil,
        expiresAt: Date? = nil,
        linkType: LinkType = .unguessable
    ) {
        self.domain = domain
        self.title = title
        self.deepLinkPath = deepLinkPath
        self.webLink = webLink
        self.deepLinkParams = deepLinkParams
        self.expiresAt = expiresAt
        self.linkType = linkType
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
    public let webLink: String?
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