import Foundation

/// Handler for custom URL schemes
internal class CustomSchemeHandler: LinkHandler {
    private let supportedSchemes: Set<String>
    private let autoHandleLinks: Bool
    private let enableLogging: Bool
    
    var priority: Int { 90 }
    
    init(supportedSchemes: Set<String>, autoHandleLinks: Bool, enableLogging: Bool) {
        self.supportedSchemes = supportedSchemes
        self.autoHandleLinks = autoHandleLinks
        self.enableLogging = enableLogging
    }
    
    func canHandle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        
        let canHandle = supportedSchemes.contains(scheme)
        
        if enableLogging && canHandle {
            print("[CustomSchemeHandler] Can handle URL: \(url)")
        }
        
        return canHandle
    }
    
    func handle(url: URL) async throws -> LinkHandlingResult {
        if enableLogging {
            print("[CustomSchemeHandler] Handling URL: \(url)")
        }
        
        // Extract metadata from URL
        var metadata: [String: String] = [
            "type": "custom_scheme",
            "scheme": url.scheme ?? "",
            "host": url.host ?? "",
            "path": url.path
        ]
        
        // Extract query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value {
                    metadata["param_\(item.name)"] = value
                }
            }
        }
        
        // Parse path components for common patterns
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        if !pathComponents.isEmpty {
            metadata["action"] = pathComponents.first
            
            // Common patterns: myapp://product/123, myapp://user/profile
            if pathComponents.count > 1 {
                metadata["target"] = pathComponents[1]
            }
        }
        
        // Auto-handle if enabled
        if autoHandleLinks {
            await handleNavigation(url: url, metadata: metadata)
        }
        
        return LinkHandlingResult(
            handled: true,
            url: url,
            metadata: metadata
        )
    }
    
    private func handleNavigation(url: URL, metadata: [String: String]) async {
        await MainActor.run {
            if enableLogging {
                print("[CustomSchemeHandler] Auto-handling navigation for: \(url)")
            }
            
            // In a real implementation, this would navigate based on the URL structure
            // For example:
            // - myapp://product/123 -> Navigate to product view with ID 123
            // - myapp://promo/summer -> Navigate to promo view with code "summer"
            // - myapp://home -> Navigate to home view
            
            // For now, we'll post a notification that the app can observe
            NotificationCenter.default.post(
                name: Notification.Name("AppLinksCustomSchemeHandled"),
                object: nil,
                userInfo: [
                    "url": url,
                    "metadata": metadata
                ]
            )
        }
    }
}
