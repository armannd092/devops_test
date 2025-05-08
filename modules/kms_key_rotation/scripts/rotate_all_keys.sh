#!/bin/bash
# scripts/rotate_all_keys.sh

# This script rotates external key material for all AWS KMS keys
# It assumes you have a mechanism to generate new key material

BASE_SCRIPT_PATH=$(dirname "$0")
ROTATE_SCRIPT="${BASE_SCRIPT_PATH}/rotate_external_key.sh"
VALIDITY_DAYS=${1:-365}

# Read key IDs from Terraform output
KEYS_JSON=$(terraform output -json key_ids)

# Parse the JSON to get each key ID
echo "Starting rotation for all keys..."
echo $KEYS_JSON | jq -r 'to_entries[] | "\(.key)=\(.value)"' | while read line; do
  ENV_SERVICE=${line%%=*}
  KEY_ID=${line#*=}
  
  ENV=${ENV_SERVICE%-*}
  SERVICE=${ENV_SERVICE#*-}
  
  KEY_MATERIAL_PATH="/secure/key_materials/${ENV}/${SERVICE}/key.bin"
  
  echo "Rotating key for $ENV-$SERVICE (Key ID: $KEY_ID)"
  
  # Generate new key material (this would be done with HSM in production)
  # Here we're just simulating this step
  mkdir -p $(dirname "$KEY_MATERIAL_PATH")
  openssl rand -out "$KEY_MATERIAL_PATH" 32
  
  # Call the rotation script for this key
  bash "$ROTATE_SCRIPT" "$KEY_ID" "$KEY_MATERIAL_PATH" "$VALIDITY_DAYS"
  
  echo "Rotation completed for $ENV-$SERVICE"
  echo "-----------------------------------"
done

echo "All keys have been rotated successfully"