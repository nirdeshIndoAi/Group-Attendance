# Face Recognition SDK - Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Flutter App                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ imports face_recognition_sdk
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Face Recognition SDK Package                │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌────────────────────────────────────────────────┐    │
│  │      GroupAttendanceSDK (Main Widget)          │    │
│  │  • Entry point for users                       │    │
│  │  • Handles UI rendering                        │    │
│  │  • Manages demo/production modes               │    │
│  └────────────┬───────────────────────────────────┘    │
│               │                                          │
│               │ uses                                     │
│               ▼                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │   FaceRecognitionViewModel (Business Logic)    │    │
│  │  • Image selection & management                │    │
│  │  • Face detection & cropping                   │    │
│  │  • Face enhancement                            │    │
│  │  • Feature extraction                          │    │
│  │  • Similarity comparison                       │    │
│  │  • Match assignment                            │    │
│  └────────────┬───────────────────────────────────┘    │
│               │                                          │
│               │ manages                                  │
│               ▼                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │        Data Models                             │    │
│  │  • SDKUserReference (Input)                    │    │
│  │  • RecognitionResult (Output)                  │    │
│  │  • UserReference (Internal)                    │    │
│  │  • FaceMatchResult (Internal)                  │    │
│  └────────────────────────────────────────────────┘    │
│                                                           │
└───────────────────┬───────────────────────────────────┘
                    │
                    │ uses
                    ▼
┌─────────────────────────────────────────────────────────┐
│              External Dependencies                       │
├─────────────────────────────────────────────────────────┤
│  • Provider (State Management)                           │
│  • Google ML Kit (Face Detection)                        │
│  • Image Picker (Image Selection)                        │
│  • Image Package (Image Processing)                      │
│  • Path Provider (File System)                           │
└─────────────────────────────────────────────────────────┘
```

## Component Breakdown

### 1. Widget Layer (UI)

```
GroupAttendanceSDK
├── UserSelectionScreen (Demo Mode)
├── ResultScreen (Results Display)
└── PrimaryButton (Reusable Component)
```

**Responsibilities:**
- Render UI
- Handle user interactions
- Navigate between screens
- Display loading states
- Show results

### 2. ViewModel Layer (Business Logic)

```
FaceRecognitionViewModel (ChangeNotifier)
├── Image Management
│   ├── selectMultipleImages()
│   ├── images: List<File?>
│   └── currentImageIndex: int
│
├── Face Processing
│   ├── cropAndEnhanceFaces()
│   ├── _detectFaces()
│   ├── _cropFace()
│   └── _enhanceFace()
│
├── User Reference Management
│   ├── addUserReference()
│   ├── addUserReferenceFromFile()
│   ├── removeUserReference()
│   ├── clearUserReferences()
│   └── userReferences: List<UserReference>
│
└── Face Recognition
    ├── performFaceRecognition()
    ├── _extractFaceTemplate()
    ├── _compareFaceTemplates()
    ├── clearMatchResults()
    └── matchResults: List<FaceMatchResult>
```

**Responsibilities:**
- Manage application state
- Process images
- Detect and crop faces
- Extract face features
- Compare faces
- Assign matches

### 3. Model Layer (Data)

```
Public Models (API Surface)
├── SDKUserReference
│   ├── name: String
│   └── imageBytes: Uint8List
│
└── RecognitionResult
    ├── isMatched: bool
    ├── name: String
    ├── croppedImagePath: String
    └── similarity: double?

Internal Models
├── UserReference
│   ├── name: String
│   ├── imageFile: File
│   └── faceTemplate: List<int>
│
└── FaceMatchResult
    ├── croppedFaceFile: File
    ├── isMatched: bool
    ├── matchedUserName: String?
    └── similarity: double?
```

## Data Flow

### Demo Mode Flow

```
User Action
    │
    ├─> Select Images
    │       │
    │       ├─> ImagePicker.pickMultiImage()
    │       └─> Store in ViewModel.images
    │
    ├─> Crop Faces
    │       │
    │       ├─> Google ML Kit Detection
    │       ├─> Extract Face Regions
    │       ├─> Enhance Face Images
    │       └─> Store in ViewModel.croppedFaces
    │
    ├─> Navigate to UserSelectionScreen
    │       │
    │       └─> User assigns names manually
    │
    └─> Return Results
            │
            └─> Callback with RecognitionResult[]
