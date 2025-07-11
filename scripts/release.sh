#!/bin/bash

# Release script for AppLinksSDK
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.0.1

if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.1"
    exit 1
fi

VERSION=$1

# Validate version format (basic semver)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z (e.g., 1.0.1)"
    exit 1
fi

echo "Preparing release for AppLinksSDK version $VERSION"

# Get current date in YYYY-MM-DD format
BUILD_DATE=$(date '+%Y-%m-%d')

# Update version in AppLinksSDKVersion.swift
VERSION_FILE="AppLinksSDK/Sources/AppLinksSDK/AppLinksSDKVersion.swift"
if [ -f "$VERSION_FILE" ]; then
    sed -i '' "s/public static let current = \"[^\"]*\"/public static let current = \"$VERSION\"/" "$VERSION_FILE"
    sed -i '' "s/public static let buildDate = \"[^\"]*\"/public static let buildDate = \"$BUILD_DATE\"/" "$VERSION_FILE"
    echo "✓ Updated version to $VERSION in $VERSION_FILE"
    echo "✓ Updated build date to $BUILD_DATE in $VERSION_FILE"
else
    echo "✗ Could not find $VERSION_FILE"
    exit 1
fi

# Update version comment in Package.swift
PACKAGE_FILE="AppLinksSDK/Package.swift"
if [ -f "$PACKAGE_FILE" ]; then
    sed -i '' "s/Current version: [^ ]*/Current version: $VERSION/" "$PACKAGE_FILE"
    echo "✓ Updated version comment in $PACKAGE_FILE"
else
    echo "✗ Could not find $PACKAGE_FILE"
    exit 1
fi

echo ""
echo "Version updated to $VERSION and build date set to $BUILD_DATE in all files."
echo ""
echo "Next steps:"
echo "1. Review the changes: git diff"
echo "2. Commit the changes: git add -A && git commit -m \"Release version $VERSION\""
echo "3. Create a tag: git tag $VERSION"
echo "4. Push changes and tag: git push && git push --tags"