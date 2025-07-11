# AppLinks SDK for iOS

A Swift SDK for handling deferred deep links in iOS applications using clipboard-based attribution, similar to the now-deprecated Firebase Dynamic Links.

## Features

- 🔗 **Universal Links** - Handle web links that open your app
- 🎯 **Custom URL Schemes** - Support for app-specific URL schemes
- 📋 **Deferred Deep Links** - Retrieve deep links via clipboard on first launch
- 🚀 **Automatic Link Handling** - Auto-navigate on app launch
- 🔒 **Privacy-First** - Respects iOS clipboard privacy

## Requirements

- iOS 14.0+
- Swift 5.7+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/applinks-ios.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Quick Start

### 1. Initialize the SDK

In your `AppDelegate` or app's main entry point:

```swift
import AppLinksSDK

// Initialize the SDK
AppLinksSDK.initialize(
    apiKey: "pk_your_public_key",                        // Required: Your public API key
    supportedDomains: ["example.com", "app.example.com"], // Optional: Universal link domains
    supportedSchemes: ["myapp", "example-app"],          // Optional: Custom URL schemes
    logLevel: .info                                      // Optional: Logging level (default: .info)
)
```

### 2. Handle Incoming Links

#### SwiftUI

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle the incoming URL
                    AppLinksSDK.shared.handleLink(url)
                }
                .onReceive(AppLinksSDK.shared.linkPublisher) { linkResult in
                    // React to link handling results
                    if linkResult.handled {
                        // Navigate based on the link
                        navigateToContent(
                            path: linkResult.path,
                            params: linkResult.params,
                            metadata: linkResult.metadata
                        )
                    }
                }
        }
    }
}
```

#### UIKit

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    var linkSubscription: AnyCancellable?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize SDK
        AppLinksSDK.initialize(
            apiKey: "pk_your_public_key",
            supportedDomains: ["example.com"],
            supportedSchemes: ["myapp"]
        )
        
        // Subscribe to link events
        linkSubscription = AppLinksSDK.shared.linkPublisher
            .sink { linkResult in
                if linkResult.handled {
                    self.handleDeepLink(linkResult)
                }
            }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        AppLinksSDK.shared.handleLink(url)
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let url = userActivity.webpageURL {
            AppLinksSDK.shared.handleLink(url)
        }
        return true
    }
}
```

## Link Handling Result

The `LinkHandlingResult` object contains:

```swift
struct LinkHandlingResult {
    let handled: Bool                    // Whether the link was successfully handled
    let originalUrl: URL                 // The original URL that was processed
    let path: String                     // The extracted path from the link
    let params: [String: String]         // Query parameters from the link
    let metadata: [String: Any]          // Additional metadata (attribution, campaign data, etc.)
    let error: String?                   // Error message if handling failed
}
```

## Example Usage

### Logging Configuration

Configure logging levels for debugging:

```swift
AppLinksSDK.initialize(
    apiKey: "pk_your_public_key",
    logLevel: .debug  // Options: .none, .error, .warning, .info, .debug
)
```

## Deferred Deep Links

The SDK automatically checks for deferred deep links on first launch:

1. When a user clicks a link but doesn't have the app installed
2. The link is saved to their clipboard by the web page
3. After installing and launching the app, the SDK retrieves the link
4. The app navigates to the intended content

This happens automatically when the SDK is initialized.

## API Reference

### AppLinksSDK

#### Initialize
```swift
static func initialize(
    apiKey: String,
    supportedDomains: Set<String> = [],
    supportedSchemes: Set<String> = [],
    logLevel: AppLinksSDKLogLevel = .info
)
```

#### Handle Link
```swift
func handleLink(_ url: URL)
```

#### Link Publisher
```swift
var linkPublisher: PassthroughSubject<LinkHandlingResult, Never>
```

#### Version Info
```swift
static var version: String
static var versionInfo: String
```

## Error Handling

The SDK defines specific errors in the `AppLinksError` enum:

```swift
switch error {
case .invalidApiKey:
    print("Invalid API key format")
case .networkError(let underlying):
    print("Network error: \(underlying)")
case .invalidURL:
    print("Invalid URL format")
// ... handle other errors
}
```

## Best Practices

1. **Initialize Early**: Initialize the SDK as early as possible in your app's lifecycle
2. **Handle All URL Types**: Implement both custom scheme and universal link handling
3. **Error Handling**: Always handle potential errors in link processing
4. **Testing**: Test with various link formats and edge cases
5. **Attribution Tracking**: Use metadata for campaign attribution and analytics

## Privacy & Security

- The SDK only accesses the clipboard when checking for deferred deep links
- No personal data is collected without explicit attribution parameters
- All API communications use HTTPS
- API keys must be public keys (prefixed with `pk_`)

## Troubleshooting

### Links Not Opening App
- Verify your Associated Domains entitlement is configured correctly
- Ensure domains are listed in `supportedDomains`

### Deferred Links Not Working
- Ensure clipboard permissions are granted
- Verify the link was properly copied to clipboard

### Custom Schemes Not Working
- Verify URL schemes are registered in Info.plist
- Ensure schemes are listed in `supportedSchemes`
- Test with proper URL format: `myapp://path/to/content`

## License

This SDK is available under the MIT license. See the LICENSE file for more info.