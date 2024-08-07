#1 === Check Operating System Version ===

echo "🔃 Checking Ubuntu version..."

# Check if lsb_release is available
if command -v lsb_release &> /dev/null; then
    os_info=$(lsb_release -rs)   

elif [ -f /etc/os-release ]; then  # If lsb_release is not available, try /etc/os-release
    os_info=$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release)
else
    log_and_exit "Unable to determine Ubuntu version."  
fi

# Extract version number (assuming format like "22.04" or "20.04.6")
OS_VERSION=$(echo "$os_info" | grep -oE '[0-9]+\.[0-9]+')

# Validate extracted version
if [ -z "$OS_VERSION" ]; then
    log_and_exit "Unable to determine Ubuntu version." 
fi

# Check if the version is in the allowed list
if [[ ! ${ALLOWED_VERSIONS[*]} =~ ${OS_VERSION} ]]; then
    log_and_exit "This script only supports Ubuntu versions ${ALLOWED_VERSIONS[*]}. Your current version is: $OS_VERSION"
fi


