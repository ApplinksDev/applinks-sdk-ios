import Foundation

/// Request model for creating a new link
internal struct CreateLinkRequest: Encodable {
    let domain: String
    let link: LinkData
    
    struct LinkData: Encodable {
        let title: String
        let subtitle: String?
        let originalUrl: String?
        let deepLinkPath: String?
        let deepLinkParams: [String: String]?
        let expiresAt: Date?
        let aliasPathAttributes: AliasPathAttributes?
        let backgroundType: String?
        let backgroundColor: String?
        let backgroundColorFrom: String?
        let backgroundColorTo: String?
        let backgroundColorDirection: String?
        
        enum CodingKeys: String, CodingKey {
            case title
            case subtitle
            case originalUrl = "original_url"
            case deepLinkPath = "deep_link_path"
            case deepLinkParams = "deep_link_params"
            case expiresAt = "expires_at"
            case aliasPathAttributes = "alias_path_attributes"
            case backgroundType = "background_type"
            case backgroundColor = "background_color"
            case backgroundColorFrom = "background_color_from"
            case backgroundColorTo = "background_color_to"
            case backgroundColorDirection = "background_color_direction"
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