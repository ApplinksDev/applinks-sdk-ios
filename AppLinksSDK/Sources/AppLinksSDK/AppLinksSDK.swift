import Foundation
import Combine
import UIKit

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
    private let attributionManager: AttributionManager?
    private let notificationCenter: NotificationCenter
    private var didBecomeActiveObserver: NSObjectProtocol?
    
    /// Public API for creating shortened links
    public lazy var linkShortener: LinkShortener = LinkShortener(apiClient: apiClient)

    // MARK: - Initialization
    
    /// The dependencies can be replaced for tests
    internal init(
        config: AppLinksConfig,
        customMiddleware: [AnyLinkMiddleware],
        preferences: AppLinksPreferences = AppLinksPreferences(),
        clipboardManager: ClipboardManager = ClipboardManager(),
        urlSession: URLSession? = nil,
        attributionDeviceInfo: AttributionDeviceInfo = SystemAttributionDeviceInfo(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.config = config
        self.customMiddleware = customMiddleware
        
        // Initialize components
        self.apiClient = AppLinksApiClient(
            serverUrl: config.serverUrl,
            apiKey: config.apiKey,
            session: urlSession
        )
        
        self.preferences = preferences
        self.middlewareChain = MiddlewareChain(middlewares: [])
        self.clipboardManager = clipboardManager
        self.logger = AppLinksSDKLogger.shared.withCategory("core")
        self.notificationCenter = notificationCenter
        
        if config.installAttributionEnabled, let apiKey = config.apiKey, !apiKey.isEmpty {
            self.attributionManager = AttributionManager(
                apiClient: apiClient,
                preferences: preferences,
                deviceInfo: attributionDeviceInfo
            )
        } else {
            self.attributionManager = nil
        }
        
        setupMiddleware()
        setupInstallAttribution()
        checkForDeferredDeepLinkIfFirstLaunch()
    }
    
    deinit {
        if let observer = didBecomeActiveObserver {
            notificationCenter.removeObserver(observer)
        }
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
        deferredDeepLinkingEnabled: Bool = true,
        installAttributionEnabled: Bool = true
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
            deferredDeepLinkingEnabled: deferredDeepLinkingEnabled,
            installAttributionEnabled: installAttributionEnabled
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
    
    private func setupInstallAttribution() {
        guard let attributionManager = attributionManager else { return }
        
        // A fresh install: it's reported after the first deferred deep link
        // lookup. Kept apart from the first launch flag, which is set before
        // the report is sent.
        if preferences.isFirstLaunch && preferences.attributionId == nil {
            preferences.installReportDue = true
        }
        
        // Retry a report that failed, send an app or OS update
        attributionManager.trigger()
        
        // The user may have changed their tracking choice (the ATT prompt, or Settings)
        didBecomeActiveObserver = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            attributionManager.trigger()
        }
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
    
    // MARK: - Install Attribution
    
    /// The attribution Applinks recorded for this install, nil until the
    /// install was reported. Pass it to your backend, which reports the
    /// user's conversions with POST /api/v1/conversions and its private key.
    public var attributionId: String? {
        preferences.attributionId
    }
    
    /// Set the user's consent to ad measurement. Call it whenever your app's
    /// consent prompt or privacy settings change it. Until it's called, the
    /// install is reported without consent, so nothing is sent to ad networks.
    /// - Parameters:
    ///   - adsConsent: Whether your consent prompt allowed ad measurement
    ///     (true where no prompt is required)
    ///   - limitedDataUse: Whether the user opted out of sharing under US
    ///     state privacy laws
    public func updateConsent(adsConsent: Bool, limitedDataUse: Bool = false) {
        preferences.adsConsent = adsConsent
        preferences.limitedDataUse = limitedDataUse
        attributionManager?.trigger()
    }
    
    /// Set the IDFA, which your app reads itself, only once the user allowed
    /// tracking. The SDK never reads it. Pass nil to remove it.
    public func setAdvertisingId(_ advertisingId: String?) {
        let advertisingId = advertisingId?.trimmingCharacters(in: .whitespacesAndNewlines)
        preferences.advertisingId = advertisingId?.isEmpty == false ? advertisingId : nil
        attributionManager?.trigger()
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
        
        // The install report waits for this lookup. It's sent alongside the
        // deep link, which doesn't wait for it.
        attributionManager?.recordInstallLookup(url: result.url)
        
        if markFirstLaunch {
            preferences.markFirstLaunchCompleted()
        }
        
        guard let url = result.url else {
            logger.debug("[AppLinksSDK] No deferred deep link found")
            return nil
        }
        
        logger.info("[AppLinksSDK] Deferred deep link found: \(url)")
        
        do {
            let linkResult = try await processMiddlewareChain(url: url, chain: deferredDeepLinkChain(for: url))
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
    
    /// With the project's "https" clipboard format, the link page copies the
    /// link's own URL with its click ID. It's resolved like a universal link,
    /// even when its domain isn't one of the supportedDomains.
    private func deferredDeepLinkChain(for url: URL) -> MiddlewareChain {
        guard !middlewareChain.canHandle(url: url),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host?.lowercased(),
              ClickId.extract(from: url.absoluteString) != nil else {
            return middlewareChain
        }
        
        let clipboardLinkMiddleware = UniversalLinkMiddleware(supportedDomains: [host], apiClient: apiClient)
        return MiddlewareChain(middlewares: middlewareChain.middlewares + [AnyLinkMiddleware(clipboardLinkMiddleware)])
    }
    
    // MARK: Middleware chain processing
    private func processMiddlewareChain(url: URL, chain: MiddlewareChain? = nil) async throws -> LinkHandlingResult {
        let context = LinkHandlingContext(
            isFirstLaunch: preferences.isFirstLaunch,
            launchTimestamp: Date()
        )
        
        let result = try await (chain ?? middlewareChain).execute(
            url: url,
            context: context
        ) { finalUrl, finalContext in
            return LinkHandlingResult(
                handled: true,
                originalUrl: url,
                path: finalContext.deepLinkPath ?? "",
                // The click ID the link page added is for the install report
                params: ClickId.removingClickId(from: finalContext.deepLinkParams),
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
