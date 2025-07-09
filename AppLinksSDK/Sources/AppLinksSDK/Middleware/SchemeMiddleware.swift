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
        if let query = url.query {
            let queryItems = URLComponents(string: "?" + query)?.queryItems ?? []
            var params: [String: String] = [:]
            var visitId: String?
            
            for item in queryItems {
                if let value = item.value {
                    if item.name == "visit_id" {
                        visitId = value
                    } else {
                        params[item.name] = value
                    }
                }
            }
            
            updatedContext.deepLinkParams = params
            
            // Add visit_id to additionalData if present
            if let visitId = visitId {
                updatedContext.additionalData["visitId"] = visitId
            }
        }
        
        logger.debug("[AppLinksSDK] Parsed scheme URL: \(url)")
        
        return try await next(url, updatedContext)
    }
    
    
    private func canHandle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        
        return supportedSchemes.contains(scheme)
    }
    
}
