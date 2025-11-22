#!/bin/bash

set -e

echo "Building Face Recognition SDK for distribution..."

cd "$(dirname "$0")"

echo "Cleaning previous builds..."
flutter clean
cd android && ./gradlew clean && cd ..
cd ios && pod install && cd ..

echo "Building Android AAR..."
flutter build aar --release --no-debug

echo "Building iOS Framework..."
flutter build ios-framework --release --obfuscate --split-debug-info=build/obfuscation/ios

echo "✅ Build completed!"
echo ""
echo "Output files:"
echo "- Android: build/host/outputs/repo/"
echo "- iOS: build/ios/framework/Release/"