```

### Production Mode Flow

```
Initialization
    │
    ├─> Receive SDKUserReference[]
    │       │
    │       ├─> Convert bytes to File
    │       ├─> Detect face in reference
    │       ├─> Extract feature template
    │       └─> Store in ViewModel.userReferences
    │
Processing
    │
    ├─> Select Images
    │       │
    │       └─> Store in ViewModel.images
    │
    ├─> Crop Faces
    │       │
    │       ├─> Detect all faces
    │       ├─> Extract & enhance faces
    │       └─> Store in ViewModel.croppedFaces
    │
    ├─> Face Recognition
    │       │
    │       ├─> Extract templates from cropped faces
    │       ├─> Compare with reference templates
    │       ├─> Calculate similarity scores
    │       ├─> Two-pass assignment
    │       └─> Store in ViewModel.matchResults
    │
    └─> Return Results
            │
            └─> Callback with RecognitionResult[]
```

## Recognition Algorithm

### Feature Extraction Pipeline

```
Input Image
    │
    ├─> Preprocessing
    │   ├─> Grayscale Conversion
    │   ├─> Resize to 100x100
    │   └─> Normalize values [0-255]
    │
    ├─> Enhancement
    │   ├─> Gaussian Blur (noise reduction)
    │   ├─> Sharpen (edge enhancement)
    │   └─> Color Balance
    │
    └─> Feature Extraction
        │
        ├─> Pixel Features
        │   └─> All 10,000 pixel values
        │
        ├─> Block Statistics (6x6 grid)
        │   ├─> Block Averages (36 values)
        │   ├─> Block Ranges (36 values)
        │   └─> Block Variances (36 values)
        │
        └─> Gradient Features
            ├─> Horizontal Gradients (9,900 values)
            ├─> Vertical Gradients (9,900 values)
            └─> Diagonal Gradients (9,801 values)
```

### Similarity Comparison

```
Template A + Template B
    │
    ├─> Cosine Similarity (40% weight)
    │   └─> dot(A, B) / (norm(A) * norm(B))
    │
    ├─> Normalized Euclidean Distance (30% weight)
    │   └─> 1 - (euclidean(A, B) / maxDist)
    │
    ├─> Exact Match Ratio (20% weight)
    │   └─> count(A[i] == B[i]) / length
    │
    ├─> Pearson Correlation (10% weight)
    │   └─> correlation(A, B)
    │
    └─> Composite Score
        └─> Weighted sum [0.0 to 1.0]
```

### Match Assignment Strategy

```
Cropped Faces + User References
    │
    ├─> Calculate All Similarities
    │   └─> Create NxM similarity matrix
    │
    ├─> Pass 1: High Confidence Matches
    │   ├─> Filter: similarity > threshold
    │   ├─> Filter: confidence gap > minimum
    │   ├─> Sort by similarity (highest first)
    │   └─> Assign one-to-one
    │
    ├─> Pass 2: Best Available Matches
    │   ├─> For remaining faces
    │   ├─> For remaining references
    │   ├─> Sort by similarity
    │   └─> Assign if > threshold
    │
    └─> Mark Unmatched
        └─> Set as "Unknown"
```

## State Management

### Provider Pattern

```
App Root
    │
    └─> ChangeNotifierProvider<FaceRecognitionViewModel>
            │
            ├─> GroupAttendanceSDK
            │   ├─> Consumer (watches state)
            │   └─> Provider.of (reads/writes)
            │
            ├─> UserSelectionScreen
            │   ├─> Consumer (watches userReferences)
            │   └─> Provider.of (addUserReference)
            │
            └─> ResultScreen
                └─> Receives results as constructor param
