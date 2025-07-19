import Foundation

extension JSONDecoder.DateDecodingStrategy {
    /// Custom date decoding strategy that handles Rails ISO8601 dates with fractional seconds
    static let railsISO8601 = custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Try different date formats that Rails might produce
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ", // With milliseconds and timezone
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",     // Without milliseconds, with timezone
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",   // With milliseconds, UTC
            "yyyy-MM-dd'T'HH:mm:ss'Z'",       // Without milliseconds, UTC
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",     // Legacy format with milliseconds
            "yyyy-MM-dd'T'HH:mm:ssZ"          // Legacy format without milliseconds
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected date string to be ISO8601-formatted. Got: \(dateString)",
                underlyingError: nil
            )
        )
    }
}

extension JSONEncoder.DateEncodingStrategy {
    /// Custom date encoding strategy that matches Rails ISO8601 format
    static let railsISO8601 = custom { date, encoder in
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        var container = encoder.singleValueContainer()
        try container.encode(formatter.string(from: date))
    }
}