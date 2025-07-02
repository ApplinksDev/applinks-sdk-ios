import Foundation

/// Main SDK class for AppLinks functionality
public class AppLinksSDK {
    // MARK: - Singleton
    
    /// Shared instance of AppLinksSDK
    public static var shared: AppLinksSDK {
        guard let instance = _instance else {
            fatalError("AppLinksSDK not initialized. Call AppLinksSDK.initialize() first.")
        }
        return instance
    }
    
    private static var _instance: AppLinksSDK?
    
    // MARK: - Properties
    
    private let config: AppLinksConfig
    private let apiClient: AppLinksApiClient
    private let preferences: AppLinksPreferences
    private let linkHandlingManager: LinkHandlingManager
    private let clipboardManager: ClipboardManager
    private let customHandlers: [LinkHandler]
    
    // MARK: - Initialization
    
    private init(config: AppLinksConfig, customHandlers: [LinkHandler]) {
        self.config = config
        self.customHandlers = customHandlers
        
        // Initialize components
        self.apiClient = AppLinksApiClient(
            serverUrl: config.serverUrl,
            apiKey: config.apiKey,
            enableLogging: config.enableLogging
        )
        
        self.preferences = AppLinksPreferences()
        self.linkHandlingManager = LinkHandlingManager(config: config, enableLogging: config.enableLogging)
        self.clipboardManager = ClipboardManager(
            apiClient: apiClient,
            preferences: preferences,
            enableLogging: config.enableLogging
        )
        
        setupHandlers()
        checkForDeferredDeepLinkIfFirstLaunch()
    }
    
    /// Initialize the SDK with named parameters
    @discardableResult
    public static func initialize(
        apiKey: String,
        serverUrl: String = "https://applinks.com",
        autoHandleLinks: Bool = true,
        enableLogging: Bool = true,
        supportedDomains: Set<String> = [],
        supportedSchemes: Set<String> = [],
        customHandlers: [LinkHandler] = []
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
            enableLogging: enableLogging,
            serverUrl: serverUrl,
            apiKey: apiKey,
            supportedDomains: supportedDomains,
            supportedSchemes: supportedSchemes
        )
        
        let instance = AppLinksSDK(config: config, customHandlers: customHandlers)
        _instance = instance
        return instance
    }
    
    /// Initialize the SDK with a configuration object
    @discardableResult
    public static func initialize(config: AppLinksConfig, customHandlers: [LinkHandler] = []) -> AppLinksSDK {
        // Validate API key format
        if let apiKey = config.apiKey {
            if apiKey.hasPrefix("sk_") {
                fatalError("Private keys (sk_*) should never be used in mobile applications. Please use a public key (pk_*) instead.")
            }
            if !apiKey.hasPrefix("pk_") && !apiKey.isEmpty {
                print("[AppLinksSDK] Warning: API key should start with 'pk_' for public keys. Current key: \(apiKey.prefix(3))...")
            }
        }
        
        if let existingInstance = _instance {
            print("[AppLinksSDK] Warning: SDK already initialized")
            return existingInstance
        }
        
        let instance = AppLinksSDK(config: config, customHandlers: customHandlers)
        _instance = instance
        return instance
    }
    
    // MARK: - Setup
    
    private func setupHandlers() {
        // Add Universal Link Handler if domains are configured
        if !config.supportedDomains.isEmpty {
            linkHandlingManager.addHandler(
                UniversalLinkHandler(
                    supportedDomains: config.supportedDomains,
                    autoHandleLinks: config.autoHandleLinks,
                    enableLogging: config.enableLogging
                )
            )
        }
        
        // Add Custom Scheme Handler if schemes are configured
        if !config.supportedSchemes.isEmpty {
            linkHandlingManager.addHandler(
                CustomSchemeHandler(
                    supportedSchemes: config.supportedSchemes,
                    autoHandleLinks: config.autoHandleLinks,
                    enableLogging: config.enableLogging
                )
            )
        }
        
        // Add custom handlers provided via builder
        customHandlers.forEach { handler in
            linkHandlingManager.addHandler(handler)
        }
    }
    
    // MARK: - Public Methods
    
    /// Handle an incoming URL
    public func handleLink(
        _ url: URL,
        onSuccess: @escaping (String, [String: String]) -> Void,
        onError: @escaping (String) -> Void
    ) {
        Task {
            do {
                let result = try await linkHandlingManager.handleLink(url)
                if result.handled {
                    onSuccess(result.url.absoluteString, result.metadata)
                } else {
                    onError(result.error ?? "Link not handled")
                }
            } catch {
                onError(error.localizedDescription)
            }
        }
    }
    
    /// Add a custom link handler
    public func addCustomHandler(_ handler: LinkHandler) {
        linkHandlingManager.addHandler(handler)
    }
    
    // MARK: - Deferred Deep Links
    
    private func checkForDeferredDeepLinkIfFirstLaunch() {
        guard preferences.isFirstLaunch else {
            if config.enableLogging {
                print("[AppLinksSDK] Skipping deferred deep link check - not first launch")
            }
            return
        }
        
        if config.enableLogging {
            print("[AppLinksSDK] First launch detected - checking for deferred deep link")
        }
        
        checkForDeferredDeepLink()
    }
    
    private func checkForDeferredDeepLink() {
        Task {
            do {
                let result = try await clipboardManager.retrieveDeferredDeepLink()
                
                // Mark first launch as completed
                preferences.markFirstLaunchCompleted()
                
                if let url = result.url {
                    if config.enableLogging {
                        print("[AppLinksSDK] Deferred deep link retrieved: \(url)")
                    }
                    
                    // Handle the retrieved link
                    _ = try? await linkHandlingManager.handleLink(url)
                }
            } catch {
                if config.enableLogging {
                    print("[AppLinksSDK] No deferred deep link found: \(error)")
                }
                
                // Mark first launch as completed even if no deferred link found
                preferences.markFirstLaunchCompleted()
            }
        }
    }
}

// MARK: - Public Types

/// Callback for link handling results
public typealias LinkCallback = (String, [String: String]) -> Void
public typealias ErrorCallback = (String) -> Void
