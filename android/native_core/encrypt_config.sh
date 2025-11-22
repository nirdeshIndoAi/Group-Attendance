#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/src/main/assets/algorithm_config.json"
ENCRYPTED_FILE="$SCRIPT_DIR/src/main/assets/algorithm_config.enc"

echo "Encrypting algorithm configuration..."

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

MASTER_KEY="GA_SDK_MASTER_KEY_2024_32_BYTES_KEY!!"

if command -v openssl &> /dev/null; then
    openssl enc -aes-256-cbc -salt -in "$CONFIG_FILE" -out "$ENCRYPTED_FILE" -k "$MASTER_KEY" -pbkdf2
    echo "✅ Config encrypted successfully!"
    echo "Encrypted file: $ENCRYPTED_FILE"
    rm -f "$CONFIG_FILE"
    echo "Original config file removed for security"
else
    echo "Error: openssl not found. Please install openssl to encrypt config."
    exit 1
fi

