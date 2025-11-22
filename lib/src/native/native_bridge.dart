import 'dart:typed_data';

import 'package:flutter/services.dart';

class NativeSecurityBridge {
  static const MethodChannel _channel = MethodChannel('face_recognition_sdk/native');

  static Future<Map<String, double>> compareTemplates(
    Uint8List template1,
    Uint8List template2,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'compareTemplates',
      {
        'template1': template1,
        'template2': template2,
      },
    );

    if (result == null) {
      return const {
        'final': 0,
        'cosine': 0,
        'distance': 0,
        'exactMatch': 0,
        'correlation': 0,
      };
    }

    return result.map(
      (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
    );
  }

  static Future<bool> validateLicense({
    required String licenseKey,
    required String appId,
    required String endpoint,
  }) async {
    final result = await _channel.invokeMethod<bool>(
      'validateLicense',
      {
        'licenseKey': licenseKey,
        'appId': appId,
        'endpoint': endpoint,
      },
    );

    return result ?? false;
  }

  static Future<String?> fetchIntegritySignature(String challenge) async {
    final result = await _channel.invokeMethod<String>(
      'verifyIntegrity',
      {'challenge': challenge},
    );
    return result;
  }
}

