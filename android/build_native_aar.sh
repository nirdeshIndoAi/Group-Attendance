#!/bin/bash

set -e

echo "Building Native Core AAR..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building native_core module..."

cd native_core

# String encryption disabled for now
# echo "Running string encryption script..."
# if [ -f "encrypt_strings.sh" ]; then
#     chmod +x encrypt_strings.sh
#     ./encrypt_strings.sh
# else
#     echo "⚠️  Warning: encrypt_strings.sh not found!"
# fi
echo "⚠️  String encryption disabled - using plain strings"

echo "Running config encryption script..."
if [ -f "encrypt_config.sh" ]; then
    chmod +x encrypt_config.sh
    ./encrypt_config.sh
else
    echo "⚠️  Warning: encrypt_config.sh not found!"
fi

if [ ! -f "gradlew" ]; then
    echo "Creating Gradle wrapper..."
    gradle wrapper --gradle-version 8.3
fi

./gradlew assembleRelease

echo "Copying AAR to libface_recognition_native..."
mkdir -p ../libface_recognition_native

if [ -f "build/outputs/aar/native_core-release.aar" ]; then
    cp build/outputs/aar/native_core-release.aar ../libface_recognition_native/face_recognition_native.aar
    echo "✅ Native Core AAR built and copied!"
    echo "AAR location: $SCRIPT_DIR/libface_recognition_native/face_recognition_native.aar"
    ls -lh ../libface_recognition_native/face_recognition_native.aar
else
    echo "❌ Error: AAR file not found at build/outputs/aar/native_core-release.aar"
    echo "Build may have failed. Check the output above."
    exit 1
fi

