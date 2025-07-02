import Foundation

/// Response model for link data
internal struct LinkResponse: Codable {
    let id: String
    let title: String
    let aliasPath: String
    let domain: String
    let originalUrl: String
    let deepLinkPath: String
    let deepLinkParams: [String: String]
    let expiresAt: String?
    let createdAt: String
    let updatedAt: String
    let fullUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case aliasPath = "alias_path"
        case domain
        case originalUrl = "original_url"
        case deepLinkPath = "deep_link_path"
        case deepLinkParams = "deep_link_params"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case fullUrl = "full_url"
    }
}