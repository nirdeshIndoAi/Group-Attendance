package com.groupattendance.face_recognition_native

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import org.json.JSONObject
import java.io.DataOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.sqrt

class FaceRecognitionNative private constructor() {
    companion object {
        @Volatile
        private var instance: FaceRecognitionNative? = null
        private const val LICENSE_VALIDATION_INTERVAL = 3600000L

        @JvmStatic
        fun getInstance(): FaceRecognitionNative {
            return instance ?: synchronized(this) {
                instance ?: FaceRecognitionNative().also { instance = it }
            }
        }
    }
    
    private fun getIntegritySecret(): String {
        return EncryptedStrings.get(EncryptedStrings.STR_INTEGRITY_SECRET)
    }

    private var isTampered = false
    private var integrityChecksum: Long = 0L
    private var isLicenseValidated = false
    private var lastLicenseValidationTime: Long = 0L
    
    private var context: Context? = null
    private var decryptionKey: String? = null
    private var decryptedConfig: AlgorithmConfig? = null
    
    private fun getPrefsName(): String = EncryptedStrings.get(EncryptedStrings.STR_PREFS_NAME)
    private fun getKeyDecryptionKey(): String = EncryptedStrings.get(EncryptedStrings.STR_KEY_DECRYPTION_KEY)
    private fun getKeyConfigCache(): String = EncryptedStrings.get(EncryptedStrings.STR_KEY_CONFIG_CACHE)
    
    data class AlgorithmConfig(
        val weights: Weights,
        val thresholds: Thresholds
    ) {
        data class Weights(
            val cosine: Double,
            val distance: Double,
            val exactMatch: Double,
            val correlation: Double
        )
        
        data class Thresholds(
            val match: Double,
            val exactMatchTolerance: Int,
            val maxDistance: Double,
            val normalizationFactor: Double
        )
    }

    init {
        integrityChecksum = computeClassChecksum()
    }
    
    fun setContext(ctx: Context) {
        context = ctx.applicationContext
    }
    
    fun setDecryptionKey(key: String) {
        decryptionKey = key
        decryptedConfig = null
        EncryptedStrings.setDecryptionKey(key)
        val tempKey = EncryptedStrings.get(EncryptedStrings.STR_TEMP_DECRYPTION_KEY)
        if (key != tempKey) {
            cacheDecryptionKey(key)
        }
    }

    fun initialize(): Int {
        if (!verifyIntegrityChecksum()) {
            isTampered = true
            return -1
        }
        
        val tempKey = EncryptedStrings.get(EncryptedStrings.STR_TEMP_DECRYPTION_KEY)
        EncryptedStrings.setDecryptionKey(tempKey)
        
        val cachedKey = getCachedDecryptionKey()
        if (cachedKey != null && context != null) {
            decryptionKey = cachedKey
            EncryptedStrings.setDecryptionKey(cachedKey)
            loadConfig()
        }
        
        return 0
    }
    
    fun loadConfig(): Boolean {
        if (decryptedConfig != null) {
            return true
        }
        
        val cachedConfig = loadCachedConfig()
        if (cachedConfig != null) {
            decryptedConfig = cachedConfig
            return true
        }
        
        val tempKey = EncryptedStrings.get(EncryptedStrings.STR_TEMP_DECRYPTION_KEY)
        val key = decryptionKey ?: getCachedDecryptionKey() ?: tempKey
        
        return try {
            val configFileName = EncryptedStrings.get(EncryptedStrings.STR_ALGORITHM_CONFIG_ENC)
            val encryptedConfig = loadEncryptedConfigFromAssets(configFileName)
            if (encryptedConfig == null) {
                decryptedConfig = getDefaultConfig()
                return decryptedConfig != null
            }
            
            val decryptedJson = decryptConfig(encryptedConfig, key)
            if (decryptedJson.isEmpty()) {
                decryptedConfig = getDefaultConfig()
                return decryptedConfig != null
            }
            
            decryptedConfig = parseConfig(decryptedJson)
            val tempKey = EncryptedStrings.get(EncryptedStrings.STR_TEMP_DECRYPTION_KEY)
            if (decryptedConfig != null && key != tempKey) {
                cacheConfig(decryptedConfig!!, key)
            }
            decryptedConfig != null
        } catch (ex: Exception) {
            decryptedConfig = getDefaultConfig()
            decryptedConfig != null
        }
    }
    
