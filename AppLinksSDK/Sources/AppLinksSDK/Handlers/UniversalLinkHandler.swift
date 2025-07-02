import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Handler for Universal Links (iOS 9+)
internal class UniversalLinkHandler: LinkHandler {
    private let supportedDomains: Set<String>
    private let autoHandleLinks: Bool
    private let enableLogging: Bool
    
    var priority: Int { 100 }
    
    init(supportedDomains: Set<String>, autoHandleLinks: Bool, enableLogging: Bool) {
        self.supportedDomains = supportedDomains
        self.autoHandleLinks = autoHandleLinks
        self.enableLogging = enableLogging
    }
    
    func canHandle(url: URL) -> Bool {
        // Check if URL uses http/https scheme
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return false
        }
        
        // Check if domain is supported
        guard let host = url.host?.lowercased() else {
            return false
        }
        
        // Check exact domain match or wildcard subdomain match
        let canHandle = supportedDomains.contains { domain in
            if domain == host {
                return true
            }
            
            // Check wildcard subdomain (*.example.com)
            if domain.hasPrefix("*.") {
                let baseDomain = String(domain.dropFirst(2))
                return host.hasSuffix(baseDomain) && host.count > baseDomain.count
            }
            
            return false
        }
        
        if enableLogging && canHandle {
            print("[UniversalLinkHandler] Can handle URL: \(url)")
        }
        
        return canHandle
    }
    
    func handle(url: URL) async throws -> LinkHandlingResult {
        if enableLogging {
            print("[UniversalLinkHandler] Handling URL: \(url)")
        }
        
        // Extract metadata from URL
        var metadata: [String: String] = [
            "type": "universal_link",
            "domain": url.host ?? "",
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
        
        // Auto-handle if enabled
        if autoHandleLinks {
            await handleNavigation(url: url)
        }
        
        return LinkHandlingResult(
            handled: true,
            url: url,
            metadata: metadata
        )
    }
    
    private func handleNavigation(url: URL) async {
        await MainActor.run {
            if enableLogging {
                print("[UniversalLinkHandler] Auto-handling navigation for: \(url)")
            }
            
            // In a real implementation, this would navigate to the appropriate
            // view controller or SwiftUI view based on the URL
            // For now, we'll just open the URL if possible
            #if canImport(UIKit)
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            #endif
        }
    }
}
