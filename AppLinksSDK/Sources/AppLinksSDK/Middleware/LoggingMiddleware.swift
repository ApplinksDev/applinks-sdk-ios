import Foundation
import OSLog

/// Middleware that logs link handling events
public class LoggingMiddleware: LinkMiddleware {
    private let logger: Logger
    private let logLevel: OSLogType
    
    public init(subsystem: String = "com.applinks.sdk", category: String = "LinkHandling", logLevel: OSLogType = .info) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.logLevel = logLevel
    }
    
    public func process(
        url: URL,
        context: LinkHandlingContext,
        next: @escaping (URL, LinkHandlingContext) async throws -> LinkHandlingResult
    ) async throws -> LinkHandlingResult {
        let startTime = Date()
        
        var updatedContext = context
        updatedContext.appLinksLogLevel = logLevel
        
        logger.log(level: logLevel, "Starting link processing: \(url.absoluteString, privacy: .public)")
        logger.log(level: .debug, "Context: isFirstLaunch=\(context.isFirstLaunch), timestamp=\(context.launchTimestamp)")
        
        do {
            let result = try await next(url, updatedContext)
            let duration = Date().timeIntervalSince(startTime)
            
            if result.handled {
                logger.log(level: logLevel, "Link handled successfully: \(url.absoluteString, privacy: .public) in \(duration)s")
                if !result.metadata.isEmpty {
                    logger.log(level: .debug, "Metadata: \(result.metadata)")
                }
            } else {
                logger.log(level: logLevel, "Link not handled: \(url.absoluteString, privacy: .public)")
            }
            
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.log(level: .error, "Link handling failed: \(url.absoluteString, privacy: .public) after \(duration)s - Error: \(error.localizedDescription)")
            throw error
        }
    }
}
