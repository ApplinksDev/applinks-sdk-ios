//
//  UniversalLinkMiddleware.swift
//  AppLinksSDK
//
//  Created by Maxence Henneron on 7/3/25.
//
import Foundation
import OSLog

/**
 * Handles link that were opened directly without going to the browser.
 * This happens when the user clicks on a link when the app is already installed
 */
internal class UniversalLinkMiddleware: LinkMiddleware {
    private let supportedDomains: Set<String>
    private let apiClient: AppLinksApiClient
    private let logger = Logger(subsystem: "com.applinks.sdk", category: "UniversalLinkMiddleware")
    
    internal init(supportedDomains: Set<String>, apiClient: AppLinksApiClient) {
        self.supportedDomains = supportedDomains
        self.apiClient = apiClient
    }
    
    public func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        if (!canHandle(url: url)) {
            logger.log(level: .debug, "[UniversalLinkHandler] Cannot handle URL: \(url)")
            return try await next(url, context)
        }
        
        do {
            let linkRetrievalResponse = try await apiClient.retrieveLink(url: url.absoluteString)
            
            var updatedContext = context
            updatedContext.deepLinkPath = linkRetrievalResponse.link.deepLinkPath
            updatedContext.deepLinkParams = linkRetrievalResponse.link.deepLinkParams
            updatedContext.additionalData["visitId"] = linkRetrievalResponse.visitId
            
            logger.log(level: context.appLinksLogLevel, "[UniversalLinkHandler] Retrieved link: \(url)")
            
            return try await next(url, updatedContext)
        } catch {
            logger.log(level: .debug, "[UniversalLinkHandler] Failed to retrieve link: \(error)")
            return try await next(url, context)
        }
    }
    
    private func canHandle(url: URL) -> Bool {
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
                
        return canHandle
    }
    
}
