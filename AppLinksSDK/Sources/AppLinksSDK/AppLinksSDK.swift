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
    
    // MARK: - Publishers
    
    private let _linkPublisher = PassthroughSubject<LinkHandlingResult, Never>()
    private var pendingLinks: [LinkHandlingResult] = []
    private var subscriberCount = 0
    
    /// Publisher for link handling results with queuing support
    public lazy var linkPublisher: AnyPublisher<LinkHandlingResult, Never> = {
        _linkPublisher
            .handleEvents(
                receiveSubscription: { [weak self] _ in
                    self?.onSubscriptionReceived()
                },
                receiveCancel: { [weak self] in
                    self?.onSubscriptionCancelled()
                }
            )
            .eraseToAnyPublisher()
    }()
    
    // MARK: - Properties
    
    private let config: AppLinksConfig
    private let apiClient: AppLinksApiClient
    private let preferences: AppLinksPreferences
    private var middlewareChain: MiddlewareChain
    private let clipboardManager: ClipboardManager
    private let customMiddleware: [AnyLinkMiddleware]
    private let logger: AppLinksSDKLogger
    
    /// Public API for creating shortened links
    public lazy var linkShortener: LinkShortener = LinkShortener(apiClient: apiClient)

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
        deferredDeepLinkingEnabled: Bool = true
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
            supportedSchemes: supportedSchemes,
            deferredDeepLinkingEnabled: deferredDeepLinkingEnabled
        )
        
        AppLinksSDKLogger.shared.logLevel = logLevel
        
        let instance = AppLinksSDK(config: config, customMiddleware: customMiddleware)
        _instance = instance
        
        // Log SDK initialization
        instance.logger.info("[AppLinksSDK] Initialized \(AppLinksSDKVersion.fullName)")
        
        return instance
    }
    
    // MARK: - Setup
    
    private func setupMiddleware() {
        var middlewares: [AnyLinkMiddleware] = [AnyLinkMiddleware(LoggingMiddleware())]
        
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
    
    /// Handles an incoming URL
    /// - Parameters:
    ///   - url: The URL being processed
    /// - Returns: Boolean indicating if the link is being processed by AppLinks.
    public func handleLink(_ url: URL) -> Bool {
        let handlable = middlewareChain.canHandle(url: url)
        if (!handlable) {
            return false
        }
        
        Task {
            do {
                let result = try await processMiddlewareChain(url: url)
                
                // Send result through publisher
                sendLinkResult(result)
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
                sendLinkResult(errorResult)
            }
        }
        
        return true
    }
    
    public func getAppLinkDetails(from url: URL) async -> LinkHandlingResult {
        do {
            return try await processMiddlewareChain(url: url)
        } catch {
            return LinkHandlingResult(
                handled: false,
                originalUrl: url,
                path: "",
                params: [:],
                metadata: [:],
                error: error.localizedDescription
            )
        }
    }
    
    /// Add a custom middleware
    public func addCustomMiddleware(_ middleware: AnyLinkMiddleware) {
        let currentMiddlewares = middlewareChain.middlewares + [middleware]
        middlewareChain = MiddlewareChain(middlewares: currentMiddlewares)
    }
    
    /// Get SDK version information
    public static var version: String {
        return AppLinksSDKVersion.current
    }
    
    /// Get full SDK version information including name
    public static var versionInfo: [String: String] {
        return AppLinksSDKVersion.asDictionary
    }
    
    /// Unified deferred deep link processor - handles both automatic and manual flows
    /// - Parameter markFirstLaunch: Whether to mark the first launch as completed
    /// - Returns: LinkHandlingResult if a deferred deep link is found, nil otherwise
    private func processDeferredDeepLink(markFirstLaunch: Bool) async -> LinkHandlingResult? {
        let result = await clipboardManager.retrieveDeferredDeepLink()
        
        if markFirstLaunch {
            preferences.markFirstLaunchCompleted()
        }
        
        guard let url = result.url else {
            logger.debug("[AppLinksSDK] No deferred deep link found")
            return nil
        }
        
        logger.info("[AppLinksSDK] Deferred deep link found: \(url)")
        
        do {
            let linkResult = try await processMiddlewareChain(url: url)
            return linkResult
        } catch {
            logger.error("[AppLinksSDK] Error processing deferred deep link: \(error)")
            return LinkHandlingResult(
                handled: false,
                originalUrl: url,
                path: "",
                params: [:],
                metadata: [:],
                error: error.localizedDescription
            )
        }
    }
    
    /// Manually check for deferred deep links
    /// - Returns: LinkHandlingResult if a deferred deep link is found, nil otherwise
    public func checkForDeferredDeepLink() async -> LinkHandlingResult? {
        return await processDeferredDeepLink(markFirstLaunch: false)
    }
    
    // MARK: - Deferred Deep Links
    
    private func checkForDeferredDeepLinkIfFirstLaunch() {
        guard preferences.isFirstLaunch else {
            self.logger.debug("[AppLinksSDK] Skipping deferred deep link check - not first launch")
            return
        }
        
        guard config.deferredDeepLinkingEnabled else {
            self.logger.info("[AppLinksSDK] Deferred deep linking disabled - skipping check")
            preferences.markFirstLaunchCompleted()
            return
        }
        
        self.logger.info("[AppLinksSDK] First launch detected - checking for deferred deep link")
        Task {
            if let result = await processDeferredDeepLink(markFirstLaunch: true) {
                sendLinkResult(result)
            }
        }
    }
    
    // MARK: - Link Queue Management
    
    private func sendLinkResult(_ result: LinkHandlingResult) {
        if subscriberCount > 0 {
            _linkPublisher.send(result)
        } else {
            // Queue the link for when subscribers become available
            pendingLinks.append(result)
            logger.debug("[AppLinksSDK] Queued link result - no active subscribers")
        }
    }
    
    private func onSubscriptionReceived() {
        subscriberCount += 1
        
        // Send all pending links to the first subscriber only
        // We use async to ensure the subscription is fully established
        if subscriberCount == 1 && !pendingLinks.isEmpty {
            let linksToSend = pendingLinks
            pendingLinks.removeAll()
            
            DispatchQueue.main.async { [weak self] in
                guard let self: AppLinksSDK = self else { return }
                for pendingLink in linksToSend {
                    self._linkPublisher.send(pendingLink)
                }
                self.logger.info("[AppLinksSDK] Delivered \(linksToSend.count) queued link(s) to first subscriber")
            }
        }
    }
    
    private func onSubscriptionCancelled() {
        subscriberCount = max(0, subscriberCount - 1)
    }
    
    // MARK: Middleware chain processing
    private func processMiddlewareChain(url: URL) async throws -> LinkHandlingResult {
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
        
        return result
    }
}

// MARK: - Public Types

/// Callback for link handling results
public typealias LinkCallback = (String, [String: String]) -> Void
public typealias ErrorCallback = (String) -> Void
