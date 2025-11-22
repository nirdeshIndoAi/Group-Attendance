import 'dart:convert';
import 'dart:typed_data';

class EndpointEncryption {
  static const _key = 'GA_NATIVE_SECURE_SALT_2024';

  static String encrypt(String plaintext) {
    try {
      final plainBytes = utf8.encode(plaintext);
      final keyBytes = utf8.encode(_key);
      final encrypted = Uint8List(plainBytes.length);

      for (int i = 0; i < plainBytes.length; i++) {
        encrypted[i] = plainBytes[i] ^ keyBytes[i % keyBytes.length];
      }

      return base64.encode(encrypted);
    } catch (e) {
      return plaintext;
    }
  }
}

