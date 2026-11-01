import Foundation

/// Response of the attributions endpoints (POST and PATCH)
internal struct AttributionResponse: Decodable {
    let attributionId: String
    let matched: Bool?
    
    enum CodingKeys: String, CodingKey {
        case attributionId = "attribution_id"
        case matched
    }
}

/// Outcome of an attribution request
internal enum AttributionApiResult: Equatable {
    /// 201, or 200 (already reported, or updated)
    case success(attributionId: String)
    /// Network error, timeout, 5xx, 408 or 429: worth trying again later
    case retryLater(String)
    /// Any other answer: trying again would get the same one
    case rejected(statusCode: Int, message: String)
}
