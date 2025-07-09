\# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS SDK written in Swift that provides deferred deep linking functionality using clipboard-based attribution. The SDK allows apps to handle universal links, custom URL schemes, and retrieve deferred deep links when users install the app from a link.

## Build and Development Commands

### Building the SDK
```bash
# Build the SDK
swift build

# Build for release
swift build -c release

# Clean build
swift build --clean
```

### Testing
Since this is an iOS SDK that uses UIKit, tests must be run through Xcode or xcodebuild:

**Option 1: Using Xcode (Recommended)**
```bash
# Open the package in Xcode
open /Users/maxencehenneron/Documents/Projects/Appsent/Applink-SDK-iOS/AppLinksSDK/Package.swift

# Then in Xcode:
# 1. Select the AppLinksSDK scheme
# 2. Choose an iOS Simulator (e.g., iPhone 15)
# 3. Press Cmd+U to run tests
```

**Option 2: Using xcodebuild**
```bash
cd AppLinksSDK

# Run tests on iOS Simulator
xcodebuild test -scheme AppLinksSDK -destination 'generic/platform=iOS Simulator'

# Run tests with specific simulator
xcodebuild test -scheme AppLinksSDK -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'

# Run tests with code coverage
xcodebuild test -scheme AppLinksSDK -destination 'generic/platform=iOS Simulator' -enableCodeCoverage YES
```

**Note**: `swift test` cannot be used directly because it runs on macOS, which doesn't have UIKit.

### Demo App
The demo app is located in `/AppLinksDemo/` and requires opening in Xcode:
- Open the root directory in Xcode
- Select the AppLinksDemo scheme
- Build and run on simulator or device

## Architecture and Key Components

### SDK Structure
The SDK follows a modular architecture with clear separation of concerns:

1. **Main Entry Point**: `AppLinksSDK.swift`
   - Singleton pattern with forced initialization
   - Coordinates all SDK functionality

2. **Link Handling Layer**: `/Handlers/`
   - Protocol-based design with `LinkHandler` protocol
   - `UniversalLinkHandler`: Processes web URLs that should open the app
   - `CustomSchemeHandler`: Handles app-specific URL schemes
   - Handlers have priorities for execution order

3. **Network Layer**: `/API/`
   - `AppLinksApiClient`: Async/await HTTP client
   - Models in `/API/Models/` for type-safe responses
   - Handles communication with AppLinks server

4. **Business Logic**: `/Managers/`
   - `LinkHandlingManager`: Orchestrates link processing
   - `ClipboardManager`: Handles deferred link retrieval from clipboard
   - Implements privacy-conscious clipboard checking

5. **Storage**: `AppLinksPreferences.swift`
   - UserDefaults wrapper for persistent data
   - Tracks first launch and processed links

### Key Design Patterns
- **Protocol-Oriented**: Link handlers conform to protocols for extensibility
- **Async/Await**: Modern Swift concurrency throughout
- **Dependency Injection**: Components receive dependencies via initializers

## Development Guidelines

### Adding New Features
1. Follow existing patterns - check similar components first
2. Use protocols for extensibility
3. Implement async/await for any asynchronous operations
4. Add new handlers by conforming to `LinkHandler` protocol

### Code Style
- Swift 5.7+ features are available
- Use modern concurrency (async/await) over callbacks
- Follow protocol-oriented design principles
- No external dependencies - keep it lightweight

### Testing Approach
Basic test suite is now working with:
- **BasicSDKTests.swift** - Core SDK functionality tests
  - Basic link handling flow
  - Configuration validation
- **Status**: ✅ 4 tests passing
- **Coverage**: Basic SDK functionality and link handling

**Note**: Additional comprehensive tests are available but need fixing to match the actual SDK implementation. Run `xcodebuild test` to execute current working tests.

## Important Configuration

### For SDK Users
1. **Info.plist**: Must add URL schemes under `CFBundleURLTypes`
2. **Entitlements**: Add Associated Domains capability for universal links
3. **Initialization**: SDK must be initialized before use with API key and server URL

### Privacy Considerations
- iOS 14+ shows clipboard notification on first access
- SDK only checks clipboard once on first launch
- Clipboard is cleared after processing to prevent re-reads

## Common Development Tasks

### Adding a New Link Handler
1. Create new class conforming to `LinkHandler` protocol
2. Implement `canHandle(url:)`, `handle(url:)`, and `priority`
3. Register with SDK using `addCustomHandler(_:)`

### Modifying API Communication
1. Update models in `/API/Models/` if response format changes
2. Modify `AppLinksApiClient` for new endpoints
3. Keep async/await pattern for consistency

### Debugging
- Check console output for link handling flow
- Use demo app to test different link scenarios