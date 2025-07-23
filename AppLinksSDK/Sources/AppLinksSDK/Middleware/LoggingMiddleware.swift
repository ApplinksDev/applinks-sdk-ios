import Foundation
import OSLog

/// Middleware that logs link handling events
public class LoggingMiddleware: LinkMiddleware {
    private let logger = AppLinksSDKLogger.shared.withCategory("logging-middleware")
    
    public func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        let startTime = Date()
                
        logger.debug("[AppLinksSDK] Starting link processing: \(url.absoluteString)")
        logger.debug("[AppLinksSDK] Context: isFirstLaunch=\(context.isFirstLaunch), timestamp=\(context.launchTimestamp)")
        
        do {
            let result = try await next(url, context)
            let duration = Date().timeIntervalSince(startTime)
            
            if result.handled {
                logger.debug("[AppLinksSDK] Link handled successfully: \(url.absoluteString) in \(duration)s")
                if !result.metadata.isEmpty {
                    logger.debug("[AppLinksSDK] Metadata: \(result.metadata)")
                }
            } else {
                logger.debug("[AppLinksSDK] Link not handled: \(url.absoluteString)")
            }
            
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.error("[AppLinksSDK] Link handling failed: \(url.absoluteString) after \(duration)s - Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func canHandle(url: URL) -> Bool {
        /// Middleware does not handle links, only does logging.
        return false
    }
}
