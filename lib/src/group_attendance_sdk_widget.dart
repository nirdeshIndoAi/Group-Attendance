import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'widgets/primary_button.dart';
import 'screens/user_selection_screen.dart';
import 'models.dart';

class UserReference {
  final String name;
  final File photo;
  Uint8List? faceTemplate;

  UserReference({required this.name, required this.photo, this.faceTemplate});
}

class FaceMatchResult {
  final File croppedFace;
  final bool isMatched;
  final String? matchedUserName;
  final double? similarity;

  FaceMatchResult({
    required this.croppedFace,
    required this.isMatched,
    this.matchedUserName,
    this.similarity,
  });
}

class GroupAttendanceSDK extends StatefulWidget {
  final List<SDKUserReference>? userReferences;
  final bool isDemo;
  final Function(List<RecognitionResult>)? onComplete;

  const GroupAttendanceSDK({
    Key? key,
    this.userReferences,
    this.isDemo = false,
    this.onComplete,
  }) : super(key: key);

  @override
  State<GroupAttendanceSDK> createState() => _GroupAttendanceSDKState();
}

class _GroupAttendanceSDKState extends State<GroupAttendanceSDK> {
  bool _isInitializing = false;
  int currentImageIndex = 0;
  List<File?> images = [];
  List<bool> hasError = [];
  List<File> croppedFaces = [];
  List<UserReference> userReferences = [];
  List<FaceMatchResult> matchResults = [];
  double recognitionThreshold = 0.55;
  double minimumConfidenceGap = 0.03;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: false,
      enableContours: false,
      enableClassification: false,
      minFaceSize: 0.15,
    ),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.isDemo && widget.userReferences != null && widget.userReferences!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeUserReferences();
      });
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeUserReferences() async {
    setState(() {
      _isInitializing = true;
    });

    userReferences.clear();

    for (var userRef in widget.userReferences!) {
      File imageFile = await _convertBytesToFile(userRef.imageBytes, userRef.name);
      await _addUserReferenceFromFile(userRef.name, imageFile);
    }

    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _addUserReferenceFromFile(String name, File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return;
      }

      final face = faces.first;
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return;

      final faceRect = face.boundingBox;
      final x = max(0, faceRect.left.toInt());
      final y = max(0, faceRect.top.toInt());
      final w = min(image.width - x, faceRect.width.toInt());
      final h = min(image.height - y, faceRect.height.toInt());

      if (w <= 0 || h <= 0) return;

      final croppedImage = img.copyCrop(image, x: x, y: y, width: w, height: h);
      final enhancedImage = _enhanceFaceImage(croppedImage);
      final template = _extractFaceTemplate(enhancedImage);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ref_${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(enhancedImage));

      userReferences.add(UserReference(
        name: name,
        photo: tempFile,
        faceTemplate: template,
      ));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<File> _convertBytesToFile(Uint8List bytes, String name) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/user_${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> pickImageAndUpload(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          if (images.length <= currentImageIndex) {
            images.add(File(pickedFile.path));
            hasError.add(false);
          } else {
            images[currentImageIndex] = File(pickedFile.path);
            hasError[currentImageIndex] = false;
          }
        });
      }
    } catch (e) {
      setState(() {
        if (hasError.length <= currentImageIndex) {
          hasError.add(true);
        } else {
          hasError[currentImageIndex] = true;
        }
      });
    }
  }

  void removeImage(int index) {
    setState(() {
      images[index] = null;
      hasError[index] = false;
    });
  }

  void moveToNextImage() {
    setState(() {
      currentImageIndex++;
      if (images.length <= currentImageIndex) {
        images.add(null);
        hasError.add(false);
      }
    });
  }

  Future<void> processAllCapturedImages(BuildContext context) async {
    croppedFaces.clear();

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      if (image != null) {
        final inputImage = InputImage.fromFile(image);
        final faces = await _faceDetector.processImage(inputImage);

        for (final face in faces) {
          final croppedFace = await _cropFaceFromImage(image, face);
          if (croppedFace != null) {
            croppedFaces.add(croppedFace);
          }
        }
      }
    }
  }

  Future<File?> _cropFaceFromImage(File imageFile, Face face) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final faceRect = face.boundingBox;
      final x = max(0, faceRect.left.toInt());
      final y = max(0, faceRect.top.toInt());
      final w = min(image.width - x, faceRect.width.toInt());
      final h = min(image.height - y, faceRect.height.toInt());

      if (w <= 0 || h <= 0) return null;

      final croppedImage = img.copyCrop(image, x: x, y: y, width: w, height: h);
      final enhancedImage = _enhanceFaceImage(croppedImage);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final croppedFile = File('${tempDir.path}/cropped_face_$timestamp.jpg');
      await croppedFile.writeAsBytes(img.encodeJpg(enhancedImage));

      return croppedFile;
    } catch (e) {
      return null;
    }
  }

  img.Image _enhanceFaceImage(img.Image image) {
    var processedImage = img.grayscale(image);
    processedImage = img.copyResize(processedImage, width: 100, height: 100);

    for (int y = 0; y < processedImage.height; y++) {
      for (int x = 0; x < processedImage.width; x++) {
        final pixel = processedImage.getPixel(x, y);
        final luminance = pixel.r.toInt();
        final normalized = (luminance / 255.0 * 255).toInt().clamp(0, 255);
        processedImage.setPixelRgba(x, y, normalized, normalized, normalized, 255);
      }
    }

    processedImage = img.gaussianBlur(processedImage, radius: 1);
    processedImage = img.contrast(processedImage, contrast: 120);

    return processedImage;
  }

  Uint8List _extractFaceTemplate(img.Image image) {
    List<int> template = [];

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        template.add(pixel.r.toInt());
      }
    }

    int blockSize = 16;
    int blocksX = image.width ~/ blockSize;
    int blocksY = image.height ~/ blockSize;

    for (int by = 0; by < blocksY; by++) {
      for (int bx = 0; bx < blocksX; bx++) {
        List<int> blockPixels = [];
        for (int y = by * blockSize; y < (by + 1) * blockSize && y < image.height; y++) {
          for (int x = bx * blockSize; x < (bx + 1) * blockSize && x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            blockPixels.add(pixel.r.toInt());
          }
        }

        if (blockPixels.isNotEmpty) {
          int sum = blockPixels.reduce((a, b) => a + b);
          int avg = sum ~/ blockPixels.length;
          template.add(avg);

          int minVal = blockPixels.reduce((a, b) => a < b ? a : b);
          int maxVal = blockPixels.reduce((a, b) => a > b ? a : b);
          template.add(maxVal - minVal);

          double variance = 0;
          for (int val in blockPixels) {
            variance += (val - avg) * (val - avg);
          }
          variance /= blockPixels.length;
          template.add(variance.toInt());
        }
      }
    }

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width - 1; x++) {
        final pixel1 = image.getPixel(x, y);
        final pixel2 = image.getPixel(x + 1, y);
        int gradient = (pixel2.r.toInt() - pixel1.r.toInt()).abs();
        template.add(gradient);
      }
    }

    for (int y = 0; y < image.height - 1; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel1 = image.getPixel(x, y);
        final pixel2 = image.getPixel(x, y + 1);
        int gradient = (pixel2.r.toInt() - pixel1.r.toInt()).abs();
        template.add(gradient);
      }
    }

    for (int y = 0; y < image.height - 1; y++) {
      for (int x = 0; x < image.width - 1; x++) {
        final pixel1 = image.getPixel(x, y);
        final pixel2 = image.getPixel(x + 1, y + 1);
        int gradient = (pixel2.r.toInt() - pixel1.r.toInt()).abs();
        template.add(gradient);
      }
    }

    return Uint8List.fromList(template);
  }

  Future<void> performFaceRecognition() async {
    matchResults.clear();

    List<Uint8List> faceTemplates = [];
    for (var face in croppedFaces) {
      final bytes = await face.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        final template = _extractFaceTemplate(image);
        faceTemplates.add(template);
      } else {
        faceTemplates.add(Uint8List(0));
      }
    }

    List<List<double>> similarityMatrix = [];
    for (int i = 0; i < croppedFaces.length; i++) {
      List<double> row = [];
      for (int j = 0; j < userReferences.length; j++) {
        if (faceTemplates[i].isEmpty || userReferences[j].faceTemplate == null) {
          row.add(0.0);
        } else {
          double similarity = _compareFaceTemplates(faceTemplates[i], userReferences[j].faceTemplate!);
          row.add(similarity);
        }
      }
      similarityMatrix.add(row);
    }

    Set<int> assignedUsers = {};
    Set<int> assignedFaces = {};

    for (int faceIdx = 0; faceIdx < croppedFaces.length; faceIdx++) {
      if (assignedFaces.contains(faceIdx)) continue;

      double maxSimilarity = 0.0;
      int bestUserIdx = -1;

      for (int userIdx = 0; userIdx < userReferences.length; userIdx++) {
        if (assignedUsers.contains(userIdx)) continue;

        double similarity = similarityMatrix[faceIdx][userIdx];
        if (similarity > maxSimilarity && similarity > recognitionThreshold) {
          maxSimilarity = similarity;
          bestUserIdx = userIdx;
        }
      }

      if (bestUserIdx != -1) {
        double secondBestSimilarity = 0.0;
        for (int userIdx = 0; userIdx < userReferences.length; userIdx++) {
          if (userIdx == bestUserIdx) continue;
          double similarity = similarityMatrix[faceIdx][userIdx];
          if (similarity > secondBestSimilarity) {
            secondBestSimilarity = similarity;
          }
        }

        if (maxSimilarity - secondBestSimilarity >= minimumConfidenceGap) {
          matchResults.add(FaceMatchResult(
            croppedFace: croppedFaces[faceIdx],
            isMatched: true,
            matchedUserName: userReferences[bestUserIdx].name,
            similarity: maxSimilarity,
          ));
          assignedUsers.add(bestUserIdx);
          assignedFaces.add(faceIdx);
        }
      }
    }

    for (int faceIdx = 0; faceIdx < croppedFaces.length; faceIdx++) {
      if (assignedFaces.contains(faceIdx)) continue;

      double maxSimilarity = 0.0;
      int bestUserIdx = -1;

      for (int userIdx = 0; userIdx < userReferences.length; userIdx++) {
        if (assignedUsers.contains(userIdx)) continue;

        double similarity = similarityMatrix[faceIdx][userIdx];
        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          bestUserIdx = userIdx;
        }
      }

      if (bestUserIdx != -1 && maxSimilarity > recognitionThreshold) {
        matchResults.add(FaceMatchResult(
          croppedFace: croppedFaces[faceIdx],
          isMatched: true,
          matchedUserName: userReferences[bestUserIdx].name,
          similarity: maxSimilarity,
        ));
        assignedUsers.add(bestUserIdx);
        assignedFaces.add(faceIdx);
      } else {
        matchResults.add(FaceMatchResult(
          croppedFace: croppedFaces[faceIdx],
          isMatched: false,
          matchedUserName: null,
          similarity: maxSimilarity,
        ));
      }
    }
  }

  double _compareFaceTemplates(Uint8List template1, Uint8List template2) {
    if (template1.isEmpty || template2.isEmpty) return 0.0;

    int minLength = template1.length < template2.length ? template1.length : template2.length;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < minLength; i++) {
      dotProduct += template1[i].toDouble() * template2[i].toDouble();
      norm1 += template1[i].toDouble() * template1[i].toDouble();
      norm2 += template2[i].toDouble() * template2[i].toDouble();
    }

    double cosineSimilarity = 0.0;
    if (norm1 > 0 && norm2 > 0) {
      cosineSimilarity = dotProduct / (sqrt(norm1) * sqrt(norm2));
    }

    double sumSquaredDiff = 0.0;
    for (int i = 0; i < minLength; i++) {
      double diff = (template1[i] - template2[i]).toDouble();
      sumSquaredDiff += diff * diff;
    }
    double euclideanDistance = sqrt(sumSquaredDiff);
    double maxPossibleDistance = sqrt(minLength.toDouble() * 255 * 255);
    double normalizedEuclidean = 1.0 - (euclideanDistance / maxPossibleDistance);

    int exactMatches = 0;
    for (int i = 0; i < minLength; i++) {
      if (template1[i] == template2[i]) {
        exactMatches++;
      }
    }
    double exactMatchRatio = exactMatches / minLength.toDouble();

    double mean1 = 0.0;
    double mean2 = 0.0;
    for (int i = 0; i < minLength; i++) {
      mean1 += template1[i].toDouble();
      mean2 += template2[i].toDouble();
    }
    mean1 /= minLength;
    mean2 /= minLength;

    double covariance = 0.0;
    double variance1 = 0.0;
    double variance2 = 0.0;

    for (int i = 0; i < minLength; i++) {
      double diff1 = template1[i].toDouble() - mean1;
      double diff2 = template2[i].toDouble() - mean2;
      covariance += diff1 * diff2;
      variance1 += diff1 * diff1;
      variance2 += diff2 * diff2;
    }

    double pearsonCorrelation = 0.0;
    if (variance1 > 0 && variance2 > 0) {
      pearsonCorrelation = covariance / (sqrt(variance1) * sqrt(variance2));
    }

    double compositeScore = (cosineSimilarity * 0.4) +
        (normalizedEuclidean * 0.3) +
        (exactMatchRatio * 0.2) +
        (pearsonCorrelation * 0.1);

    return compositeScore.clamp(0.0, 1.0);
  }

  Future<List<RecognitionResult>> _convertMatchResults(List<FaceMatchResult> matchResults) async {
    List<RecognitionResult> results = [];

    for (var result in matchResults) {
      results.add(RecognitionResult(
        isMatched: result.isMatched,
        name: result.matchedUserName ?? 'Unknown',
        croppedImagePath: result.croppedFace.path,
        similarity: result.similarity,
      ));
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = currentImageIndex;
    final bool hasImage = images.length > currentIndex && images[currentIndex] != null;

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            "Offline Attendance",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Loading user references...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: Padding(
          padding: EdgeInsets.only(left: 18),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Icon(Icons.arrow_back_ios),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Offline Attendance",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Capture Attendance (Offline Mode)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () => pickImageAndUpload(context),
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black12,
                  ),
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            images[currentIndex]!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade300,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(height: 20),
              if (hasError.contains(true))
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Please capture the image before proceeding.",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              SizedBox(height: 10),
              Row(
                children: [
                  if (hasImage)
                    Expanded(
                      child: PrimaryButton(
                        onTap: () => removeImage(currentIndex),
                        height: 48,
                        borderRadius: 10,
                        color: const Color(0xFFE53935),
                        child: Text(
                          "Retake",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ),
                    ),
                  if (hasImage) SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      onTap: () async {
                        if (!hasImage) {
                          await pickImageAndUpload(context);
                          return;
                        }
                        final image = images[currentIndex];
                        if (image != null) {
                          moveToNextImage();
                        }
                      },
                      height: 48,
                      borderRadius: 10,
                      color: hasImage
                          ? const Color(0xFF00B4D8)
                          : const Color(0xFF19CA74),
                      child: Text(
                        hasImage ? "Capture More" : "Capture",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              if (images.any((img) => img != null)) ...[
                Text(
                  "Captured Images",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final file = images[index];
                    return GestureDetector(
                      onTap: () => setState(() {
                        currentImageIndex = index;
                      }),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: index == currentImageIndex
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: file != null
                              ? Image.file(file, fit: BoxFit.cover)
                              : Icon(Icons.camera_alt,
                                  size: 40, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 20),
                PrimaryButton(
                  onTap: () async {
                    if (images.where((img) => img != null).isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please capture at least one image')),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    await processAllCapturedImages(context);

                    Navigator.pop(context);

                    if (widget.isDemo) {
                      final demoResults = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserSelectionScreen(
                            croppedFaces: croppedFaces,
                          ),
                        ),
                      );

                      if (demoResults != null && widget.onComplete != null) {
                        widget.onComplete!(demoResults);
                      }
                    } else {
                      if (userReferences.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'No user references found. Please add users first.')),
                        );
                        return;
                      }

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      await performFaceRecognition();

                      Navigator.pop(context);

                      final results = await _convertMatchResults(matchResults);

                      if (widget.onComplete != null) {
                        widget.onComplete!(results);
                      }
                    }
                  },
                  height: 48,
                  borderRadius: 10,
                  color: const Color(0xFF19CA74),
                  child: Text(
                    "Proceed",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}
