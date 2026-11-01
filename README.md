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

## Install attribution and conversions

The SDK reports each new install to Applinks, so it's credited to the link (and the campaign and ad) that sent the user to the App Store. Your backend can then report what the user does next (a trial, a subscription, a purchase), and Applinks sends the install and those conversions to Meta when the user's consent allows it.

### What is sent, and when

Once per new install, right after the first deferred deep link lookup (the automatic one on first launch, or, with `deferredDeepLinkingEnabled: false`, your app's first `checkForDeferredDeepLink()` call), the SDK sends `POST /api/v1/attributions` with your public key:

| Field | Value |
|-------|-------|
| `platform` | `ios` |
| `bundle_id` | `Bundle.main.bundleIdentifier` |
| `click_id` | The link's click ID, when the clipboard link had one |
| `att_status` | `authorized`, `denied`, `restricted` or `not_determined` |
| `ads_consent`, `limited_data_use` | What your app passed to `updateConsent` (`false` until it does) |
| `advertising_id` | What your app passed to `setAdvertisingId`, if anything |
| `app_version`, `os_version` | Your app's version and the iOS version |

The report carries only the click ID, never the clipboard link. (To open the right screen, the SDK resolves a copied `https` link with `POST /api/v1/links/retrieve`, as it does for universal links: see the note on the clipboard format below.) An install without a click ID is reported as unmatched. Deep link delivery doesn't wait for the report.

A report that fails on the network or with a server error is sent again at the next launch. A refused one is logged and not sent again: `404 App not found` means the app's bundle ID isn't the iOS bundle ID of an Applinks project, `401` that the API key is wrong. Apps updated from an SDK version without install attribution don't report: they aren't new installs.

A report without a click ID whose answer is lost (a timeout, the app suspended mid-request) can't be recognised when it's sent again, so that install may be counted twice in the project's unmatched installs. Installs credited to a link are never counted twice.

> **Adding the SDK to an app that already has users:** the first launch of that update looks like a new install to the SDK, so every existing user would be reported as an unmatched install. When your app can tell the user installed it before (for example from data it stored earlier), pass `installAttributionEnabled: false` on that launch: the install is then never reported, even on later launches with attribution turned on.

Afterwards, when the consent, the advertising ID, the ATT status, the app version or the iOS version changes, the SDK sends only what changed with `PATCH /api/v1/attributions/<attributionId>`.

> **iOS installs are credited only when the project's clipboard format is "https"** (project settings in Applinks). With it, the link page copies the link with its click ID (`https://go.acme.com/promo?ck=...`) before opening the App Store. With the default "scheme" format, it copies `bundleid://path` without a click ID, and every iOS install is reported as unmatched. With the "https" format, the SDK resolves the copied link with Applinks even when its domain isn't in `supportedDomains`.

### Report conversions from your backend

```swift
if let attributionId = AppLinksSDK.shared.attributionId {
    // Send it to your backend with the user's account
    try await api.saveAttribution(attributionId)
}
```

`attributionId` is `nil` until the install was reported, which happens in the background a moment after the first deferred deep link lookup, or at a later launch when the report failed. On a fresh install it's usually still `nil` right after `initialize`, so don't read it only once at startup: read it when you send the user's data to your backend (at sign-up, sign-in or each launch) and send it once it's set. Your backend stores it with the user and reports their conversions with `POST /api/v1/conversions` and your **private** key (`sk_`). Never call the conversions endpoint from the app: the public key ships inside it.

### Consent

```swift
// After your consent prompt, or when the user changes their privacy settings
AppLinksSDK.shared.updateConsent(adsConsent: true, limitedDataUse: false)
```

- `adsConsent`: whether your consent prompt allowed ad measurement. Pass `true` where no prompt is required.
- `limitedDataUse`: whether the user opted out of sharing under US state privacy laws.

Call it before the install is reported if you can (the values then go in the report), and again whenever the user changes their choice. It's stored on the device. Until your app calls it, the install is reported with `ads_consent: false`, so nothing is sent to Meta.

### Advertising ID

```swift
import AdSupport
import AppTrackingTransparency

if ATTrackingManager.trackingAuthorizationStatus == .authorized {
    AppLinksSDK.shared.setAdvertisingId(ASIdentifierManager.shared().advertisingIdentifier.uuidString)
}

// The user withdrew consent
AppLinksSDK.shared.setAdvertisingId(nil)
```

The SDK never reads the IDFA itself: your app reads it, only once the user allowed tracking, and passes it. A value that isn't an IDFA (a UUID) is ignored and logged, and the zeroed ID iOS returns without authorization counts as none. Applinks keeps it only while `att_status` is `authorized` and `ads_consent` is `true`: it drops it otherwise, and the SDK sends it again once both allow it (for example when the user grants consent after your app set the ID).

### App Tracking Transparency

The SDK reads `ATTrackingManager.trackingAuthorizationStatus` and never shows the ATT prompt: that's your app's call, with its own `NSUserTrackingUsageDescription`. The SDK needs no Info.plist key. It reads the status again when the app becomes active (after the prompt, or a change in Settings) and in `updateConsent`, and sends it when it changed.

### Turning it off

```swift
AppLinksSDK.initialize(
    apiKey: "pk_your_public_key",
    installAttributionEnabled: false
)
```

With `installAttributionEnabled: false` (or no API key), the SDK sends nothing for attribution.

The `ck` parameter the link page adds is removed from `LinkHandlingResult.params`.

## API Reference

### AppLinksSDK

#### Initialize
```swift
static func initialize(
    apiKey: String,
    serverUrl: String = "https://applinks.com",
    autoHandleLinks: Bool = true,
    supportedDomains: Set<String> = [],
    supportedSchemes: Set<String> = [],
    logLevel: AppLinksSDKLogLevel = .info,
    customMiddleware: [AnyLinkMiddleware] = [],
    deferredDeepLinkingEnabled: Bool = true,
    installAttributionEnabled: Bool = true
)
```

#### Install Attribution
```swift
var attributionId: String? { get }
func updateConsent(adsConsent: Bool, limitedDataUse: Bool = false)
func setAdvertisingId(_ advertisingId: String?)
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