```

### State Properties

```dart
FaceRecognitionViewModel {
  // Image State
  List<File?> images = [];
  int currentImageIndex = 0;
  bool isImagePicked = false;
  
  // Face State
  List<File> croppedFaces = [];
  List<bool> hasError = [];
  
  // Reference State
  List<UserReference> userReferences = [];
  
  // Recognition State
  List<FaceMatchResult> matchResults = [];
  
  // Configuration
  double recognitionThreshold = 0.73;
  double minimumConfidenceGap = 0.05;
}
```

### State Updates

```
User Action
    │
    └─> ViewModel Method Call
            │
            ├─> Update State Properties
            │
            └─> notifyListeners()
                    │
                    └─> UI Rebuilds (Consumer)
```

## File System Operations

```
Temporary Directory
    │
    ├─> /cropped_faces/
    │   ├─> face_0.jpg
    │   ├─> face_1.jpg
    │   └─> face_N.jpg
    │
    └─> /user_references/
        ├─> user_name_0.jpg
        ├─> user_name_1.jpg
        └─> user_name_N.jpg
```

**Management:**
- Files created in system temp directory
- Managed by path_provider
- Auto-cleanup by OS
- Manual cleanup via ViewModel.clear*()

## Error Handling

```
Operation
    │
    ├─> Success Path
    │   └─> Continue execution
    │
    └─> Error Path
        ├─> Catch exception
        ├─> Set hasError flag
        ├─> Log error (if debug)
        ├─> Notify user
        └─> Graceful degradation
```

## Performance Considerations

### Optimization Strategies

1. **Image Processing**
   - Resize to standard 100x100
   - Single-pass enhancement
   - Efficient array operations

2. **Matching Algorithm**
   - Two-pass reduces comparisons
   - Early termination on clear matches
   - Vectorized operations

3. **Memory Management**
   - Temporary file storage
   - Clear unused references
   - Dispose resources properly

4. **UI Responsiveness**
   - Async operations
   - Loading indicators
   - Progress feedback

## Extension Points

### Custom Similarity Metrics

```dart
// Add custom metric to _compareFaceTemplates()
double customMetric = calculateCustomSimilarity(template1, template2);
compositeScore += customMetric * 0.1;  // 10% weight
```

### Custom Enhancement

```dart
// Override _enhanceFace() with custom processing
img.Image customEnhance(img.Image input) {
  // Your enhancement logic
  return enhanced;
}
```

### Custom UI

```dart
// Wrap GroupAttendanceSDK with custom UI
class CustomRecognitionUI extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: customDecoration,
      child: GroupAttendanceSDK(...),
    );
  }
}
```

## Security Model

```
Data Flow Security
    │
    ├─> Image Data
    │   ├─> Stored locally only
    │   ├─> No network transmission
    │   └─> Temporary storage
    │
    ├─> Face Templates
    │   ├─> Generated on-device
    │   ├─> Not reversible to images
    │   └─> Cleared after use
    │
    └─> Recognition Results
        ├─> Return via callback only
        ├─> No persistent storage
        └─> User controls retention
```

## Platform Integration

```
Flutter App
    │
    ├─> Android
    │   ├─> Kotlin/Java Native Code
    │   ├─> Platform Channels
    │   └─> ML Kit Android SDK
    │
    └─> iOS
        ├─> Swift/Objective-C Native Code
        ├─> Platform Channels
        └─> ML Kit iOS SDK
```

## Testing Architecture

```
Test Pyramid
    │
    ├─> Unit Tests
    │   ├─> ViewModel logic
    │   ├─> Feature extraction
    │   ├─> Similarity calculations
    │   └─> Match assignment
    │
    ├─> Widget Tests
    │   ├─> SDK widget rendering
    │   ├─> User interactions
    │   └─> State updates
    │
    └─> Integration Tests
        ├─> Complete flows
        ├─> File operations
        └─> ML Kit integration
```

## Deployment Model

```
Development
    │
    ├─> Local Testing
    │   └─> path: packages/face_recognition_sdk
    │
Production
    │
    ├─> Git Repository
    │   └─> git: url + ref
    │
    └─> Pub.dev (Future)
        └─> face_recognition_sdk: ^1.0.0
```

---

This architecture ensures:
- ✅ Separation of concerns
- ✅ Testability
- ✅ Maintainability
- ✅ Extensibility
- ✅ Performance
- ✅ Security

