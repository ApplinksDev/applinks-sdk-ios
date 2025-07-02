import Foundation

/// Manages multiple link handlers and routes links to appropriate handlers
internal class LinkHandlingManager {
    private var handlers: [LinkHandler] = []
    private let config: AppLinksConfig
    private let enableLogging: Bool
    
    init(config: AppLinksConfig, enableLogging: Bool) {
        self.config = config
        self.enableLogging = enableLogging
    }
    
    /// Add a new link handler
    func addHandler(_ handler: LinkHandler) {
        handlers.append(handler)
        // Sort by priority (highest first)
        handlers.sort { $0.priority > $1.priority }
        
        if enableLogging {
            print("[LinkHandlingManager] Added handler with priority \(handler.priority)")
        }
    }
    
    /// Handle a link by finding appropriate handler
    func handleLink(_ url: URL) async throws -> LinkHandlingResult {
        if enableLogging {
            print("[LinkHandlingManager] Attempting to handle URL: \(url)")
        }
        
        // Find the first handler that can handle this URL
        for handler in handlers {
            if handler.canHandle(url: url) {
                do {
                    let result = try await handler.handle(url: url)
                    
                    if result.handled {
                        if enableLogging {
                            print("[LinkHandlingManager] URL handled successfully by \(type(of: handler))")
                        }
                        return result
                    }
                } catch {
                    if enableLogging {
                        print("[LinkHandlingManager] Handler \(type(of: handler)) failed: \(error)")
                    }
                    // Continue to next handler
                }
            }
        }
        
        if enableLogging {
            print("[LinkHandlingManager] No handler found for URL: \(url)")
        }
        
        // No handler found
        return LinkHandlingResult(
            handled: false,
            url: url,
            error: "No handler found for URL"
        )
    }
    
    /// Get all registered handlers
    var registeredHandlers: [LinkHandler] {
        handlers
    }
    
    /// Remove all handlers
    func removeAllHandlers() {
        handlers.removeAll()
    }
}