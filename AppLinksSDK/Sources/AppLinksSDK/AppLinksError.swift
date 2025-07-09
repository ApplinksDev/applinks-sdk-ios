import Foundation

// MARK: - Errors

enum AppLinksError: LocalizedError {
    case invalidResponse
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}