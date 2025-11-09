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
  final double? similarity;

  RecognitionResult({
    required this.isMatched,
    required this.name,
    required this.croppedImagePath,
    this.similarity,
  });

  Map<String, dynamic> toJson() {
    return {
      'isMatched': isMatched,
      'name': name,
      'croppedImagePath': croppedImagePath,
      'similarity': similarity,
      'similarityPercentage': similarity != null ? '${(similarity! * 100).toStringAsFixed(2)}%' : null,
    };
  }
}