    private fun getDefaultConfig(): AlgorithmConfig {
        return AlgorithmConfig(
            weights = AlgorithmConfig.Weights(
                cosine = 0.40,
                distance = 0.30,
                exactMatch = 0.20,
                correlation = 0.10
            ),
            thresholds = AlgorithmConfig.Thresholds(
                match = 0.75,
                exactMatchTolerance = 15,
                maxDistance = 255.0,
                normalizationFactor = 2.0
            )
        )
    }
    
    private fun getPrefs(): SharedPreferences? {
        return context?.getSharedPreferences(getPrefsName(), Context.MODE_PRIVATE)
    }
    
    private fun getCachedDecryptionKey(): String? {
        return try {
            getPrefs()?.getString(getKeyDecryptionKey(), null)
        } catch (ex: Exception) {
            null
        }
    }
    
    private fun cacheDecryptionKey(key: String) {
        try {
            getPrefs()?.edit()?.putString(getKeyDecryptionKey(), key)?.apply()
        } catch (ex: Exception) {
        }
    }
    
    private fun loadCachedConfig(): AlgorithmConfig? {
        return try {
            val cachedJson = getPrefs()?.getString(getKeyConfigCache(), null)
            if (cachedJson != null) {
                parseConfig(cachedJson)
            } else {
                null
            }
        } catch (ex: Exception) {
            null
        }
    }
    
    private fun cacheConfig(config: AlgorithmConfig, key: String) {
        try {
            val root = JSONObject()
            val weightsObj = JSONObject()
            weightsObj.put(EncryptedStrings.get(EncryptedStrings.STR_COSINE), config.weights.cosine)
            weightsObj.put(EncryptedStrings.get(EncryptedStrings.STR_DISTANCE), config.weights.distance)
            weightsObj.put(EncryptedStrings.get(EncryptedStrings.STR_EXACT_MATCH), config.weights.exactMatch)
            weightsObj.put(EncryptedStrings.get(EncryptedStrings.STR_CORRELATION), config.weights.correlation)
            
            val thresholdsObj = JSONObject()
            thresholdsObj.put(EncryptedStrings.get(EncryptedStrings.STR_MATCH), config.thresholds.match)
            thresholdsObj.put(EncryptedStrings.get(EncryptedStrings.STR_EXACT_MATCH_TOLERANCE), config.thresholds.exactMatchTolerance)
            thresholdsObj.put(EncryptedStrings.get(EncryptedStrings.STR_MAX_DISTANCE), config.thresholds.maxDistance)
            thresholdsObj.put(EncryptedStrings.get(EncryptedStrings.STR_NORMALIZATION_FACTOR), config.thresholds.normalizationFactor)
            
            root.put(EncryptedStrings.get(EncryptedStrings.STR_WEIGHTS), weightsObj)
            root.put(EncryptedStrings.get(EncryptedStrings.STR_THRESHOLDS), thresholdsObj)
            
            getPrefs()?.edit()?.putString(getKeyConfigCache(), root.toString())?.apply()
            cacheDecryptionKey(key)
        } catch (ex: Exception) {
        }
    }
    
    private fun loadEncryptedConfigFromAssets(filename: String): ByteArray? {
        return try {
            context?.assets?.open(filename)?.use { stream ->
                stream.readBytes()
            }
        } catch (ex: Exception) {
            null
        }
    }
    
