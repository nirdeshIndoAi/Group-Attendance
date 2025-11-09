# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-11-09

### Added
- Initial release of Face Recognition SDK
- Multiple image selection from gallery
- Automatic face detection using Google ML Kit
- Face cropping and enhancement
- Advanced face recognition with composite similarity scoring
- Demo mode for manual user selection
- Production mode with reference-based recognition
- One-to-one matching algorithm with confidence thresholds
- Configurable recognition parameters
- Comprehensive example app
- Full documentation and API reference

### Features
- Multi-metric face recognition (Cosine Similarity, Euclidean Distance, Exact Match Ratio, Pearson Correlation)
- Two-pass assignment strategy for optimal matching
- Face image preprocessing (normalization, sharpening, noise reduction)
- Block-based feature extraction (averages, ranges, variances, gradients)
- Adjustable recognition thresholds and confidence gaps
- Clean and intuitive widget-based API

### Dependencies
- Flutter SDK: >=3.7.2
- provider: ^6.1.2
- google_mlkit_face_detection: ^0.10.0
- image_picker: ^1.0.7
- image: ^4.1.7
- path_provider: ^2.1.2

