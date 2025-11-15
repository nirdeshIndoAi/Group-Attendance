import 'dart:typed_data';

class SDKUserReference {
  final String name;
  final Uint8List imageBytes;

  SDKUserReference({
    required this.name,
    required this.imageBytes,
  });
}

class RecognitionResult {
  final bool isMatched;
  final String name;
  final String croppedImagePath;

  RecognitionResult({
    required this.isMatched,
    required this.name,
    required this.croppedImagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'isMatched': isMatched,
      'name': name,
      'croppedImagePath': croppedImagePath,
    };
  }
}

