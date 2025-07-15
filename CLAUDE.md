# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

AppLinks SDK for iOS is a Swift SDK for handling deferred deep links in iOS applications using clipboard-based attribution. It serves as a replacement for the deprecated Firebase Dynamic Links, providing universal links, custom URL schemes, and deferred deep link support with a privacy-first approach.

## Development Commands

### Testing
```bash
# Run tests using the provided script
./run-tests.sh

# Or run tests directly with Swift Package Manager (requires platform adjustments)
cd AppLinksSDK && swift test

# Run tests in Xcode (recommended)
# 1. Open AppLinksSDK/Package.swift in Xcode
# 2. Select AppLinksSDK scheme and an iOS Simulator
# 3. Press Cmd+U
```

### Building
```bash
# Build the SDK package
cd AppLinksSDK && swift build

# Build for specific platform
swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-ios14.0-simulator"
```

### Release Management
```bash
# Create a new release (updates version files automatically)
./scripts/release.sh 1.0.1

# Manual release process:
# 1. Update version in AppLinksSDK/Sources/AppLinksSDK/AppLinksSDKVersion.swift
# 2. Update version comment in AppLinksSDK/Package.swift
# 3. Commit changes
# 4. Create and push git tag
```

### Demo App
```bash
# Open demo app in Xcode
open AppLinksDemo/AppLinksDemo.xcodeproj

# Run demo app: Build and run in Xcode with iPhone simulator
```

## Architecture

### Package Structure
- **AppLinksSDK/**: Main SDK Swift package
  - **Sources/AppLinksSDK/**: SDK implementation
    - **API/**: Network layer (`AppLinksApiClient.swift`, models)
    - **Managers/**: Feature managers (`ClipboardManager.swift`)
    - **Middleware/**: Link processing chain (`LinkMiddleware.swift`, implementations)
    - **Storage/**: Preferences and persistence (`AppLinksPreferences.swift`)
  - **Tests/**: XCTest unit tests

### Core Architecture Pattern: Middleware Chain
The SDK uses a middleware chain pattern for extensible link processing:

1. **LinkMiddleware Protocol**: Base protocol for all middleware
2. **AnyLinkMiddleware**: Type-erased wrapper for middleware
3. **MiddlewareChain**: Manages execution order
4. **Built-in Middleware**:
   - `LoggingMiddleware`: Logs all link operations
   - `UniversalLinkMiddleware`: Handles web domain links
   - `SchemeMiddleware`: Handles custom URL schemes

### Key Components

1. **AppLinksSDK** (Main entry point)
   - Singleton with `shared` instance
   - Publishes link results via Combine `linkPublisher`
   - Manages middleware chain and deferred link checking

2. **AppLinksApiClient**
   - REST API client for server communication
   - Endpoints: `/v1/links/{linkId}`, `/v1/links/{linkId}/visit`
   - Includes SDK version in User-Agent and headers

3. **ClipboardManager**
   - Privacy-aware clipboard access
   - Checks for AppLinks URLs in clipboard
   - Auto-clears clipboard after retrieval

4. **LinkHandlingResult**
   - Unified result with status, path, params, metadata
   - Published to `linkPublisher` for app consumption

### Version Management
- Version source of truth: `AppLinksSDKVersion.swift`
- Access via `AppLinksSDK.version` or `AppLinksSDK.versionInfo`
- Automatically included in API request headers

### Testing Strategy
- XCTest framework for unit tests
- Mock objects for API client and clipboard manager
- Test coverage for all public APIs and critical paths
- Integration tests in demo app

## Key Implementation Notes

1. **Privacy First**: Only accesses clipboard when explicitly checking for deferred links
2. **No External Dependencies**: Self-contained SDK for reliability
3. **iOS 14+ Requirement**: Uses modern Swift features (async/await, Combine)
4. **Type Safety**: Strong typing with enums for errors and states
5. **Extensibility**: Custom middleware can be added via `AppLinksSDK.shared.addMiddleware()`

## Common Development Tasks

### Adding New Middleware
1. Create class conforming to `LinkMiddleware` protocol
2. Implement `handle(url:next:)` method
3. Add to chain: `AppLinksSDK.shared.addMiddleware(CustomMiddleware())`

### Updating API Endpoints
1. Modify endpoints in `AppLinksApiClient.swift`
2. Update corresponding models in `API/Models/`
3. Add tests in `AppLinksApiClientTests.swift`

### Debugging Link Handling
1. Set log level to `.debug` during initialization
2. All middleware operations are logged
3. Check `LinkHandlingResult.error` for failure details

## Platform Compatibility
- **Primary**: iOS 14.0+
- **Demo App**: Requires Xcode and iOS Simulator
- **Testing**: Best run in Xcode with iOS Simulator target
- **Package Manager**: Swift Package Manager (primary), CocoaPods support