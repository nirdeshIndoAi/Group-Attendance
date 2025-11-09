# Face Recognition SDK - Complete Usage Guide

## Table of Contents
1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [API Documentation](#api-documentation)
4. [Advanced Usage](#advanced-usage)
5. [Configuration](#configuration)
6. [Examples](#examples)
7. [Troubleshooting](#troubleshooting)

## Installation

### As a Local Package

Add to your `pubspec.yaml`:

```yaml
dependencies:
  face_recognition_sdk:
    path: packages/face_recognition_sdk
```

### From Git Repository

```yaml
dependencies:
  face_recognition_sdk:
    git:
      url: https://github.com/yourusername/face_recognition_sdk.git
      ref: main
```

### Run Flutter Pub Get

```bash
flutter pub get
```

## Quick Start

### 1. Setup Provider

Wrap your app with `FaceRecognitionViewModel`:

```dart
import 'package:provider/provider.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FaceRecognitionViewModel(),
      child: MyApp(),
    ),
  );
}
```

### 2. Use the SDK Widget

#### Demo Mode (Manual Selection)

```dart
GroupAttendanceSDK(
  isDemo: true,
  onComplete: (results) {
    print('Found ${results.length} faces');
  },
)
```

#### Production Mode (Automatic Recognition)

```dart
import 'dart:io';

List<SDKUserReference> userReferences = [
  SDKUserReference(
    name: 'John Doe',
    imageBytes: await File('path/to/john.jpg').readAsBytes(),
  ),
];

GroupAttendanceSDK(
  isDemo: false,
  userReferences: userReferences,
  onComplete: (results) {
    for (var result in results) {
      print('${result.name}: ${result.isMatched}');
    }
  },
)
```

## API Documentation

### Classes

#### `GroupAttendanceSDK`

Main widget component for face recognition.

```dart
GroupAttendanceSDK({
  required bool isDemo,
  List<SDKUserReference>? userReferences,
  Function(List<RecognitionResult>)? onComplete,
})
```

**Parameters:**
- `isDemo` - Enable demo mode for manual user selection
- `userReferences` - List of reference users (required if `isDemo` is false)
- `onComplete` - Callback function with recognition results

#### `SDKUserReference`

Model for user reference data.

```dart
SDKUserReference({
  required String name,
  required Uint8List imageBytes,
})
```

**Fields:**
- `name` - User's full name
- `imageBytes` - User's reference photo as bytes (Uint8List)

#### `RecognitionResult`

Model for face recognition results.

```dart
RecognitionResult({
  required bool isMatched,
  required String name,
  required String croppedImagePath,
  double? similarity,
})
```

**Fields:**
- `isMatched` - Whether face matched a reference user
- `name` - Matched user's name (or "Unknown")
- `croppedImagePath` - File path to cropped face image
- `similarity` - Similarity score from 0.0 to 1.0

**Methods:**
- `toJson()` - Convert to JSON map with similarity percentage

#### `FaceRecognitionViewModel`

ViewModel for managing face recognition logic.

**Key Properties:**
```dart
List<File?> images;              // Selected group photos
List<File> croppedFaces;         // Detected and cropped faces
List<UserReference> userReferences; // Reference users
List<FaceMatchResult> matchResults;  // Recognition results
double recognitionThreshold;     // Matching threshold (default: 0.73)
double minimumConfidenceGap;     // Confidence gap (default: 0.05)
```

**Key Methods:**
```dart
Future<void> selectMultipleImages(BuildContext context);
Future<void> cropAndEnhanceFaces();
Future<void> addUserReference(String name, BuildContext context);
Future<void> addUserReferenceFromFile(String name, File imageFile);
Future<void> performFaceRecognition();
void clearUserReferences();
void clearMatchResults();
```

## Advanced Usage

### Custom Recognition Configuration

```dart
final viewModel = Provider.of<FaceRecognitionViewModel>(context, listen: false);

// Adjust recognition threshold (default: 0.73)
viewModel.recognitionThreshold = 0.75;

// Adjust minimum confidence gap (default: 0.05)
viewModel.minimumConfidenceGap = 0.08;
```

Higher thresholds = more strict matching (fewer false positives)
Lower thresholds = more lenient matching (fewer false negatives)

### Adding References Programmatically

```dart
final viewModel = Provider.of<FaceRecognitionViewModel>(context, listen: false);

// From file path
File imageFile = File('/path/to/image.jpg');
await viewModel.addUserReferenceFromFile('John Doe', imageFile);

// From bytes
Uint8List imageBytes = await imageFile.readAsBytes();
File tempFile = await _convertBytesToFile(imageBytes, 'john_doe');
await viewModel.addUserReferenceFromFile('John Doe', tempFile);
```

### Handling Results

```dart
GroupAttendanceSDK(
  isDemo: false,
  userReferences: userReferences,
  onComplete: (results) {
    // Filter matched faces
    var matchedFaces = results.where((r) => r.isMatched).toList();
    
    // Filter unmatched faces
    var unknownFaces = results.where((r) => !r.isMatched).toList();
    
    // Get high-confidence matches (similarity > 0.8)
    var highConfidence = results.where((r) => 
      r.similarity != null && r.similarity! > 0.8
    ).toList();
    
    // Convert to JSON
    var jsonResults = results.map((r) => r.toJson()).toList();
    
    // Display results
    for (var result in results) {
      print('Name: ${result.name}');
      print('Matched: ${result.isMatched}');
      print('Similarity: ${result.similarity?.toStringAsFixed(2)}');
      print('Image Path: ${result.croppedImagePath}');
      print('---');
    }
  },
)
```

### Navigation Patterns

#### Push and Pop

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GroupAttendanceSDK(
      isDemo: false,
      userReferences: userReferences,
      onComplete: (results) {
        Navigator.pop(context);
        _handleResults(results);
      },
    ),
  ),
);
```

#### Pop with Results

```dart
onComplete: (results) {
  Navigator.pop(context, results);
}

// Caller
final results = await Navigator.push<List<RecognitionResult>>(
  context,
  MaterialPageRoute(
    builder: (context) => GroupAttendanceSDK(...),
  ),
);
```

## Examples

### Complete Production App

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

class FaceRecognitionApp extends StatefulWidget {
  @override
  _FaceRecognitionAppState createState() => _FaceRecognitionAppState();
}

class _FaceRecognitionAppState extends State<FaceRecognitionApp> {
  List<SDKUserReference> _userReferences = [];

  Future<void> _addUser() async {
    final nameController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add User'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(ctx);
                
                final picker = ImagePicker();
                final file = await picker.pickImage(source: ImageSource.gallery);
                
                if (file != null) {
                  final bytes = await File(file.path).readAsBytes();
                  setState(() {
                    _userReferences.add(SDKUserReference(
                      name: nameController.text,
                      imageBytes: bytes,
                    ));
                  });
                }
              }
            },
            child: Text('Select Photo'),
          ),
        ],
      ),
    );
  }

  void _startRecognition() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupAttendanceSDK(
          isDemo: false,
          userReferences: _userReferences,
          onComplete: (results) {
            Navigator.pop(context);
            _showResults(results);
          },
        ),
      ),
    );
  }

  void _showResults(List<RecognitionResult> results) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Recognition Results'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: results.map((result) {
              return ListTile(
                leading: Image.file(File(result.croppedImagePath)),
                title: Text(result.name),
                subtitle: Text(
                  'Similarity: ${(result.similarity ?? 0) * 100}%',
                ),
                trailing: Icon(
                  result.isMatched ? Icons.check_circle : Icons.cancel,
                  color: result.isMatched ? Colors.green : Colors.red,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Face Recognition')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Users: ${_userReferences.length}'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _userReferences.isEmpty ? null : _startRecognition,
              child: Text('Start Recognition'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## Configuration

### Face Detection Settings

The SDK uses Google ML Kit for face detection with these settings:

- **Performance Mode**: Accurate (prioritizes accuracy over speed)
- **Landmark Mode**: All landmarks detected
- **Classification Mode**: All classifications enabled
- **Contour Mode**: All contours detected
- **Minimum Face Size**: 0.1 (10% of image)
- **Tracking**: Enabled

### Image Enhancement

Faces are automatically enhanced with:

1. **Normalization**: Converts to grayscale, resizes to 100x100
2. **Gaussian Blur**: Reduces noise (3x3 kernel)
3. **Sharpening**: Enhances edges and details
4. **Color Balance**: Adjusts brightness and contrast

### Recognition Algorithm

The SDK uses a composite similarity score:

- **Cosine Similarity** (40% weight)
- **Normalized Euclidean Distance** (30% weight)
- **Exact Match Ratio** (20% weight)
- **Pearson Correlation** (10% weight)

Feature extraction includes:
- Normalized pixel values
- Block-based statistics (16x16 blocks)
- Gradient analysis (horizontal, vertical, diagonal)

## Troubleshooting

### No Faces Detected

**Problem**: `cropAndEnhanceFaces()` returns empty list

**Solutions**:
- Ensure images contain clear, front-facing faces
- Check image quality and resolution
- Verify faces are at least 10% of image size
- Use well-lit photos without obstructions

### Low Recognition Accuracy

**Problem**: Faces not matching correctly

**Solutions**:
```dart
// Lower threshold for more lenient matching
viewModel.recognitionThreshold = 0.65;

// Reduce confidence gap requirement
viewModel.minimumConfidenceGap = 0.03;
```

### Multiple Images Not Loading

**Problem**: `selectMultipleImages()` fails

**Solutions**:
- Check storage permissions
- Verify image formats (JPG, PNG supported)
- Ensure images are accessible to app

### SDK Widget Not Updating

**Problem**: UI not reflecting changes

**Solutions**:
- Verify Provider is set up correctly
- Ensure widget is wrapped with `ChangeNotifierProvider`
- Check that `notifyListeners()` is being called

### Memory Issues

**Problem**: App crashes with large images

**Solutions**:
- Limit number of images selected at once
- Reduce image quality before processing
- Clear unused references periodically

```dart
// Clear after processing
viewModel.clearMatchResults();
```

## Best Practices

1. **Image Quality**: Use high-resolution, well-lit photos
2. **Face Position**: Front-facing faces work best
3. **Reference Photos**: One clear photo per user
4. **Threshold Tuning**: Test with your specific use case
5. **Error Handling**: Always handle null results
6. **Memory Management**: Clear references when done
7. **User Feedback**: Show loading indicators during processing

## Platform-Specific Setup

### Android

Add to `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photos for face recognition</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access</string>
```

## Support

For issues, feature requests, or contributions:
- GitHub Issues: [Your Repository]
- Email: [Your Email]
- Documentation: [Your Docs Site]

## License

MIT License - See LICENSE file for details

