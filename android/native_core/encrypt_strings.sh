#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STRINGS_FILE="$SCRIPT_DIR/src/main/kotlin/com/groupattendance/face_recognition_native/EncryptedStrings.kt"
TEMP_KEY="GA_SDK_MASTER_KEY_2024_32_BYTES_KEY!!"

echo "Encrypting string literals..."

if [ ! -f "$SCRIPT_DIR/strings_to_encrypt.txt" ]; then
    echo "Error: strings_to_encrypt.txt not found!"
    exit 1
fi

# Create encrypted strings file
cat > "$STRINGS_FILE" << 'EOF'
package com.groupattendance.face_recognition_native

import android.util.Base64
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

object EncryptedStrings {
    private var decryptionKey: String? = null
    
    fun setDecryptionKey(key: String) {
        decryptionKey = key
    }
    
    private fun decryptString(encrypted: ByteArray, key: String): String {
        if (key.isEmpty()) return ""
        
        return try {
            val salt = encrypted.sliceArray(0 until 8)
            val iv = encrypted.sliceArray(8 until 24)
            val cipherText = encrypted.sliceArray(24 until encrypted.size)
            
            val keyBytes = key.toByteArray(Charsets.UTF_8)
            val keyAndIv = evpBytesToKey(keyBytes, salt, 32 + 16)
            val aesKey = keyAndIv.sliceArray(0 until 32)
            val derivedIv = keyAndIv.sliceArray(32 until 48)
            
            val secretKeySpec = SecretKeySpec(aesKey, "AES")
            val ivParameterSpec = IvParameterSpec(derivedIv)
            
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, secretKeySpec, ivParameterSpec)
            
            val decrypted = cipher.doFinal(cipherText)
            String(decrypted, Charsets.UTF_8)
        } catch (ex: Exception) {
            ""
        }
    }
    
    private fun evpBytesToKey(password: ByteArray, salt: ByteArray, keyLength: Int): ByteArray {
        val md = MessageDigest.getInstance("MD5")
        var currentHash = ByteArray(0)
        var result = ByteArray(0)
        
        while (result.size < keyLength) {
            md.reset()
            if (currentHash.isNotEmpty()) {
                md.update(currentHash)
            }
            md.update(password)
            md.update(salt)
            currentHash = md.digest()
            result += currentHash
        }
        return result.sliceArray(0 until keyLength)
    }
    
    fun get(id: Int): String {
        val key = decryptionKey ?: "GA_SDK_MASTER_KEY_2024_32_BYTES_KEY!!"
        val encrypted = getEncryptedBytes(id) ?: return ""
        return decryptString(encrypted, key)
    }
    
    companion object {
        // String ID constants
EOF

# Add constants in companion object
idx=1
while IFS='=' read -r key value; do
    if [[ -z "$key" || "$key" =~ ^# ]]; then
        continue
    fi
    key_upper=$(echo "$key" | tr '[:lower:]' '[:upper:]')
    echo "        const val STR_${key_upper} = $idx" >> "$STRINGS_FILE"
    ((idx++))
done < "$SCRIPT_DIR/strings_to_encrypt.txt"

cat >> "$STRINGS_FILE" << 'EOF'
    }
    
EOF

cat >> "$STRINGS_FILE" << 'EOF'
    
    private fun getEncryptedBytes(id: Int): ByteArray? {
        val base64Str = when (id) {
EOF

# Encrypt each string and add to file
encrypted_count=0
while IFS='=' read -r key value; do
    if [[ -z "$key" || "$key" =~ ^# ]]; then
        continue
    fi
    
    echo "Encrypting: $key = $value"
    
    # Encrypt using openssl and remove newlines from base64 output
    encrypted=$(echo -n "$value" | openssl enc -aes-256-cbc -salt -k "$TEMP_KEY" -pbkdf2 -base64 2>/dev/null | tr -d '\n\r')
    
    # Convert key to uppercase (compatible with bash 3+)
    key_upper=$(echo "$key" | tr '[:lower:]' '[:upper:]')
    
    # Append to the when expression - use direct constant reference (companion object members accessible from object body)
    echo "            STR_${key_upper} -> \"$encrypted\"," >> "$STRINGS_FILE"
    ((encrypted_count++))
done < "$SCRIPT_DIR/strings_to_encrypt.txt"

cat >> "$STRINGS_FILE" << 'EOF'
            else -> null
        }
        return base64Str?.let { Base64.decode(it, Base64.NO_WRAP) }
    }
    
EOF

cat >> "$STRINGS_FILE" << 'EOF'
}
EOF

echo "✅ String encryption complete!"
echo "Encrypted $encrypted_count strings"
echo "File: $STRINGS_FILE"

