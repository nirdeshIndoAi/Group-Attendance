import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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

class FaceRecognitionViewModel extends ChangeNotifier {
  int currentImageIndex = 0;
  List<File?> images = [];
  List<bool> hasError = [];
  bool isImagePicked = false;
  List<File> croppedFaces = [];
  List<Uint8List> extractedTemplates = [];
  bool isProcessingInBackground = false;
  int _activeBackgroundJobs = 0;
  Map<int, bool> imageProcessingComplete = {};
  Map<int, List<File>> imageProcessedFaces = {};
  Map<int, List<Uint8List>> imageProcessedTemplates = {};
  
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

  bool get allImagesProcessed {
    if (images.isEmpty) return true;
    for (int i = 0; i < images.length; i++) {
      if (images[i] != null && imageProcessingComplete[i] != true) {
        return false;
      }
    }
    return true;
  }

  double get processingProgress {
    if (images.isEmpty) return 1.0;
    int total = images.where((img) => img != null).length;
    if (total == 0) return 1.0;
    int processed = imageProcessingComplete.values.where((v) => v == true).length;
    return processed / total;
  }

  void setImages(List<File?> newImages) {
    images = newImages;
    notifyListeners();
  }

  void setCurrentImageIndex(int index) {
    currentImageIndex = index;
    notifyListeners();
  }

  void moveToNextImage() {
    currentImageIndex++;
    if (images.length <= currentImageIndex) {
      images.add(null);
      hasError.add(false);
    }
    notifyListeners();
  }

  void removeImage(int index) {
    images[index] = null;
    notifyListeners();
  }

  Future<void> extractFacesFromGroupPhoto(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      return;
    }

