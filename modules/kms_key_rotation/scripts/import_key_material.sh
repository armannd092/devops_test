#!/bin/bash
# scripts/import_key_material.sh

# This script imports external key material into an AWS KMS key
# It assumes you have the key material available and the AWS CLI configured

# Exit on any error
set -e

# Parse inputs
ENV=$1
SERVICE=$2

# Use environment variables set by Terraform
# KEY_ID is set by Terraform
# VALIDITY_DAYS is set by Terraform
# KEY_MATERIAL_PATH is set by Terraform

# Set up temporary files
TEMP_DIR=$(mktemp -d)
KEY_SPEC="RSA_2048"
WRAPPING_KEY_FILE="$TEMP_DIR/wrapping_key.bin"
IMPORT_TOKEN_FILE="$TEMP_DIR/import_token.bin"
WRAPPED_KEY_FILE="$TEMP_DIR/wrapped_key.bin"

cleanup() {
  echo "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo "Importing key material for $ENV-$SERVICE (Key ID: $KEY_ID)"

# Ensure key material directory exists
KEY_MATERIAL_DIR=$(dirname "$KEY_MATERIAL_PATH")
if [ ! -d "$KEY_MATERIAL_DIR" ]; then
  echo "Creating directory for key material: $KEY_MATERIAL_DIR"
  mkdir -p "$KEY_MATERIAL_DIR"
fi

# Get import parameters from AWS KMS
echo "Getting import parameters for KMS key: $KEY_ID"

aws kms get-parameters-for-import \
  --key-id "$KEY_ID" \
  --wrapping-algorithm RSAES_OAEP_SHA_256 \
  --wrapping-key-spec "$KEY_SPEC" \
  --output text \
  --query 'PublicKey' | base64 --decode > "$WRAPPING_KEY_FILE"

aws kms get-parameters-for-import \
  --key-id "$KEY_ID" \
  --wrapping-algorithm RSAES_OAEP_SHA_256 \
  --wrapping-key-spec "$KEY_SPEC" \
  --output text \
  --query 'ImportToken' | base64 --decode > "$IMPORT_TOKEN_FILE"

echo "Parameters obtained successfully."

# In a real environment, this would be where you'd integrate with your HSM
# to wrap the key material using the wrapping key.

if [ -f "$KEY_MATERIAL_PATH" ]; then
  echo "Wrapping key material from $KEY_MATERIAL_PATH"
  
  openssl pkeyutl \
    -encrypt \
    -in "$KEY_MATERIAL_PATH" \
    -out "$WRAPPED_KEY_FILE" \
    -inkey "$WRAPPING_KEY_FILE" \
    -keyform DER \
    -pubin \
    -pkeyopt rsa_padding_mode:oaep \
    -pkeyopt rsa_oaep_md:sha256
    
  echo "Key material wrapped successfully."
  
  # Import the wrapped key material
  echo "Importing key material into KMS key: $KEY_ID"
  
  if [ -z "$VALIDITY_DAYS" ] || [ "$VALIDITY_DAYS" -eq 0 ]; then
    # Import with no expiration
    aws kms import-key-material \
      --key-id "$KEY_ID" \
      --encrypted-key-material fileb://"$WRAPPED_KEY_FILE" \
      --import-token fileb://"$IMPORT_TOKEN_FILE" \
      --expiration-model KEY_MATERIAL_DOES_NOT_EXPIRE
  else
    # Import with expiration
    EXPIRY_DATE=$(date -u -d "+$VALIDITY_DAYS days" "+%Y-%m-%dT%H:%M:%SZ")
    aws kms import-key-material \
      --key-id "$KEY_ID" \
      --encrypted-key-material fileb://"$WRAPPED_KEY_FILE" \
      --import-token fileb://"$IMPORT_TOKEN_FILE" \
      --expiration-model KEY_MATERIAL_EXPIRES \
      --valid-to "$EXPIRY_DATE"
  fi
  
  echo "Key material imported successfully for $ENV-$SERVICE."
else
  echo "WARNING: Key material file not found at $KEY_MATERIAL_PATH"
  echo "Please generate key material for $ENV-$SERVICE and place it at $KEY_MATERIAL_PATH"
  echo "Then import it manually using the rotate_external_key.sh script."
fi