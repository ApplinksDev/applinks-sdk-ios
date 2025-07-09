import Foundation
import Combine

/// Main SDK class for AppLinks functionality
public class AppLinksSDK: ObservableObject {
    // MARK: - Singleton
    
    /// Shared instance of AppLinksSDK
    public static var shared: AppLinksSDK {
        guard let instance = _instance else {
            fatalError("AppLinksSDK not initialized. Call AppLinksSDK.initialize() first.")
        }
        return instance
    }
    
    private static var _instance: AppLinksSDK?
    
    //
    public let linkPublisher = PassthroughSubject<LinkHandlingResult, Never>()
    
    // MARK: - Properties
    
    private let config: AppLinksConfig
    private let apiClient: AppLinksApiClient
    private let preferences: AppLinksPreferences
    private var middlewareChain: MiddlewareChain
    private let clipboardManager: ClipboardManager
    private let customMiddleware: [AnyLinkMiddleware]
    private let logger: AppLinksSDKLogger

    // MARK: - Initialization
    
    private init(config: AppLinksConfig, customMiddleware: [AnyLinkMiddleware]) {
        self.config = config
        self.customMiddleware = customMiddleware
        
        // Initialize components
        self.apiClient = AppLinksApiClient(
            serverUrl: config.serverUrl,
            apiKey: config.apiKey
        )
        
        self.preferences = AppLinksPreferences()
        self.middlewareChain = MiddlewareChain(middlewares: [])
        self.clipboardManager = ClipboardManager()
        self.logger = AppLinksSDKLogger.shared.withCategory("core")
        
        setupMiddleware()
        checkForDeferredDeepLinkIfFirstLaunch()
    }
    
    /// Initialize the SDK with named parameters
    @discardableResult
    public static func initialize(
        apiKey: String,
        serverUrl: String = "https://applinks.com",
        autoHandleLinks: Bool = true,
        supportedDomains: Set<String> = [],
        supportedSchemes: Set<String> = [],
        logLevel: AppLinksSDKLogLevel = .info,
        customMiddleware: [AnyLinkMiddleware] = [],
    ) -> AppLinksSDK {
        // Validate API key format
        if apiKey.hasPrefix("sk_") {
            fatalError("Private keys (sk_*) should never be used in mobile applications. Please use a public key (pk_*) instead.")
        }
        if !apiKey.hasPrefix("pk_") && !apiKey.isEmpty {
            print("[AppLinksSDK] Warning: API key should start with 'pk_' for public keys. Current key: \(apiKey.prefix(3))...")
        }
        
        if let existingInstance = _instance {
            print("[AppLinksSDK] Warning: SDK already initialized")
            return existingInstance
        }
        
        let config = AppLinksConfig(
            autoHandleLinks: autoHandleLinks,
            logLevel: logLevel,
            serverUrl: serverUrl,
            apiKey: apiKey,
            supportedDomains: supportedDomains,
            supportedSchemes: supportedSchemes
        )
        
        AppLinksSDKLogger.shared.logLevel = logLevel
        
        let instance = AppLinksSDK(config: config, customMiddleware: customMiddleware)
        _instance = instance
        return instance
    }
    
    // MARK: - Setup
    
    private func setupMiddleware() {
        var middlewares: [AnyLinkMiddleware] = []
        
        // Add Universal Link Middleware if domains are configured
        if !config.supportedDomains.isEmpty {
            let universalLinkMiddleware = UniversalLinkMiddleware(
                supportedDomains: config.supportedDomains,
                apiClient: apiClient
            )
            middlewares.append(AnyLinkMiddleware(universalLinkMiddleware))
        }
        
        // Add Custom Scheme Middleware if schemes are configured
        if !config.supportedSchemes.isEmpty {
            let schemeMiddleware = SchemeMiddleware(
                supportedSchemes: config.supportedSchemes
            )
            middlewares.append(AnyLinkMiddleware(schemeMiddleware))
        }
        
        // Add custom middleware provided via builder
        middlewares.append(contentsOf: customMiddleware)
        
        // Update the middleware chain
        middlewareChain = MiddlewareChain(middlewares: middlewares)
    }
    
    // MARK: - Public Methods
    
    /// Handle an incoming URL
    public func handleLink(_ url: URL) {
        Task {
            do {
                let context = LinkHandlingContext(
                    isFirstLaunch: preferences.isFirstLaunch,
                    launchTimestamp: Date()
                )
                
                let result = try await middlewareChain.execute(
                    url: url,
                    context: context
                ) { finalUrl, finalContext in
                    return LinkHandlingResult(
                        handled: true,
                        originalUrl: url,
                        path: finalContext.deepLinkPath ?? "",
                        params: finalContext.deepLinkParams,
                        metadata: finalContext.additionalData
                    )
                }
                
                // Invoke the callback if available
                linkPublisher.send(result)
            } catch {
                // Create error result and invoke callback
                let errorResult = LinkHandlingResult(
                    handled: false,
                    originalUrl: url,
                    path: "",
                    params: [:],
                    metadata: [:],
                    error: error.localizedDescription
                )
                linkPublisher.send(errorResult)
            }
        }
    }
    
    /// Add a custom middleware
    public func addCustomMiddleware(_ middleware: AnyLinkMiddleware) {
        let currentMiddlewares = middlewareChain.middlewares + [middleware]
        middlewareChain = MiddlewareChain(middlewares: currentMiddlewares)
    }
    
    // MARK: - Deferred Deep Links
    
    private func checkForDeferredDeepLinkIfFirstLaunch() {
        guard preferences.isFirstLaunch else {
            self.logger.debug("[AppLinksSDK] Skipping deferred deep link check - not first launch")
            return
        }
        
        self.logger.info("[AppLinksSDK] First launch detected - checking for deferred deep link")
        
        checkForDeferredDeepLink()
    }
    
    private func checkForDeferredDeepLink() {
        Task {
            let result = await clipboardManager.retrieveDeferredDeepLink()
            
            // Mark first launch as completed
            preferences.markFirstLaunchCompleted()
            
            if let url = result.url {
                self.logger.info("[AppLinksSDK] Deferred deep link retrieved: \(url)")
                
                do {
                    // Handle the retrieved link through middleware
                    let context = LinkHandlingContext(
                        isFirstLaunch: true,
                        launchTimestamp: Date()
                    )
                    
                    let result = try await middlewareChain.execute(url: url, context: context) { finalUrl, finalContext in
                        return LinkHandlingResult(
                            handled: true,
                            originalUrl: url,
                            path: finalContext.deepLinkPath ?? "",
                            params: finalContext.deepLinkParams,
                            metadata: finalContext.additionalData
                        )
                    }
                    
                    // Invoke the callback for deferred deep link
                    linkPublisher.send(result)
                } catch {
                    // Create error result and invoke callback
                    let errorResult = LinkHandlingResult(
                        handled: false,
                        originalUrl: url,
                        path: "",
                        params: [:],
                        metadata: [:],
                        error: error.localizedDescription
                    )
                    linkPublisher.send(errorResult)
                }
            } else {
                self.logger.debug("[AppLinksSDK] No deferred deep link found in clipboard")
            }
        }
    }
}

// MARK: - Public Types

/// Callback for link handling results
public typealias LinkCallback = (String, [String: String]) -> Void
public typealias ErrorCallback = (String) -> Void
