# AppLinksSDK Versioning Guide

This document explains how versioning works in the AppLinksSDK and how to manage releases.

## Version Management

The SDK uses semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Incompatible API changes
- **MINOR**: Backwards-compatible functionality additions
- **PATCH**: Backwards-compatible bug fixes

## Version Locations

The SDK version is defined in multiple places:

1. **`AppLinksSDKVersion.swift`** - The source of truth for runtime version access
2. **`Package.swift`** - Comment indicating current version
3. **Git tags** - Used by Swift Package Manager for version resolution

## Accessing Version at Runtime

### From Within the SDK

```swift
let version = AppLinksSDKVersion.current
let userAgent = AppLinksSDKVersion.userAgent
```

### From Client Applications

```swift
import AppLinksSDK

// Get version string
let version = AppLinksSDK.version // "1.0.0"

// Get full version info
let info = AppLinksSDK.versionInfo
```

## HTTP Headers

The SDK automatically includes version information in all API requests:

- **User-Agent**: `AppLinksSDK/1.0.0 (iOS/17.0.0)`
- **X-AppLinks-SDK-Version**: `1.0.0`

This helps with:
- Server-side SDK usage analytics
- Debugging and support
- API compatibility management

## Creating a New Release

### Manual Process

1. Update version in `AppLinksSDKVersion.swift`:
   ```swift
   public static let current = "1.1.0"
   ```

2. Update comment in `Package.swift`:
   ```swift
   // Current version: 1.1.0 - See AppLinksSDKVersion.swift for runtime version access
   ```

3. Commit changes:
   ```bash
   git add -A
   git commit -m "Release version 1.1.0"
   ```

4. Create and push tag:
   ```bash
   git tag 1.1.0
   git push && git push --tags
   ```

### Using the Release Script

A convenience script is provided to automate version updates:

```bash
./scripts/release.sh 1.1.0
```

This script will:
1. Update version in all necessary files
2. Show you the changes
3. Provide instructions for committing and tagging

## Best Practices

1. **Always use semantic versioning** - This helps users understand the impact of updates
2. **Keep version in sync** - Ensure git tags match the version in code
3. **Document breaking changes** - Update CHANGELOG.md for major version bumps
4. **Test before releasing** - Run full test suite before creating a release tag

## Integration with Swift Package Manager

Swift Package Manager uses git tags to resolve versions. When users specify:

```swift
.package(url: "https://github.com/yourorg/AppLinksSDK.git", from: "1.0.0")
```

SPM will:
1. Look for git tags in the repository
2. Find the latest tag that satisfies the version requirement
3. Check out that specific tag

This is why it's crucial to keep git tags synchronized with the version defined in code.