#!/bin/bash

# Define the path to your key.properties file
PROPERTIES_FILE="C:\Users\Brisingr\Documents\GitHub\tilt-hydrometer\tilt_app\android\key.properties"
# Define the environment variable names used in build.gradle (UPDATED)
ENV_VAR_STORE_FILE="MYAPP_KEYSTORE_FILE"
ENV_VAR_STORE_PASSWORD="MYAPP_KEYSTORE_PASS"
ENV_VAR_KEY_ALIAS="MYAPP_KEY_ALIAS"
ENV_VAR_KEY_PASSWORD="MYAPP_KEY_PASS"

# Check if the properties file exists
if [ ! -f "$PROPERTIES_FILE" ]; then
    echo "Error: $PROPERTIES_FILE not found."
    exit 1
fi

echo "Exporting signing environment variables from $PROPERTIES_FILE..."

# Read the properties file line by line
while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Trim whitespace (optional, but good practice)
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    # Skip empty lines or comments
    [[ -z "$key" || "$key" =~ ^# ]] && continue

    # Export the corresponding environment variable using the UPDATED names
    case "$key" in
        storeFile)
            export "$ENV_VAR_STORE_FILE=$value"
            echo "Exported $ENV_VAR_STORE_FILE"
            ;;
        storePassword)
            export "$ENV_VAR_STORE_PASSWORD=$value"
            echo "Exported $ENV_VAR_STORE_PASSWORD"
            ;;
        keyAlias)
            export "$ENV_VAR_KEY_ALIAS=$value"
            echo "Exported $ENV_VAR_KEY_ALIAS"
            ;;
        keyPassword)
            export "$ENV_VAR_KEY_PASSWORD=$value"
            echo "Exported $ENV_VAR_KEY_PASSWORD"
            ;;
        *)
            # Optionally handle unknown keys
            # echo "Ignoring unknown key: $key"
            ;;
    esac
done < "$PROPERTIES_FILE"

echo "Environment variables set."