# Face Recognition SDK - Quick Start Guide

Get started with face recognition in your Flutter app in 5 minutes!

## Installation

### Step 1: Add Dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  face_recognition_sdk:
    path: packages/face_recognition_sdk  # For local package
    # OR
    git:
      url: https://github.com/yourusername/face_recognition_sdk.git
```

### Step 2: Install

```bash
flutter pub get
```

## Minimal Setup

### Step 1: Wrap with Provider (in main.dart)

```dart
import 'package:flutter/material.dart';
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

### Step 2: Use the SDK Widget

```dart
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GroupAttendanceSDK(
        isDemo: true,  // Start with demo mode
        onComplete: (results) {
          // Handle results
          print('Found ${results.length} faces');
        },
      ),
    );
  }
}
```

## Demo Mode (Testing)

Perfect for testing without reference images:

```dart
GroupAttendanceSDK(
  isDemo: true,
  onComplete: (results) {
    for (var result in results) {
      print('${result.name}: ${result.croppedImagePath}');
    }
  },
)
```

**What happens:**
1. User selects group photos
2. Faces are automatically detected and cropped
3. User manually assigns names to each face
4. Results returned via callback

## Production Mode (Automatic Recognition)

With pre-registered users:

```dart
import 'dart:io';

// Prepare user references
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

// Use SDK
GroupAttendanceSDK(
  isDemo: false,
  userReferences: users,
  onComplete: (results) {
    for (var result in results) {
      if (result.isMatched) {
        print('✓ ${result.name} - ${result.similarity}');
      } else {
        print('✗ Unknown person');
      }
    }
  },
)
```

## Complete Minimal Example

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:face_recognition_sdk/face_recognition_sdk.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FaceRecognitionViewModel(),
      child: MaterialApp(home: HomeScreen()),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SDKUserReference> users = [];

  Future<void> addUser() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    
    if (file != null) {
      final bytes = await File(file.path).readAsBytes();
      setState(() {
        users.add(SDKUserReference(
          name: 'User ${users.length + 1}',
          imageBytes: bytes,
        ));
      });
    }
  }

  void startRecognition() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupAttendanceSDK(
          isDemo: users.isEmpty,
          userReferences: users.isEmpty ? null : users,
          onComplete: (results) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Found ${results.length} faces')),
            );
          },
        ),
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
            Text('Users: ${users.length}'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: startRecognition,
              child: Text('Start Recognition'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addUser,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## Understanding Results

### RecognitionResult Object

```dart
class RecognitionResult {
  final bool isMatched;           // true if matched a reference user
  final String name;              // Matched user name or "Unknown"
  final String croppedImagePath;  // Path to cropped face image
  final double? similarity;       // Similarity score (0.0 to 1.0)
}
```

### Processing Results

```dart
onComplete: (results) {
  // Count matches
  int matched = results.where((r) => r.isMatched).length;
  int unknown = results.where((r) => !r.isMatched).length;
  
  // Filter high confidence
  var highConf = results.where((r) => 
    r.similarity != null && r.similarity! > 0.8
  ).toList();
  
  // Group by name
  Map<String, List<RecognitionResult>> grouped = {};
  for (var result in results) {
    grouped.putIfAbsent(result.name, () => []).add(result);
  }
  
  // Display images
  for (var result in results) {
    Image.file(File(result.croppedImagePath));
  }
}
```

## Configuration (Optional)

Adjust recognition sensitivity:

```dart
final viewModel = Provider.of<FaceRecognitionViewModel>(context, listen: false);

// More strict (fewer false positives)
viewModel.recognitionThreshold = 0.80;

// More lenient (fewer false negatives)
viewModel.recognitionThreshold = 0.65;
```

## Platform Setup

### Android (android/app/build.gradle)

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

### iOS (ios/Runner/Info.plist)

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Access photos for face recognition</string>
```

## Next Steps

- ✅ See [README.md](README.md) for full features
- ✅ Read [USAGE_GUIDE.md](USAGE_GUIDE.md) for advanced usage
- ✅ Check [PACKAGE_STRUCTURE.md](PACKAGE_STRUCTURE.md) for architecture
- ✅ Explore [example/](example/) for complete demo app

## Common Patterns

### Add User Flow

```dart
Future<void> addUserWithPhoto(String name) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  
  if (pickedFile != null) {
    final imageBytes = await File(pickedFile.path).readAsBytes();
    userReferences.add(SDKUserReference(
      name: name,
      imageBytes: imageBytes,
    ));
  }
}
```

### Navigate and Handle Results

```dart
void navigateToRecognition() async {
  final results = await Navigator.push<List<RecognitionResult>>(
    context,
    MaterialPageRoute(
      builder: (context) => GroupAttendanceSDK(
        isDemo: false,
        userReferences: userReferences,
        onComplete: (results) {
          Navigator.pop(context, results);
        },
      ),
    ),
  );
  
  if (results != null) {
    handleResults(results);
  }
}
```

### Display Results in UI

```dart
Widget buildResultList(List<RecognitionResult> results) {
  return ListView.builder(
    itemCount: results.length,
    itemBuilder: (context, index) {
      final result = results[index];
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: FileImage(File(result.croppedImagePath)),
        ),
        title: Text(result.name),
        subtitle: Text(
          result.isMatched 
            ? 'Match: ${(result.similarity! * 100).toStringAsFixed(1)}%'
            : 'Unknown',
        ),
        trailing: Icon(
          result.isMatched ? Icons.check_circle : Icons.help,
          color: result.isMatched ? Colors.green : Colors.grey,
        ),
      );
    },
  );
}
```

## Tips for Best Results

1. **Reference Photos**: Use clear, front-facing photos
2. **Lighting**: Ensure consistent lighting
3. **Image Quality**: High resolution works better
4. **Face Size**: Faces should be at least 10% of image
5. **Testing**: Start with demo mode, then production

## Help & Support

- **Issues**: Check [USAGE_GUIDE.md](USAGE_GUIDE.md#troubleshooting)
- **Examples**: See [example/lib/main.dart](example/lib/main.dart)
- **API Docs**: Read [README.md](README.md#api-reference)

## Summary

```dart
// 1. Add dependency in pubspec.yaml
// 2. Wrap app with Provider
ChangeNotifierProvider(
  create: (_) => FaceRecognitionViewModel(),
  child: MyApp(),
)

// 3. Use SDK widget
GroupAttendanceSDK(
  isDemo: false,
  userReferences: myUsers,
  onComplete: (results) => handleResults(results),
)

// Done! 🎉
```

Ready to build amazing face recognition apps! 🚀

