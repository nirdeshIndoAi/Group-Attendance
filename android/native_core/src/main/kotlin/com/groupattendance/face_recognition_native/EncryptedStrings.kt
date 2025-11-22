package com.groupattendance.face_recognition_native

object EncryptedStrings {
    private var decryptionKey: String? = null
    
    const val STR_INTEGRITY_SECRET = 1
    const val STR_TEMP_DECRYPTION_KEY = 2
    const val STR_PREFS_NAME = 3
    const val STR_KEY_DECRYPTION_KEY = 4
    const val STR_KEY_CONFIG_CACHE = 5
    const val STR_ALGORITHM_CONFIG_ENC = 6
    const val STR_WEIGHTS = 7
    const val STR_COSINE = 8
    const val STR_DISTANCE = 9
    const val STR_EXACT_MATCH = 10
    const val STR_CORRELATION = 11
    const val STR_THRESHOLDS = 12
    const val STR_MATCH = 13
    const val STR_EXACT_MATCH_TOLERANCE = 14
    const val STR_MAX_DISTANCE = 15
    const val STR_NORMALIZATION_FACTOR = 16
    const val STR_TAMPERED = 17
    const val STR_POST = 18
    const val STR_ACCEPT = 19
    const val STR_USER_AGENT = 20
    const val STR_API_KEY = 21
    const val STR_APP_ID = 22
    const val STR_SUCCESS = 23
    const val STR_STATUS = 24
    const val STR_VALID = 25
    const val STR_IS_VALID = 26
    const val STR_AUTHORIZED = 27
    const val STR_MESSAGE = 28
    const val STR_DECRYPTION_KEY = 29
    const val STR_FINAL = 30
    const val STR_GROUP_ATTENDANCE_SDK = 31
    const val STR_AES = 32
    const val STR_CBC_PKCS5 = 33
    const val STR_MD5 = 34
    const val STR_SHA256 = 35
    
    fun setDecryptionKey(key: String) {
        decryptionKey = key
    }
    
    fun get(id: Int): String {
        return when (id) {
            STR_INTEGRITY_SECRET -> "GA_NATIVE_SECURE_SALT_2024"
            STR_TEMP_DECRYPTION_KEY -> "GA_SDK_MASTER_KEY_2024_32_BYTES_KEY!!"
            STR_PREFS_NAME -> "face_recognition_sdk_prefs"
            STR_KEY_DECRYPTION_KEY -> "decryption_key"
            STR_KEY_CONFIG_CACHE -> "config_cache"
            STR_ALGORITHM_CONFIG_ENC -> "algorithm_config.enc"
            STR_WEIGHTS -> "weights"
            STR_COSINE -> "cosine"
            STR_DISTANCE -> "distance"
            STR_EXACT_MATCH -> "exactMatch"
            STR_CORRELATION -> "correlation"
            STR_THRESHOLDS -> "thresholds"
            STR_MATCH -> "match"
            STR_EXACT_MATCH_TOLERANCE -> "exactMatchTolerance"
            STR_MAX_DISTANCE -> "maxDistance"
            STR_NORMALIZATION_FACTOR -> "normalizationFactor"
            STR_TAMPERED -> "TAMPERED"
            STR_POST -> "POST"
            STR_ACCEPT -> "Accept"
            STR_USER_AGENT -> "User-Agent"
            STR_API_KEY -> "Api-Key"
            STR_APP_ID -> "app_id"
            STR_SUCCESS -> "success"
            STR_STATUS -> "status"
            STR_VALID -> "valid"
            STR_IS_VALID -> "is_valid"
            STR_AUTHORIZED -> "authorized"
            STR_MESSAGE -> "message"
            STR_DECRYPTION_KEY -> "decryption_key"
            STR_FINAL -> "final"
            STR_GROUP_ATTENDANCE_SDK -> "GroupAttendanceSDK/1.0.0"
            STR_AES -> "AES"
            STR_CBC_PKCS5 -> "AES/CBC/PKCS5Padding"
            STR_MD5 -> "MD5"
            STR_SHA256 -> "SHA-256"
            else -> ""
        }
    }
}
