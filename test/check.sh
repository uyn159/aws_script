#!/bin/bash

# If the version is valid, continue with the rest of your script
echo "✅ Ubuntu version is supported. Continuing with script..."
# Check if lsb_release is available (best for Debian-based systems)
if command -v lsb_release &> /dev/null; then
  os_info=$(lsb_release -rs)   # Get release and short version

# If lsb_release is not available, try /etc/os-release
elif [ -f /etc/os-release ]; then
  os_info=$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release)
else
  echo "Unable to determine Ubuntu version."
  exit 1
fi

# Extract version number (assuming format like "22.04" or "20.04.6")
OS_VERSION=$(echo "$os_info" | grep -oE '[0-9]+\.[0-9]+')

# If the grep didn't find the version, it was unsuccessful. Exit with a status
if [ -z "$OS_VERSION" ]; then
  echo "Unable to determine Ubuntu version."
  exit 1
fi

echo "$OS_VERSION"  # Output: e.g., 24.04
# Allowed versions
ALLOWED_VERSIONS=("18.04" "20.04" "22.04" "24.04")

# Check if the version is in the allowed list
if [[ ! " ${ALLOWED_VERSIONS[*]} " =~ " ${OS_VERSION} " ]]; then
    echo "❌ Error: This script only supports Ubuntu versions 18.04, 20.04, 22.04, or 24.04."
    echo "Your current version is: $OS_VERSION"
    exit 1  # Exit the script with an error code
fi