    private fun decryptConfig(encrypted: ByteArray, key: String): String {
        return try {
            if (encrypted.size < 16) {
                return ""
            }
            
            val saltHeader = "Salted__".toByteArray(Charsets.UTF_8)
            val hasHeader = encrypted.size >= 16 && encrypted.sliceArray(0 until 8).contentEquals(saltHeader)
            
            val saltStart = if (hasHeader) 8 else 0
            if (encrypted.size < saltStart + 8) {
                return ""
            }
            
            val salt = encrypted.sliceArray(saltStart until saltStart + 8)
            val ciphertext = encrypted.sliceArray(saltStart + 8 until encrypted.size)
            
            val keyBytes = try {
                Base64.decode(key, Base64.NO_WRAP)
            } catch (ex: Exception) {
                key.toByteArray(Charsets.UTF_8)
            }
            val keyAndIv = evpBytesToKey(keyBytes, salt, 32 + 16)
            
            val aes = EncryptedStrings.get(EncryptedStrings.STR_AES)
            val cbcPkcs5 = EncryptedStrings.get(EncryptedStrings.STR_CBC_PKCS5)
            val secretKey = SecretKeySpec(keyAndIv.sliceArray(0 until 32), aes)
            val iv = IvParameterSpec(keyAndIv.sliceArray(32 until 48))
            
            val cipher = Cipher.getInstance(cbcPkcs5)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, iv)
            val decrypted = cipher.doFinal(ciphertext)
            String(decrypted, Charsets.UTF_8)
        } catch (ex: Exception) {
            ""
        }
    }
    
    private fun evpBytesToKey(password: ByteArray, salt: ByteArray, keyLength: Int): ByteArray {
        var result = ByteArray(0)
        var hash = ByteArray(0)
        
        while (result.size < keyLength) {
            val md5 = EncryptedStrings.get(EncryptedStrings.STR_MD5)
            val md = MessageDigest.getInstance(md5)
            if (hash.isNotEmpty()) {
                md.update(hash)
            }
            md.update(password)
            md.update(salt)
            hash = md.digest()
            
            result += hash
        }
        
        return result.sliceArray(0 until keyLength)
    }
    
    private fun parseConfig(json: String): AlgorithmConfig? {
        return try {
            val root = JSONObject(json)
            val weightsObj = root.getJSONObject(EncryptedStrings.get(EncryptedStrings.STR_WEIGHTS))
            val thresholdsObj = root.getJSONObject(EncryptedStrings.get(EncryptedStrings.STR_THRESHOLDS))
            
            val weights = AlgorithmConfig.Weights(
                cosine = weightsObj.getDouble(EncryptedStrings.get(EncryptedStrings.STR_COSINE)),
                distance = weightsObj.getDouble(EncryptedStrings.get(EncryptedStrings.STR_DISTANCE)),
                exactMatch = weightsObj.getDouble(EncryptedStrings.get(EncryptedStrings.STR_EXACT_MATCH)),
                correlation = weightsObj.getDouble(EncryptedStrings.get(EncryptedStrings.STR_CORRELATION))
            )
            
            val thresholds = AlgorithmConfig.Thresholds(
                match = thresholdsObj.getDouble(EncryptedStrings.get(EncryptedStrings.STR_MATCH)),
                exactMatchTolerance = thresholdsObj.getInt(EncryptedStrings.get(EncryptedStrings.STR_EXACT_MATCH_TOLERANCE)),
                maxDistance = thresholdsObj.getDouble(EncryptedStrings.get(EncryptedStrings.STR_MAX_DISTANCE)),
                normalizationFactor = thresholdsObj.getDouble(EncryptedStrings.get(EncryptedStrings.STR_NORMALIZATION_FACTOR))
            )
            
            AlgorithmConfig(weights, thresholds)
        } catch (ex: Exception) {
            null
        }
    }

    fun validateLicense(licenseKey: String, appId: String, endpoint: String): Int {
        if (isTampered || !verifyIntegrityChecksum() || !checkAntiTampering()) {
            return -2
        }

        val isValid = validateLicenseInternal(licenseKey, appId, endpoint)
        if (isValid) {
            return 0
        } else {
            isLicenseValidated = false
            return -3
        }
    }
    
    private fun extractDecryptionKeyFromResponse(licenseKey: String, appId: String): String {
        return try {
            val keyInput = "$licenseKey$appId"
            val sha256 = EncryptedStrings.get(EncryptedStrings.STR_SHA256)
            val digest = MessageDigest.getInstance(sha256).digest(keyInput.toByteArray())
            val derivedKey = digest.sliceArray(0 until 32)
            Base64.encodeToString(derivedKey, Base64.NO_WRAP)
        } catch (ex: Exception) {
            ""
        }
    }
    
    private fun extractDecryptionKeyFromServerResponse(response: String, licenseKey: String, appId: String): String {
        return try {
            val json = JSONObject(response)
            
            if (json.has("base64key")) {
                return json.getString("base64key")
            }
            
            if (json.has("decryption_key")) {
                return json.getString("decryption_key")
            }
            
            val keyInput = "$licenseKey$appId"
            val sha256 = EncryptedStrings.get(EncryptedStrings.STR_SHA256)
            val digest = MessageDigest.getInstance(sha256).digest(keyInput.toByteArray())
            val derivedKey = digest.sliceArray(0 until 32)
            Base64.encodeToString(derivedKey, Base64.NO_WRAP)
        } catch (ex: Exception) {
            ""
        }
    }

    fun compareTemplates(template1: ByteArray, template2: ByteArray): Map<String, Double> {
        if (!isLicenseValidated || !isLicenseStillValid() || isTampered) {
            return mapOf(
                "final" to 0.0,
                "cosine" to 0.0,
                "distance" to 0.0,
                "exactMatch" to 0.0,
                "correlation" to 0.0
            )
        }

        if (decryptedConfig == null && !loadConfig()) {
            decryptedConfig = getDefaultConfig()
        }

        if (decryptedConfig == null) {
            return mapOf(
                "final" to 0.0,
                "cosine" to 0.0,
                "distance" to 0.0,
                "exactMatch" to 0.0,
                "correlation" to 0.0
            )
        }

        return compareTemplatesInternal(template1, template2)
    }

    fun verifyIntegrity(challenge: String): String {
        if (isTampered || !verifyIntegrityChecksum()) {
            return EncryptedStrings.get(EncryptedStrings.STR_TAMPERED)
        }
        val message = (challenge + getIntegritySecret()).toByteArray(Charsets.UTF_8)
        val sha256 = EncryptedStrings.get(EncryptedStrings.STR_SHA256)
        val digest = MessageDigest.getInstance(sha256).digest(message)
        return Base64.encodeToString(digest, Base64.NO_WRAP)
    }

    private fun validateLicenseInternal(licenseKey: String, appId: String, endpoint: String): Boolean {
        if (isTampered || !verifyIntegrityChecksum() || !checkAntiTampering()) {
            return false
        }

        return try {
            val encryptedEndpoint = decryptEndpoint(endpoint)
            if (encryptedEndpoint.isEmpty()) {
                return false
            }

            val url = URL(encryptedEndpoint)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = EncryptedStrings.get(EncryptedStrings.STR_POST)
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.doOutput = true
            connection.setRequestProperty(EncryptedStrings.get(EncryptedStrings.STR_ACCEPT), "*/*")
            connection.setRequestProperty(EncryptedStrings.get(EncryptedStrings.STR_USER_AGENT), EncryptedStrings.get(EncryptedStrings.STR_GROUP_ATTENDANCE_SDK))
            connection.setRequestProperty(EncryptedStrings.get(EncryptedStrings.STR_API_KEY), licenseKey)

            val appIdKey = EncryptedStrings.get(EncryptedStrings.STR_APP_ID)
            val params = "$appIdKey=${URLEncoder.encode(appId, "UTF-8")}"
            DataOutputStream(connection.outputStream).use { output ->
                output.writeBytes(params)
                output.flush()
            }

            val responseCode = connection.responseCode
            val stream = if (responseCode in 200..299) connection.inputStream else connection.errorStream
            val response = stream.bufferedReader().use { it.readText() }
            connection.disconnect()

            val isValid = responseCode == 200 && isResponseValid(response)
            if (isValid) {
                isLicenseValidated = true
                lastLicenseValidationTime = System.currentTimeMillis()
                
                val decryptionKeyFromServer = extractDecryptionKeyFromServerResponse(response, licenseKey, appId)
                if (decryptionKeyFromServer.isNotEmpty()) {
                    setDecryptionKey(decryptionKeyFromServer)
                } else {
                    val tempKey = EncryptedStrings.get(EncryptedStrings.STR_TEMP_DECRYPTION_KEY)
                    setDecryptionKey(tempKey)
                }
                loadConfig()
            } else {
                verifyIntegrityChecksum()
            }
            isValid
        } catch (ex: Exception) {
            false
        }
    }

    private fun compareTemplatesInternal(template1: ByteArray, template2: ByteArray): Map<String, Double> {
        val config = decryptedConfig ?: return mapOf(
            EncryptedStrings.get(EncryptedStrings.STR_FINAL) to 0.0,
            EncryptedStrings.get(EncryptedStrings.STR_COSINE) to 0.0,
            EncryptedStrings.get(EncryptedStrings.STR_DISTANCE) to 0.0,
            EncryptedStrings.get(EncryptedStrings.STR_EXACT_MATCH) to 0.0,
            EncryptedStrings.get(EncryptedStrings.STR_CORRELATION) to 0.0
        )
        
        val minLength = minOf(template1.size, template2.size)
        val trimmed1 = template1.copyOfRange(0, minLength)
        val trimmed2 = template2.copyOfRange(0, minLength)

        var dotProduct = 0.0
        var norm1 = 0.0
        var norm2 = 0.0

        for (i in trimmed1.indices) {
            val val1 = trimmed1[i].toInt() and 0xFF
            val val2 = trimmed2[i].toInt() and 0xFF
            dotProduct += val1 * val2
            norm1 += val1 * val1
            norm2 += val2 * val2
        }

        var cosineSimilarity = 0.0
        if (norm1 > 0 && norm2 > 0) {
            cosineSimilarity = dotProduct / (sqrt(norm1) * sqrt(norm2))
        }

        var euclideanDistance = 0.0
        for (i in trimmed1.indices) {
            val diff = (trimmed1[i].toInt() and 0xFF) - (trimmed2[i].toInt() and 0xFF)
            euclideanDistance += diff * diff
        }
        euclideanDistance = sqrt(euclideanDistance)

        val maxPossibleDistance = sqrt(trimmed1.size.toDouble() * config.thresholds.maxDistance.pow(config.thresholds.normalizationFactor))
        val normalizedDistance = 1.0 - (euclideanDistance / maxPossibleDistance)

        var exactMatches = 0
        for (i in trimmed1.indices) {
            if (abs((trimmed1[i].toInt() and 0xFF) - (trimmed2[i].toInt() and 0xFF)) < config.thresholds.exactMatchTolerance) {
                exactMatches++
            }
        }
        val exactMatchRatio = exactMatches.toDouble() / trimmed1.size

        var sum1 = 0.0
        var sum2 = 0.0
        for (i in trimmed1.indices) {
            sum1 += trimmed1[i].toInt() and 0xFF
            sum2 += trimmed2[i].toInt() and 0xFF
        }
        val mean1 = sum1 / trimmed1.size
        val mean2 = sum2 / trimmed1.size

        var correlation = 0.0
        var std1 = 0.0
        var std2 = 0.0
        for (i in trimmed1.indices) {
            val diff1 = (trimmed1[i].toInt() and 0xFF) - mean1
            val diff2 = (trimmed2[i].toInt() and 0xFF) - mean2
            correlation += diff1 * diff2
            std1 += diff1 * diff1
            std2 += diff2 * diff2
        }

        var pearsonCorrelation = 0.0
        if (std1 > 0 && std2 > 0) {
            pearsonCorrelation = correlation / (sqrt(std1) * sqrt(std2))
            pearsonCorrelation = (pearsonCorrelation + 1.0) / config.thresholds.normalizationFactor
        }

        var finalSimilarity = cosineSimilarity * config.weights.cosine +
            normalizedDistance * config.weights.distance +
            exactMatchRatio * config.weights.exactMatch +
            pearsonCorrelation * config.weights.correlation
        finalSimilarity = finalSimilarity.coerceIn(0.0, 1.0)

        return mapOf(
            EncryptedStrings.get(EncryptedStrings.STR_FINAL) to finalSimilarity,
            EncryptedStrings.get(EncryptedStrings.STR_COSINE) to cosineSimilarity,
            EncryptedStrings.get(EncryptedStrings.STR_DISTANCE) to normalizedDistance,
            EncryptedStrings.get(EncryptedStrings.STR_EXACT_MATCH) to exactMatchRatio,
            EncryptedStrings.get(EncryptedStrings.STR_CORRELATION) to pearsonCorrelation
        )
    }

    private fun isResponseValid(body: String): Boolean {
        return try {
            val json = JSONObject(body)
            val successKeys = listOf(
                EncryptedStrings.get(EncryptedStrings.STR_SUCCESS),
                EncryptedStrings.get(EncryptedStrings.STR_STATUS),
                EncryptedStrings.get(EncryptedStrings.STR_VALID),
                EncryptedStrings.get(EncryptedStrings.STR_IS_VALID),
                EncryptedStrings.get(EncryptedStrings.STR_AUTHORIZED)
            )
            for (key in successKeys) {
                if (json.optBoolean(key, false)) {
                    return true
                }
            }
            val message = json.optString(EncryptedStrings.get(EncryptedStrings.STR_MESSAGE))
            val validStr = EncryptedStrings.get(EncryptedStrings.STR_VALID)
            message.lowercase().contains(validStr)
        } catch (ex: Exception) {
            val validStr = EncryptedStrings.get(EncryptedStrings.STR_VALID)
            body.lowercase().contains(validStr)
        }
    }

    private fun decryptEndpoint(encrypted: String): String {
        if (encrypted.isEmpty()) return ""
        return try {
            val decoded = Base64.decode(encrypted, Base64.NO_WRAP)
            val key = getIntegritySecret().toByteArray(Charsets.UTF_8)
            val decrypted = ByteArray(decoded.size)
            for (i in decoded.indices) {
                decrypted[i] = (decoded[i].toInt() xor key[i % key.size].toInt()).toByte()
            }
            String(decrypted, Charsets.UTF_8)
        } catch (ex: Exception) {
            encrypted
        }
    }

    private fun computeClassChecksum(): Long {
        return try {
            val className = this::class.java.name
            val bytes = className.toByteArray(Charsets.UTF_8)
            var checksum: Long = 0L
            for (byte in bytes) {
                checksum = ((checksum shl 8) or (byte.toLong() and 0xFF))
                checksum = checksum and 0xFFFFFFFFL
            }
            checksum
        } catch (ex: Exception) {
            0xDEADBEEFL
        }
    }

    private fun verifyIntegrityChecksum(): Boolean {
        return try {
            val current = computeClassChecksum()
            if (integrityChecksum == 0L) {
                integrityChecksum = current
                true
            } else {
                current == integrityChecksum
            }
        } catch (ex: Exception) {
            false
        }
    }

    private fun checkAntiTampering(): Boolean {
        return try {
            val expectedHash = computeClassChecksum()
            val currentHash = computeClassChecksum()
            currentHash == expectedHash
        } catch (ex: Exception) {
            false
        }
    }

    private fun isLicenseStillValid(): Boolean {
        if (!isLicenseValidated) {
            return false
        }
        val currentTime = System.currentTimeMillis()
        val timeSinceValidation = currentTime - lastLicenseValidationTime
        return timeSinceValidation < LICENSE_VALIDATION_INTERVAL
    }
}

