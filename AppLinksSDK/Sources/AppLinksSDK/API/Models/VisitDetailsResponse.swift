import Foundation

/// Response model for visit details
internal struct VisitDetailsResponse: Codable {
    let id: String
    let createdAt: String
    let updatedAt: String
    let lastSeenAt: String
    let expiresAt: String
    let ipAddress: String
    let userAgent: String
    let browserFingerprint: AnyCodable?
    let link: LinkResponse?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastSeenAt = "last_seen_at"
        case expiresAt = "expires_at"
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case browserFingerprint = "browser_fingerprint"
        case link
    }
}

/// Type-erased Codable wrapper for handling unknown JSON types
internal struct AnyCodable: Codable {
    let value: Any?
    
    init(_ value: Any?) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = nil
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            self.value = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case nil:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any?]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any?]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

/// Error response model
internal struct ErrorResponse: Codable {
    let error: ErrorDetails
}

internal struct ErrorDetails: Codable {
    let status: String
    let code: Int
    let message: String
}