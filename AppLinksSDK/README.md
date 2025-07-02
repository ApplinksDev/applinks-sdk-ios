# AppLinks SDK for iOS

A Swift SDK for handling deferred deep links in iOS applications using clipboard-based attribution, similar to the now-deprecated Firebase Dynamic Links.

## Features

- 🔗 **Universal Links** - Handle web links that open your app
- 📋 **Clipboard-based Attribution** - Retrieve deferred deep links via clipboard
- 🎯 **Custom URL Schemes** - Support for app-specific URL schemes
- 🚀 **Automatic Link Handling** - Auto-navigate on app launch
- 📊 **Attribution Tracking** - Track campaign and source data
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

// Initialize with builder pattern
AppLinksSDK.builder()
    .apiKey("pk_test_123")
    .serverUrl("https://applinks.com")
    .supportedDomains(["example.com", "app.example.com"])
    .supportedSchemes(["myapp", "example-app"])
    .autoHandleLinks(true)
    .build()
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
                    AppLinksSDK.shared.handleLink(url) { link, metadata in
                        print("Handled link: \(link)")
                    } onError: { error in
                        print("Error: \(error)")
                    }
                }
        }
    }
}
```

#### UIKit

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    AppLinksSDK.shared.handleLink(url) { link, metadata in
        print("Handled link: \(link)")
    } onError: { error in
        print("Error: \(error)")
    }
    return true
}
```

### 3. Clipboard-Based Deferred Links

The SDK automatically checks the clipboard for deferred deep links on first app launch. To test:

1. Copy an AppLinks URL to clipboard: `applinks://visit/550e8400-e29b-41d4-a716-446655440000`
2. Install and launch your app
3. The SDK will automatically retrieve and handle the deferred link

## Configuration

### Required Setup

#### Info.plist

Add your URL schemes:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

#### Associated Domains (for Universal Links)

1. Add Associated Domains capability in Xcode
2. Add your domains:
   ```
   applinks:example.com
   applinks:*.example.com
   ```

## Advanced Usage

### Custom Link Handlers

```swift
class MyCustomHandler: LinkHandler {
    func canHandle(url: URL) -> Bool {
        return url.path.hasPrefix("/special")
    }
    
    func handle(url: URL) async throws -> LinkHandlingResult {
        // Custom handling logic
        return LinkHandlingResult(handled: true, url: url)
    }
    
    var priority: Int { 100 }
}

// Add custom handler
AppLinksSDK.shared.addCustomHandler(MyCustomHandler())
```

### Manual Deferred Link Check

```swift
AppLinksSDK.shared.checkForDeferredDeepLink { link, metadata in
    print("Found deferred link: \(link)")
} onError: { error in
    print("No deferred link found")
}
```

## Privacy Considerations

- iOS 14+ shows a clipboard access notification when the app reads clipboard content
- The SDK only checks clipboard on first launch to minimize privacy impact
- Clipboard is cleared after processing to prevent re-reading

## API Reference

### AppLinksSDK

The main SDK class providing link handling functionality.

#### Methods

- `handleLink(_:onSuccess:onError:)` - Process an incoming URL
- `addCustomHandler(_:)` - Add a custom link handler
- `checkForDeferredDeepLink(onSuccess:onError:)` - Manually check for deferred links

### Configuration

- `apiKey` - Your AppLinks API key (use public keys only)
- `serverUrl` - AppLinks server URL
- `supportedDomains` - Domains for universal links
- `supportedSchemes` - Custom URL schemes
- `autoHandleLinks` - Enable automatic link handling
- `enableLogging` - Enable debug logging

## License

This SDK is available under the MIT license.