# Face Recognition SDK

Flutter package for group photo face recognition with automatic face detection, cropping, enhancement, and user matching.

## Features

- 📸 Multiple image selection from gallery
- 👤 Automatic face detection using Google ML Kit
- 🎨 Face enhancement and preprocessing
- 🔍 Advanced face recognition with composite similarity scoring
- 📊 One-to-one user matching
- 🎯 Demo mode for manual user selection
- 📱 Production mode with reference-based recognition

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  face_recognition_sdk:
    git:
      url: https://github.com/yourusername/face_recognition_sdk.git
      ref: main
```

Then run:

```bash
flutter pub get
```

## Usage

### Demo Mode (Manual Selection)

```dart
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GroupAttendanceSDK(
      isDemo: true,
      onComplete: (results) {
        for (var result in results) {
          print('${result.name}: ${result.croppedImagePath}');
        }
      },
    ),
  ),
);
```

### Production Mode (Automatic Recognition)

```dart
import 'dart:io';
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

List<SDKUserReference> users = [
  SDKUserReference(
    name: 'John Doe',
    imageBytes: await File('john.jpg').readAsBytes(),
  ),
  SDKUserReference(
    name: 'Jane Smith',
    imageBytes: await File('jane.jpg').readAsBytes(),
  ),
];

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GroupAttendanceSDK(
      isDemo: false,
      userReferences: users,
      onComplete: (results) {
        for (var result in results) {
          if (result.isMatched) {
            print('✅ ${result.name} - ${result.similarity}');
          } else {
            print('❌ Unknown person');
          }
        }
      },
    ),
  ),
);
```

## API Reference

### GroupAttendanceSDK

Main widget for face recognition.

**Parameters:**
- `isDemo` (bool) - Enable demo mode for manual selection
- `userReferences` (List<SDKUserReference>?) - List of reference users (required if `isDemo` is false)
- `onComplete` (Function(List<RecognitionResult>)?) - Callback with results

### SDKUserReference

Input model for user reference data.

**Fields:**
- `name` (String) - User's name
- `imageBytes` (Uint8List) - User's reference photo as bytes

### RecognitionResult

Output model for face recognition results.

**Fields:**
- `isMatched` (bool) - Whether face matched a reference user
- `name` (String) - Matched user's name or "Unknown"
- `croppedImagePath` (String) - Path to cropped face image
- `similarity` (double?) - Similarity score (0.0 to 1.0)

## Platform Setup

### Android

Ensure minimum SDK version in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

### iOS

Add permissions to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photos for face recognition</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access</string>
```

## Requirements

- Flutter SDK: >=3.7.2
- Dart SDK: >=3.7.2
- iOS: 12.0+
- Android: API 21+

## License

MIT License - See LICENSE file for details
