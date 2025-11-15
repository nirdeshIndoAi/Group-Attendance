# Face Recognition SDK

A Flutter package for group photo face recognition with automatic face detection, cropping, enhancement, and user matching.

## Features

- 📸 Multiple image selection from gallery
- 👤 Automatic face detection and cropping using Google ML Kit
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
      print('Name: ${result.name}');
      print('Matched: ${result.isMatched}');
      print('Image: ${result.croppedImagePath}');
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
      print('Name: ${result.name}');
      print('Matched: ${result.isMatched}');
      print('Image: ${result.croppedImagePath}');
    }
  },
)
```

## API Reference

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

### FaceRecognitionViewModel

View model for managing face recognition logic.

**Key Methods:**
- `selectMultipleImages()`: Select images from gallery
- `cropAndEnhanceFaces()`: Detect and crop faces
- `addUserReference(name, context)`: Add a user reference
- `performFaceRecognition()`: Perform face matching
- `clearUserReferences()`: Clear all references
- `clearMatchResults()`: Clear match results

## Recognition Algorithm

The SDK uses a sophisticated multi-metric face recognition algorithm:

1. **Feature Extraction:**
   - Normalized pixel values
   - Block-based statistics (average, range, variance)
   - Gradient analysis (horizontal, vertical, diagonal)

2. **Similarity Scoring:**
   - Cosine Similarity (40% weight)
   - Normalized Euclidean Distance (30% weight)
   - Exact Match Ratio (20% weight)
   - Pearson Correlation (10% weight)

3. **Matching Strategy:**
   - Two-pass assignment for one-to-one matching
   - High-confidence matches prioritized
   - Configurable thresholds for precision

## Configuration

Fine-tune recognition parameters in `FaceRecognitionViewModel`:

```dart
// Recognition threshold (default: 0.73)
viewModel.recognitionThreshold = 0.75;

// Minimum confidence gap (default: 0.05)
viewModel.minimumConfidenceGap = 0.08;
```

## Requirements

- Flutter SDK: >=3.7.2
- Dart SDK: >=3.7.2
- iOS: 12.0+
- Android: API 21+

## License Validation

- The SDK uses `package_info_plus` to read the host app ID.
- License validation is performed via `https://classes-api.indoai.co/api/employee/validatekey`.
- A quick connectivity check (`https://www.google.com`) runs before every online validation.
- Successful validations are cached locally with `shared_preferences` for offline use.
- Whenever the app returns to the foreground and the network is available, the SDK re-validates the key automatically.

## Dependencies

- `google_mlkit_face_detection`: Face detection
- `image_picker`: Image selection
- `image`: Image processing
- `path_provider`: File system access
- `http`: Network calls for license validation
- `package_info_plus`: Host application metadata
- `shared_preferences`: Offline cache for license status

## License

MIT License - See LICENSE file for details

## Support

For issues and feature requests, please file an issue on GitHub.

