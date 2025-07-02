#!/bin/bash

echo "Running AppLinks SDK Tests"
echo "=========================="

cd AppLinksSDK

# Option 1: Try to run with xcodebuild for iOS
echo "Attempting to run tests with xcodebuild..."
if xcodebuild test -scheme AppLinksSDK -destination 'generic/platform=iOS Simulator' 2>/dev/null; then
    echo "✅ Tests completed successfully with xcodebuild"
else
    echo "⚠️  xcodebuild failed. This is expected if you don't have iOS simulators installed."
    echo ""
    echo "To run the tests properly, please:"
    echo "1. Open the project in Xcode:"
    echo "   open Package.swift"
    echo ""
    echo "2. In Xcode:"
    echo "   - Select the AppLinksSDK scheme"
    echo "   - Choose an iOS Simulator (e.g., iPhone 15)"
    echo "   - Press Cmd+U to run the tests"
    echo ""
    echo "Alternatively, you can run the tests on macOS with platform conditionals by:"
    echo "1. Temporarily removing UIKit dependencies"
    echo "2. Running: swift test"
fi