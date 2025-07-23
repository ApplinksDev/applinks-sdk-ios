//
//  SchemeMiddleware.swift
//  AppLinksSDK
//
//  Created by Maxence Henneron on 7/7/25.
//

import Foundation
import OSLog

internal class SchemeMiddleware: LinkMiddleware {
    private var supportedSchemes: Set<String> = []
    private let logger = AppLinksSDKLogger.shared.withCategory("scheme-middleware")

    internal init(
        supportedSchemes: Set<String> = []
    ) {
        self.supportedSchemes = supportedSchemes
    }
    
    public func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        if (!canHandle(url: url)) {
            logger.debug("[AppLinksSDK] Cannot handle URL: \(url)")
            return try await next(url, context)
        }
        
        var updatedContext = context
        
        // Extract path (host + path components for custom schemes)
        var pathParts: [String] = []
        
        // Add host as first part of path for custom schemes
        if let host = url.host {
            pathParts.append(host)
        }
        
        // Add path components (excluding "/")
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        pathParts.append(contentsOf: pathComponents)
        
        if !pathParts.isEmpty {
            updatedContext.deepLinkPath = "/" + pathParts.joined(separator: "/")
        }
        
        // Parse query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            var params: [String: String] = [:]
            
            for item in queryItems {
                params[item.name] = item.value ?? ""
            }
            
            updatedContext.deepLinkParams = params
        }
        
        logger.debug("[AppLinksSDK] Parsed scheme URL: \(url)")
        
        return try await next(url, updatedContext)
    }
    
    
    public func canHandle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        
        return supportedSchemes.contains(scheme)
    }
    
}
