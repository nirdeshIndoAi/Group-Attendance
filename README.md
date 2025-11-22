# Face Recognition SDK

A Flutter package for group photo face recognition with automatic face detection, cropping, enhancement, and user matching.

## Features

- 📸 Multiple image selection from gallery
- 👤 Automatic face detection and cropping
- 🎨 Face image enhancement (normalization, sharpening, noise reduction)
- 🔍 Advanced face recognition with composite similarity scoring
- 📊 One-to-one matching algorithm with confidence thresholds
- 🎯 Demo mode for manual user selection
- 📱 Production mode with reference-based recognition

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  face_recognition_sdk:
    path: packages/face_recognition_sdk
```

Or for remote repositories:

```yaml
dependencies:
  face_recognition_sdk:
    git:
      url: https://github.com/yourusername/face_recognition_sdk.git
```

Then run:

```bash
flutter pub get
```

## Usage
### 1. Demo Mode (Manual User Selection)

```dart
GroupAttendanceSDK(
  isDemo: true,
  licenseKey: 'REPLACE_WITH_LICENSE_KEY',
  onComplete: (results) {
    for (var result in results) {
      // Process result.name, result.isMatched, result.croppedImagePath
    }
  },
)
```

### 2. Production Mode (Automatic Face Recognition)

```dart
import 'dart:typed_data';
import 'dart:io';

// Prepare user references
List<SDKUserReference> userReferences = [
  SDKUserReference(
    name: 'John Doe',
    imageBytes: await File('path/to/john.jpg').readAsBytes(),
  ),
  SDKUserReference(
    name: 'Jane Smith',
    imageBytes: await File('path/to/jane.jpg').readAsBytes(),
  ),
];

// Use the SDK
GroupAttendanceSDK(
  isDemo: false,
  userReferences: userReferences,
  licenseKey: 'REPLACE_WITH_LICENSE_KEY',
  onComplete: (results) {
    for (var result in results) {
      // Process result.name, result.isMatched, result.croppedImagePath
    }
  },
)
```

### GroupAttendanceSDK

Main widget component for face recognition.

**Parameters:**
- `licenseKey` (String, required): License key issued for your app ID (based on host package name)
- `isDemo` (bool, required): Enable demo mode for manual selection
- `userReferences` (List<SDKUserReference>?, optional): List of reference users for recognition (required if `isDemo` is false)
- `onComplete` (Function(List<RecognitionResult>)?, optional): Callback with recognition results

### SDKUserReference

Model for user reference data.

**Fields:**
- `name` (String): User's name
- `imageBytes` (Uint8List): User's reference photo as bytes

### RecognitionResult

Model for face recognition results.

**Fields:**
- `isMatched` (bool): Whether face matched a reference user
- `name` (String): Matched user's name or "Unknown"
- `croppedImagePath` (String): Path to cropped face image


## Requirements

- Flutter SDK: >=3.7.2
- Dart SDK: >=3.7.2
- iOS: 12.0+
- Android: API 21+


## Support
For issues and feature requests, please file an issue on GitHub or contact us directly.

