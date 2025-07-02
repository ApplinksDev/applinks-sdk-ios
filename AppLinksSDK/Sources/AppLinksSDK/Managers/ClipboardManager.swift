import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Result from clipboard retrieval
internal struct ClipboardResult {
    let url: URL?
    let metadata: [String: String]
}

/// Manages clipboard-based deferred deep links
internal class ClipboardManager {
    private let apiClient: AppLinksApiClient
    private let preferences: AppLinksPreferences
    private let enableLogging: Bool
    
    // Clipboard patterns
    private let visitIdPath = "/visit/([a-zA-Z0-9\\-]+)"
    
    init(
        apiClient: AppLinksApiClient,
        preferences: AppLinksPreferences,
        enableLogging: Bool
    ) {
        self.apiClient = apiClient
        self.preferences = preferences
        self.enableLogging = enableLogging
    }
    
    /// Retrieve deferred deep link from clipboard
    func retrieveDeferredDeepLink() async throws -> ClipboardResult {
        // Check clipboard for AppLinks content
        guard hasUrlOnClipboard(),
              let clipboardContent = UIPasteboard.general.string else {
            if enableLogging {
                print("[ClipboardManager] No content in clipboard")
            }
            return ClipboardResult(url: nil, metadata: [:])
        }
        
        // Parse clipboard for visit ID
        let visitId = extractVisitId(from: clipboardContent)
        
        guard let visitId = visitId else {
            if enableLogging {
                print("[ClipboardManager] No AppLinks visit ID found in clipboard")
            }
            return ClipboardResult(url: nil, metadata: [:])
        }
        
        // Check if we've already processed this visit ID
        if preferences.hasVisitId(visitId) {
            if enableLogging {
                print("[ClipboardManager] Visit ID \(visitId) already processed, skipping")
            }
            throw AppLinksError.visitAlreadyProcessed
        }
        
        if enableLogging {
            print("[ClipboardManager] Found visit ID in clipboard: \(visitId)")
        }
        
        // Fetch link details from server
        let visitDetails = try await apiClient.fetchVisitDetails(visitId: visitId)
        
        guard let linkData = visitDetails.link else {
            throw AppLinksError.noLinkDataInVisit
        }
        
        // Check if link is expired
        if isLinkExpired(linkData.expiresAt) {
            throw AppLinksError.linkExpired
        }
        
        // Build the deep link URL
        let deepLinkUrl: URL
        if linkData.deepLinkPath.contains("://") {
            deepLinkUrl = URL(string: linkData.deepLinkPath)!
        } else {
            deepLinkUrl = URL(string: linkData.originalUrl)!
        }
        
        // Build metadata
        var metadata: [String: String] = [
            "source": "clipboard",
            "visitId": visitDetails.id,
            "linkTitle": linkData.title
        ]
        
        // Add any deep link parameters
        for (key, value) in linkData.deepLinkParams {
            metadata[key] = value
        }
        
        // Store visit ID
        preferences.addVisitId(visitDetails.id)
        
        // Clear clipboard to prevent re-processing
        clearClipboard()
        
        if enableLogging {
            print("[ClipboardManager] Successfully retrieved deferred deep link: \(deepLinkUrl)")
        }
        
        return ClipboardResult(url: deepLinkUrl, metadata: metadata)
    }
    
    // MARK: - Private Methods
    func buildVisitIdRegex(supportedDomains: Set<String>, supportedSchemes: Set<String>) -> NSRegularExpression? {
        var matchers: [String] = []

        if !supportedDomains.isEmpty {
            let escapedDomains = supportedDomains
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "|")
            matchers.append("https://(?:\(escapedDomains))")
        }

        if !supportedSchemes.isEmpty {
            let escapedSchemes = supportedSchemes
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "|")
            matchers.append("(?:\(escapedSchemes))://")
        }

        // If no valid matchers, there's nothing to build
        guard !matchers.isEmpty else {
            return nil
        }

        let schemeOrDomain = matchers.joined(separator: "|")

        let pattern = """
        (?x) # verbose mode
        (?:\(schemeOrDomain))\(visitIdPath)
        """

        return try? NSRegularExpression(pattern: pattern, options: [.allowCommentsAndWhitespace])
    }
    
    private func extractVisitId(from content: String) -> String? {
        // Try to match the visit ID pattern
        if let regex = try? buildVisitIdRegex(supportedDomains: [], supportedSchemes: []) {
            let matches = regex.matches(
                in: content,
                options: [],
                range: NSRange(content.startIndex..., in: content)
            )
            
            if let match = matches.first,
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range])
            }
        }
        
        // Alternative: Check if the entire content is a visit ID
        if isValidUUID(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func isValidUUID(_ string: String) -> Bool {
        return UUID(uuidString: string) != nil
    }
    
    private func isLinkExpired(_ expiresAt: String?) -> Bool {
        guard let expiresAt = expiresAt else { return false }
        
        let formatter = ISO8601DateFormatter()
        guard let expiryDate = formatter.date(from: expiresAt) else { return false }
        
        return expiryDate < Date()
    }
    
    private func clearClipboard() {
        // Only clear if clipboard contains AppLinks content
        UIPasteboard.general.string = ""
        if enableLogging {
            print("[ClipboardManager] Cleared AppLinks content from clipboard")
        }
    }
  
    private func hasUrlOnClipboard() -> Bool {
        #if !os(tvOS)
        return UIPasteboard.general.hasURLs
        #else
        return false
        #endif
    }
}

// MARK: - Errors

enum AppLinksError: LocalizedError {
    case visitAlreadyProcessed
    case noLinkDataInVisit
    case linkExpired
    case invalidResponse
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .visitAlreadyProcessed:
            return "Visit ID already processed"
        case .noLinkDataInVisit:
            return "No link data found in visit"
        case .linkExpired:
            return "Link has expired"
        case .invalidResponse:
            return "Invalid server response"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
