import Foundation

/// Request model for creating a new link
internal struct CreateLinkRequest: Encodable {
    let domain: String
    let link: LinkData
    
    struct LinkData: Encodable {
        let title: String
        let originalUrl: String?
        let deepLinkPath: String?
        let deepLinkParams: [String: String]?
        let expiresAt: Date?
        let aliasPathAttributes: AliasPathAttributes?
        
        enum CodingKeys: String, CodingKey {
            case title
            case originalUrl = "original_url"
            case deepLinkPath = "deep_link_path"
            case deepLinkParams = "deep_link_params"
            case expiresAt = "expires_at"
            case aliasPathAttributes = "alias_path_attributes"
        }
    }
    
    struct AliasPathAttributes: Encodable {
        let type: PathType
        
        enum PathType: String, Encodable {
            case unguessable = "UNGUESSABLE"
            case short = "SHORT"
        }
    }
}