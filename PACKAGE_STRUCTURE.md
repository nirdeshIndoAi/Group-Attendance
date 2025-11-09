# Face Recognition SDK - Package Structure

## Directory Structure

```
packages/face_recognition_sdk/
├── lib/
│   ├── face_recognition_sdk.dart          # Main package export file
│   └── src/
│       ├── models.dart                     # Data models
│       ├── face_recognition_view_model.dart # Business logic
│       ├── group_attendance_sdk_widget.dart # Main SDK widget
│       ├── screens/
│       │   ├── user_selection_screen.dart  # Demo mode screen
│       │   └── result_screen.dart          # Results display screen
│       └── widgets/
│           └── primary_button.dart         # Reusable button widget
├── example/
│   ├── lib/
│   │   └── main.dart                       # Example app
│   └── pubspec.yaml                        # Example dependencies
├── pubspec.yaml                            # Package dependencies
├── README.md                               # Package documentation
├── USAGE_GUIDE.md                          # Detailed usage guide
├── CHANGELOG.md                            # Version history
├── LICENSE                                 # MIT License
├── analysis_options.yaml                   # Linting rules
└── PACKAGE_STRUCTURE.md                    # This file
```

## File Descriptions

### Core Files

#### `lib/face_recognition_sdk.dart`
Main entry point that exports all public APIs of the package.

**Exports:**
- `GroupAttendanceSDK` - Main widget
- `SDKUserReference` - User reference model
- `RecognitionResult` - Result model
- `FaceRecognitionViewModel` - View model
- `UserSelectionScreen` - Demo mode screen
- `ResultScreen` - Results screen

#### `lib/src/models.dart`
Data models for the SDK.

**Classes:**
- `SDKUserReference` - Input model for user references
- `RecognitionResult` - Output model for recognition results

#### `lib/src/face_recognition_view_model.dart`
Core business logic using ChangeNotifier pattern.

**Responsibilities:**
- Image selection and management
- Face detection and cropping
- Face enhancement
- User reference management
- Face recognition algorithm
- Match result management

**Key Features:**
- Multi-metric similarity scoring
- One-to-one face matching
- Configurable thresholds
- Feature extraction and comparison

#### `lib/src/group_attendance_sdk_widget.dart`
Main widget component that users interact with.

**Features:**
- Replicates offline attendance view UI
- Handles demo and production modes
- Manages user reference initialization
- Provides callback for results
- Loading state management

### Screens

#### `lib/src/screens/user_selection_screen.dart`
Demo mode screen for manual user reference input.

**Features:**
- Add users with names and photos
- View list of added users
- Delete users
- Navigate to recognition results

#### `lib/src/screens/result_screen.dart`
Displays face recognition results.

**Features:**
- Shows cropped face images
- Displays match status
- Shows similarity scores
- Color-coded results

### Widgets

#### `lib/src/widgets/primary_button.dart`
Reusable button component.

**Features:**
- Customizable colors
- Flexible sizing
- Child widget support

## Data Flow

```
User Input (Images + References)
        ↓
GroupAttendanceSDK Widget
        ↓
FaceRecognitionViewModel
        ↓
┌───────────────────────────┐
│  1. Image Selection       │
│  2. Face Detection        │
│  3. Face Cropping         │
│  4. Face Enhancement      │
│  5. Feature Extraction    │
│  6. Similarity Comparison │
│  7. Match Assignment      │
└───────────────────────────┘
        ↓
RecognitionResult[]
        ↓
onComplete Callback
```

## State Management

The package uses Provider pattern with ChangeNotifier:

```
ChangeNotifierProvider<FaceRecognitionViewModel>
        ↓
    GroupAttendanceSDK
        ↓
    Consumer/Provider.of
```

## Dependencies

### Production Dependencies
- `flutter`: Flutter SDK
- `provider`: ^6.1.2 - State management
- `google_mlkit_face_detection`: ^0.10.0 - Face detection
- `image_picker`: ^1.0.7 - Image selection
- `image`: ^4.1.7 - Image processing
- `path_provider`: ^2.1.2 - File system access

### Dev Dependencies
- `flutter_test`: Testing framework
- `flutter_lints`: ^5.0.0 - Linting rules

## Usage in Other Projects

### 1. Add as Local Package

In your project's `pubspec.yaml`:

```yaml
dependencies:
  face_recognition_sdk:
    path: relative/path/to/packages/face_recognition_sdk
```

### 2. Add as Git Package

```yaml
dependencies:
  face_recognition_sdk:
    git:
      url: https://github.com/username/face_recognition_sdk.git
      ref: main
```

### 3. Publish to pub.dev

After testing and polishing:

1. Update `pubspec.yaml` - remove `publish_to: 'none'`
2. Ensure all files are documented
3. Run `flutter pub publish --dry-run`
4. Run `flutter pub publish`

## Testing Strategy

### Unit Tests
- ViewModel logic
- Feature extraction algorithms
- Similarity calculations
- Match assignment logic

### Widget Tests
- GroupAttendanceSDK rendering
- User interaction flows
- State updates
- Navigation

### Integration Tests
- End-to-end recognition flow
- File system operations
- Image processing pipeline

## Version Management

Following semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

Current version: **1.0.0**

## API Stability

### Public APIs (Stable)
- `GroupAttendanceSDK`
- `SDKUserReference`
- `RecognitionResult`
- `FaceRecognitionViewModel` (exposed methods only)

### Internal APIs (Subject to Change)
- Feature extraction algorithms
- Similarity calculation details
- UI widget implementations

## Future Enhancements

Potential additions for future versions:

1. **Multiple Face Recognition Algorithms**
   - FaceNet embeddings
   - ArcFace
   - DeepFace

2. **Performance Optimizations**
   - Batch processing
   - Multi-threading
   - GPU acceleration

3. **Additional Features**
   - Video support
   - Real-time recognition
   - Age/gender detection
   - Emotion recognition

4. **Customization Options**
   - Custom UI themes
   - Callback for progress updates
   - Custom similarity metrics

5. **Analytics**
   - Recognition statistics
   - Performance metrics
   - Quality scores

## Contributing

When contributing to this package:

1. Follow the existing code structure
2. Update this document if structure changes
3. Add tests for new features
4. Update CHANGELOG.md
5. Follow Dart/Flutter style guide
6. Document all public APIs
7. Ensure backward compatibility

## License

MIT License - See LICENSE file for details