    final imageBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      return;
    }

    for (int i = 0; i < faces.length; i++) {
      var face = faces[i];
      final rect = face.boundingBox;

      int x = rect.left.toInt().clamp(0, decodedImage.width - 1);
      int y = rect.top.toInt().clamp(0, decodedImage.height - 1);
      int w = rect.width.toInt().clamp(1, decodedImage.width - x);
      int h = rect.height.toInt().clamp(1, decodedImage.height - y);

      final cropped = img.copyCrop(
        decodedImage,
        x: x,
        y: y,
        width: w,
        height: h,
      );
      final resized = img.copyResize(cropped, width: 200, height: 200);
      final enhanced = _enhanceFaceCV(resized);
      final croppedBytes = img.encodeJpg(enhanced, quality: 90);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      await file.writeAsBytes(croppedBytes);

      try {
        Uint8List? template = await _extractFaceTemplate(file);
        if (template != null) {
          extractedTemplates.add(template);
        }
      } catch (e) {
        continue;
      }

      croppedFaces.add(file);
    }

    notifyListeners();
  }

  Future<void> processAllCapturedImages(BuildContext context) async {
    if (isProcessingInBackground) {
      int waitCount = 0;
      while (isProcessingInBackground && waitCount < 600) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
    }

    croppedFaces.clear();
    extractedTemplates.clear();

    for (int i = 0; i < images.length; i++) {
      var img = images[i];

      if (img == null) continue;

      if (imageProcessingComplete[i] == true) {
        if (imageProcessedFaces[i] != null) {
          croppedFaces.addAll(imageProcessedFaces[i]!);
        }
        if (imageProcessedTemplates[i] != null) {
          extractedTemplates.addAll(imageProcessedTemplates[i]!);
        }
      } else {
        await extractFacesFromGroupPhoto(img);
      }
    }

    notifyListeners();
  }

  void clearData(BuildContext context) {
    images.clear();
    croppedFaces.clear();
    extractedTemplates.clear();
    currentImageIndex = 0;
    hasError = [];

    imageProcessingComplete.clear();
    imageProcessedFaces.clear();
    imageProcessedTemplates.clear();
    isProcessingInBackground = false;

    notifyListeners();
  }

  void markImagePicked() {
    isImagePicked = true;
    notifyListeners();
  }

  Future<void> pickImageAndUpload(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
    );
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      int imageIndex = currentImageIndex;

      if (images.length <= currentImageIndex) {
        images.add(imageFile);
        hasError.add(false);
      } else {
        images[currentImageIndex] = imageFile;
        hasError[currentImageIndex] = false;
      }

      notifyListeners();

      _startBackgroundJob();
      _processImageInBackground(imageFile, imageIndex, context).then((_) {
        _finishBackgroundJob();
      }).catchError((error) {
        _finishBackgroundJob();
      });
    } else {
      if (hasError.length <= currentImageIndex) {
        hasError.add(true);
      } else {
        hasError[currentImageIndex] = true;
      }
      notifyListeners();
    }
  }

  Future<void> _processImageInBackground(File imageFile, int imageIndex, BuildContext context) async {
    try {
      isProcessingInBackground = true;
      imageProcessingComplete[imageIndex] = false;

      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        imageProcessingComplete[imageIndex] = false;
        isProcessingInBackground = false;
        return;
      }

      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        imageProcessingComplete[imageIndex] = false;
        isProcessingInBackground = false;
        return;
      }

      List<Face> sortedFaces = List.from(faces);
      sortedFaces.sort((a, b) {
        double areaA = a.boundingBox.width * a.boundingBox.height;
        double areaB = b.boundingBox.width * b.boundingBox.height;
        return areaB.compareTo(areaA);
      });

      const maxFacesToProcess = 20;
      int facesToProcess = sortedFaces.length > maxFacesToProcess ? maxFacesToProcess : sortedFaces.length;

      List<File> processedFaces = [];
      List<Uint8List> processedTemplates = [];

      for (int i = 0; i < facesToProcess; i++) {
        var face = sortedFaces[i];
        final rect = face.boundingBox;

        int x = rect.left.toInt().clamp(0, decodedImage.width - 1);
        int y = rect.top.toInt().clamp(0, decodedImage.height - 1);
        int w = rect.width.toInt().clamp(1, decodedImage.width - x);
        int h = rect.height.toInt().clamp(1, decodedImage.height - y);

        final cropped = img.copyCrop(
          decodedImage,
          x: x,
          y: y,
          width: w,
          height: h,
        );
        final resized = img.copyResize(cropped, width: 200, height: 200);
        final enhanced = _enhanceFaceCV(resized);
        final croppedBytes = img.encodeJpg(enhanced, quality: 90);

        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await file.writeAsBytes(croppedBytes);

        try {
          Uint8List? template = await _extractFaceTemplate(file);
          if (template != null) {
            processedTemplates.add(template);
            processedFaces.add(file);
          }
        } catch (e) {
          continue;
        }
      }

      imageProcessedFaces[imageIndex] = processedFaces;
      imageProcessedTemplates[imageIndex] = processedTemplates;
      imageProcessingComplete[imageIndex] = true;

      isProcessingInBackground = _activeBackgroundJobs > 0;
    } catch (e) {
      imageProcessingComplete[imageIndex] = false;
      isProcessingInBackground = _activeBackgroundJobs > 0;
    }
  }

  void _startBackgroundJob() {
    _activeBackgroundJobs++;
    isProcessingInBackground = true;
  }

  void _finishBackgroundJob() {
    if (_activeBackgroundJobs > 0) {
      _activeBackgroundJobs--;
    }
    isProcessingInBackground = _activeBackgroundJobs > 0;
  }

  Future<File?> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    List<int> imageBytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(Uint8List.fromList(imageBytes));
    if (image == null) return null;
    int targetWidth = 800;
    int targetHeight = (image.height * targetWidth) ~/ image.width;
    img.Image resizedImage = img.copyResize(image, width: targetWidth, height: targetHeight);
    List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 70);
    File compressedFile = File(targetPath)..writeAsBytesSync(compressedBytes);
    if (await compressedFile.length() > 500 * 1024) {
      return compressImage(compressedFile);
    }
    return compressedFile;
  }

  img.Image _enhanceFaceCV(img.Image face) {
    final base = face;
    final blurred = img.gaussianBlur(base, radius: 1);
    final sharpened = base.clone();
    const amount = 1.3;
    for (int y = 0; y < base.height; y++) {
      for (int x = 0; x < base.width; x++) {
        final o = base.getPixel(x, y);
        final b = blurred.getPixel(x, y);
        final r = (o.r + (o.r - b.r) * amount).round().clamp(0, 255);
        final g = (o.g + (o.g - b.g) * amount).round().clamp(0, 255);
        final bl = (o.b + (o.b - b.b) * amount).round().clamp(0, 255);
        sharpened.setPixelRgba(x, y, r, g, bl, o.a.round().toInt());
      }
    }
    var enhanced = img.adjustColor(
      sharpened,
      contrast: 1.1,
      saturation: 0.95,
      brightness: 1.03,
    );
    enhanced = img.normalize(enhanced, min: 0, max: 255);
    return enhanced;
  }

  Future<void> addUserReference(String name, BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await _extractAndStoreUserTemplate(name, imageFile);
      notifyListeners();
    }
  }

  Future<void> _extractAndStoreUserTemplate(String name, File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      return;
    }

    final imageBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      return;
    }

    var face = faces[0];
    final rect = face.boundingBox;

    int x = rect.left.toInt().clamp(0, decodedImage.width - 1);
    int y = rect.top.toInt().clamp(0, decodedImage.height - 1);
    int w = rect.width.toInt().clamp(1, decodedImage.width - x);
    int h = rect.height.toInt().clamp(1, decodedImage.height - y);

    final cropped = img.copyCrop(
      decodedImage,
      x: x,
      y: y,
      width: w,
      height: h,
    );
    final resized = img.copyResize(cropped, width: 200, height: 200);
    final enhanced = _enhanceFaceCV(resized);
    final croppedBytes = img.encodeJpg(enhanced, quality: 90);

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/user_${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(croppedBytes);

    Uint8List? template = await _extractFaceTemplate(file);

    userReferences.add(UserReference(
      name: name,
      photo: file,
      faceTemplate: template,
    ));
  }

  Future<Uint8List?> _extractFaceTemplate(File faceImage) async {
    final imageBytes = await faceImage.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      return null;
    }

    final resized = img.copyResize(decodedImage, width: 96, height: 96);
    final grayscale = img.grayscale(resized);
    final normalized = img.normalize(grayscale, min: 0, max: 255);

    List<int> featureVector = [];
    
    const int gridSize = 12;
    final int blockWidth = normalized.width ~/ gridSize;
    final int blockHeight = normalized.height ~/ gridSize;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        int blockSum = 0;
        int blockMin = 255;
        int blockMax = 0;
        int blockCount = 0;
        
        int startY = i * blockHeight;
        int endY = (i + 1) * blockHeight;
        int startX = j * blockWidth;
        int endX = (j + 1) * blockWidth;
        
        for (int y = startY; y < endY; y++) {
          for (int x = startX; x < endX; x++) {
            final pixel = normalized.getPixel(x, y);
            int value = pixel.r.toInt();
            blockSum += value;
            blockCount++;
            if (value < blockMin) blockMin = value;
            if (value > blockMax) blockMax = value;
          }
        }
        
        int blockAvg = blockSum ~/ blockCount;
        int blockRange = blockMax - blockMin;
        int blockVariance = 0;
        
        for (int y = startY; y < endY; y++) {
          for (int x = startX; x < endX; x++) {
            final pixel = normalized.getPixel(x, y);
            int value = pixel.r.toInt();
            int diff = value - blockAvg;
            blockVariance += (diff * diff);
          }
        }
        blockVariance = (blockVariance ~/ blockCount).clamp(0, 255);
        
        featureVector.add(blockAvg);
        featureVector.add(blockRange);
        featureVector.add(blockVariance);
      }
    }

    List<int> horizontalGradients = [];
    List<int> verticalGradients = [];
    List<int> diagonalGradients = [];
    
    for (int y = 2; y < normalized.height - 2; y += 3) {
      for (int x = 2; x < normalized.width - 2; x += 3) {
        final left = normalized.getPixel(x - 2, y).r.toInt();
        final right = normalized.getPixel(x + 2, y).r.toInt();
        final top = normalized.getPixel(x, y - 2).r.toInt();
        final bottom = normalized.getPixel(x, y + 2).r.toInt();
        final topLeft = normalized.getPixel(x - 1, y - 1).r.toInt();
        final bottomRight = normalized.getPixel(x + 1, y + 1).r.toInt();
        
        int hGrad = ((right - left).abs()).clamp(0, 255);
        int vGrad = ((bottom - top).abs()).clamp(0, 255);
        int dGrad = ((bottomRight - topLeft).abs()).clamp(0, 255);
        
        horizontalGradients.add(hGrad);
        verticalGradients.add(vGrad);
        diagonalGradients.add(dGrad);
      }
    }

    featureVector.addAll(horizontalGradients);
    featureVector.addAll(verticalGradients);
    featureVector.addAll(diagonalGradients);

    return Uint8List.fromList(featureVector);
  }

  void removeUserReference(int index) {
    if (index >= 0 && index < userReferences.length) {
      userReferences.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> performFaceRecognition() async {

    matchResults.clear();

    if (croppedFaces.isEmpty) {
      return;
    }

    if (userReferences.isEmpty) {
      return;
    }

    Map<int, List<Map<String, dynamic>>> faceToUserScores = {};

    for (int i = 0; i < croppedFaces.length; i++) {
      File croppedFace = croppedFaces[i];
      Uint8List? croppedTemplate = i < extractedTemplates.length ? extractedTemplates[i] : null;


      if (croppedTemplate == null) {
        faceToUserScores[i] = [];
        continue;
      }


      List<Map<String, dynamic>> userScores = [];


      for (int j = 0; j < userReferences.length; j++) {
        UserReference userRef = userReferences[j];
        
        if (userRef.faceTemplate == null) {
          continue;
        }

        Map<String, double> similarity = await _compareFaceTemplates(croppedTemplate, userRef.faceTemplate!);


        userScores.add({
          'userName': userRef.name,
          'similarity': similarity['final']!,
          'faceIndex': i,
          'croppedFace': croppedFace,
        });
      }

      userScores.sort((a, b) => b['similarity'].compareTo(a['similarity']));
      faceToUserScores[i] = userScores;
    }

    
    List<Map<String, dynamic>> allPossibleMatches = [];
    
    for (int faceIndex in faceToUserScores.keys) {
      List<Map<String, dynamic>> userScores = faceToUserScores[faceIndex]!;
      
      if (userScores.isEmpty) continue;
      
      userScores.sort((a, b) => b['similarity'].compareTo(a['similarity']));
      
      double bestScore = userScores[0]['similarity'];
      double secondBestScore = userScores.length > 1 ? userScores[1]['similarity'] : 0.0;
      double confidenceGap = bestScore - secondBestScore;
      String bestUserName = userScores[0]['userName'];
      
      bool meetsThreshold = bestScore >= recognitionThreshold;
      bool hasConfidence = userScores.length == 1 || confidenceGap >= minimumConfidenceGap;
      
      if (meetsThreshold && hasConfidence) {
        allPossibleMatches.add({
          'faceIndex': faceIndex,
          'userName': bestUserName,
          'similarity': bestScore,
          'confidenceGap': confidenceGap,
          'matchQuality': bestScore * (1.0 + confidenceGap),
        });
      }
    }
    
    allPossibleMatches.sort((a, b) => b['matchQuality'].compareTo(a['matchQuality']));
    
    
    Set<String> alreadyMatchedUsers = {};
    Set<int> alreadyMatchedFaces = {};
    Map<int, Map<String, dynamic>> faceAssignments = {};
    
    for (var match in allPossibleMatches) {
      int faceIndex = match['faceIndex'];
      String userName = match['userName'];
      double similarity = match['similarity'];
      
      if (alreadyMatchedFaces.contains(faceIndex)) {
        continue;
      }
      
      if (alreadyMatchedUsers.contains(userName)) {
        continue;
      }
      
      faceAssignments[faceIndex] = {
        'matched': true,
        'userName': userName,
        'similarity': similarity,
      };
      alreadyMatchedUsers.add(userName);
      alreadyMatchedFaces.add(faceIndex);
    }
    
    List<int> unmatchedFaces = [];
    for (int faceIndex in faceToUserScores.keys) {
      if (!alreadyMatchedFaces.contains(faceIndex)) {
        unmatchedFaces.add(faceIndex);
      }
    }
    
    List<String> unmatchedUsers = [];
    for (var userRef in userReferences) {
      if (!alreadyMatchedUsers.contains(userRef.name)) {
        unmatchedUsers.add(userRef.name);
      }
    }
    
    if (unmatchedFaces.isNotEmpty && unmatchedUsers.isNotEmpty) {
      
      List<Map<String, dynamic>> secondPassMatches = [];
      
      for (int faceIndex in unmatchedFaces) {
        List<Map<String, dynamic>> userScores = faceToUserScores[faceIndex]!;
        
        for (var userScore in userScores) {
          String userName = userScore['userName'];
          double similarity = userScore['similarity'];
          
          if (unmatchedUsers.contains(userName) && similarity >= recognitionThreshold) {
            secondPassMatches.add({
              'faceIndex': faceIndex,
              'userName': userName,
              'similarity': similarity,
            });
          }
        }
      }
      
      secondPassMatches.sort((a, b) => b['similarity'].compareTo(a['similarity']));
      
      Set<int> pass2MatchedFaces = {};
      Set<String> pass2MatchedUsers = {};
      
      for (var match in secondPassMatches) {
        int faceIndex = match['faceIndex'];
        String userName = match['userName'];
        double similarity = match['similarity'];
        
        if (pass2MatchedFaces.contains(faceIndex) || pass2MatchedUsers.contains(userName)) {
          continue;
        }
        
        faceAssignments[faceIndex] = {
          'matched': true,
          'userName': userName,
          'similarity': similarity,
        };
        alreadyMatchedUsers.add(userName);
        alreadyMatchedFaces.add(faceIndex);
        pass2MatchedFaces.add(faceIndex);
        pass2MatchedUsers.add(userName);
      }
    }
    
    for (int faceIndex in faceToUserScores.keys) {
      if (!faceAssignments.containsKey(faceIndex)) {
        List<Map<String, dynamic>> userScores = faceToUserScores[faceIndex]!;
        
        if (userScores.isEmpty) {
          faceAssignments[faceIndex] = {
            'matched': false,
            'userName': null,
            'similarity': 0.0,
          };
        } else {
          double bestScore = userScores[0]['similarity'];
          
          faceAssignments[faceIndex] = {
            'matched': false,
            'userName': null,
            'similarity': bestScore,
          };
        }
      }
    }

    for (int i = 0; i < croppedFaces.length; i++) {
      File croppedFace = croppedFaces[i];
      var assignment = faceAssignments[i] ?? {
        'matched': false,
        'userName': null,
        'similarity': 0.0,
      };

      matchResults.add(FaceMatchResult(
        croppedFace: croppedFace,
        isMatched: assignment['matched'],
        matchedUserName: assignment['userName'],
        similarity: assignment['similarity'],
      ));
    }

    if (matchResults.where((r) => !r.isMatched).length > matchResults.where((r) => r.isMatched).length) {
    }

    notifyListeners();
  }

  Future<Map<String, double>> _compareFaceTemplates(Uint8List template1, Uint8List template2) async {
    if (template1.length != template2.length) {
      int minLength = template1.length < template2.length ? template1.length : template2.length;
      template1 = Uint8List.fromList(template1.sublist(0, minLength));
      template2 = Uint8List.fromList(template2.sublist(0, minLength));
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < template1.length; i++) {
      double val1 = template1[i].toDouble();
      double val2 = template2[i].toDouble();
      
      dotProduct += val1 * val2;
      norm1 += val1 * val1;
      norm2 += val2 * val2;
    }

    double cosineSimilarity = 0.0;
    if (norm1 > 0 && norm2 > 0) {
      cosineSimilarity = dotProduct / (sqrt(norm1) * sqrt(norm2));
    }

    double euclideanDistance = 0.0;
    for (int i = 0; i < template1.length; i++) {
      double diff = template1[i].toDouble() - template2[i].toDouble();
      euclideanDistance += diff * diff;
    }
    euclideanDistance = sqrt(euclideanDistance);
    
    double maxPossibleDistance = sqrt(template1.length * 255 * 255);
    double normalizedDistance = 1.0 - (euclideanDistance / maxPossibleDistance);

    int exactMatches = 0;
    for (int i = 0; i < template1.length; i++) {
      if ((template1[i] - template2[i]).abs() < 15) {
        exactMatches++;
      }
    }
    double exactMatchRatio = exactMatches / template1.length;

    double correlationSum1 = 0.0;
    double correlationSum2 = 0.0;
    for (int i = 0; i < template1.length; i++) {
      correlationSum1 += template1[i].toDouble();
      correlationSum2 += template2[i].toDouble();
    }
    double mean1 = correlationSum1 / template1.length;
    double mean2 = correlationSum2 / template2.length;
    
    double correlation = 0.0;
    double std1 = 0.0;
    double std2 = 0.0;
    
    for (int i = 0; i < template1.length; i++) {
      double diff1 = template1[i] - mean1;
      double diff2 = template2[i] - mean2;
      correlation += diff1 * diff2;
      std1 += diff1 * diff1;
      std2 += diff2 * diff2;
    }
    
    double pearsonCorrelation = 0.0;
    if (std1 > 0 && std2 > 0) {
      pearsonCorrelation = correlation / (sqrt(std1) * sqrt(std2));
      pearsonCorrelation = (pearsonCorrelation + 1.0) / 2.0;
    }

    double finalSimilarity = (
      cosineSimilarity * 0.40 + 
      normalizedDistance * 0.30 + 
      exactMatchRatio * 0.20 + 
      pearsonCorrelation * 0.10
    );

    finalSimilarity = finalSimilarity.clamp(0.0, 1.0);

    return {
      'final': finalSimilarity,
      'cosine': cosineSimilarity,
      'distance': normalizedDistance,
      'exactMatch': exactMatchRatio,
      'correlation': pearsonCorrelation,
    };
  }

  void clearUserReferences() {
    userReferences.clear();
    notifyListeners();
  }

  void clearMatchResults() {
    matchResults.clear();
    notifyListeners();
  }

  void adjustRecognitionThreshold(double newThreshold) {
    recognitionThreshold = newThreshold.clamp(0.0, 1.0);
    notifyListeners();
  }

  void adjustConfidenceGap(double newGap) {
    minimumConfidenceGap = newGap.clamp(0.0, 0.5);
    notifyListeners();
  }

  Future<void> addUserReferenceFromFile(String name, File imageFile) async {
    await _extractAndStoreUserTemplate(name, imageFile);
    notifyListeners();
  }
}
