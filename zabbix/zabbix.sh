#!/bin/bash

# === Configuration Variables ===
# File paths for Zabbix configuration
CONFIG_FILE_FRONTEND="/etc/zabbix/nginx.conf"
CONFIG_FILE_DATABASE="/etc/zabbix/zabbix_server.conf"

# Zabbix server listening port (default: 80, change to 443 for HTTPS)
LISTEN_PORT="80"          

# Generate a random password for the Zabbix database user
NEW_PASSWORD=$(openssl rand -base64 12)

# Zabbix database credentials
ZABBIX_USER="zabbix"
ZABBIX_DB_NAME="zabbix"

# Log file for error tracking
LOG_FILE="/var/log/zabbix_install.log" 

# Supported Ubuntu versions for this script
ALLOWED_VERSIONS=("18.04" "20.04" "22.04" "24.04")
# === Helper Functions ===
log_and_exit() {
    local message="$1"
    echo "$(date) - ❌ Error: $message" >> "$LOG_FILE" 
    echo "❌ Error: $message"
    exit 1
}
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

# === Version Validation Passed ===
echo "✅ Ubuntu version is supported ($OS_VERSION). Continuing with script..."

# === Zabbix Version Selection and Validation ===
read -rp "Enter Zabbix version (6.0, 6.4, or 7.0): " ZABBIX_VERSION

if ! [[ "$ZABBIX_VERSION" =~ ^(6.0|6|6.4|7.0|7)$ ]]; then
    log_and_exit "Invalid version. Please retype."
fi

# Get Link Download version
case "$ZABBIX_VERSION" in
    6.0) VERSION="${ZABBIX_VERSION}-6" ;;
    6) VERSION="${ZABBIX_VERSION}.0-6" ZABBIX_VERSION="${ZABBIX_VERSION}.0";;
    6.4) VERSION="${ZABBIX_VERSION}-1" ;;
    7.0) VERSION="${ZABBIX_VERSION}-2" ;;
    7) VERSION="${ZABBIX_VERSION}.0-2" ZABBIX_VERSION="${ZABBIX_VERSION}.0";;
    *) log_and_exit "Unsupported Zabbix version: $ZABBIX_VERSION" ;;
esac

echo "✅ Selected Zabbix version: $ZABBIX_VERSION"

# === Server Public IP Detection ===
echo "🔃 Detecting server's public IP address..."
IP_ADDRESS=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ident.me)
echo "✅ Public IP Address is $IP_ADDRESS"
SERVER_NAME="$IP_ADDRESS" #get IP address of server
# read -p "Enter IP or DNS server: " SERVER_NAME

# === Download and Install Zabbix Release Package ===
echo "🔃 Downloading and installing Zabbix release package..."
wget -q "https://repo.zabbix.com/zabbix/$ZABBIX_VERSION/ubuntu/pool/main/z/zabbix-release/zabbix-release_$VERSION+ubuntu""$OS_VERSION""_all.deb" || log_and_exit "❌ Error downloading Zabbix release package"

dpkg -i "zabbix-release_$VERSION+ubuntu""$OS_VERSION""_all.deb" || log_and_exit "❌ Failed to install Zabbix release package"
apt update
rm -rf "zabbix-release_$VERSION+ubuntu""$OS_VERSION""_all.deb"
# === Zabbix and PostgreSQL Package Installation ===
echo "🔃 Checking and installing required packages..."
packages=(zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent postgresql postgresql-contrib)
for package in "${packages[@]}"; do
    if ! dpkg -s "$package" &> /dev/null; then
        apt install -y "$package" || log_and_exit "❌ Failed to install $package"
    else
        echo "✅ $package is already installed."
    fi
done

# === Zabbix Database Setup ===
echo "🔃 Setting up Zabbix database..."
sudo -u postgres psql -c "CREATE USER $ZABBIX_USER WITH PASSWORD '$NEW_PASSWORD';" || echo "❌ Failed to create Zabbix user (already exists,..)"
sudo -u postgres psql -c "CREATE DATABASE $ZABBIX_DB_NAME OWNER $ZABBIX_USER;" || echo "❌ Failed to create Zabbix database (already exists,..)"
echo "✅ Finished Zabbix Database Setup"
echo "🔃 Importing Zabbix schema..."
START_TIME=$(date +%s)
LOG_COUNT=0
{ # Start a new process group for the schema import 
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u "$ZABBIX_USER" psql "$ZABBIX_DB_NAME" 2>&1 | while read -r line; do
    if ((LOG_COUNT < 10)); then  # Only log the first 10 lines
        echo "$line"
        ((LOG_COUNT++))
    fi
done
} &
IMPORT_PID=$!

# Progress indicator while the import runs
while ps -p $IMPORT_PID > /dev/null; do 
    echo -ne "\r🔃 Elapsed time: $(date -u -d @$(( $(date +%s) - START_TIME )) +%H:%M:%S)"
    sleep 1
done

if wait $IMPORT_PID; then
    echo -e "\n✅ Zabbix schema imported successfully."
else
    # If import fails, print remaining logs
    echo "❌ Import failed. Remaining logs:"
    wait $IMPORT_PID 2>&1 | tee -a "$LOG_FILE"  # Log remaining output to file
    log_and_exit "❌ Failed to import Zabbix schema."
fi

# PostgreSQL restart (Optional)
# echo "🔃 Restarting PostgreSQL..."
# sudo systemctl restart postgresql 
echo "🔃 Configuring Zabbix server..."
# sed -i "s/^DBPassword=.*/DBPassword=$NEW_PASSWORD/" "$CONFIG_FILE_DATABASE" || log_and_exit "Failed to set the database password in $CONFIG_FILE_DATABASE"
sed -i "s@^DBPassword=.*@DBPassword=$NEW_PASSWORD@" "$CONFIG_FILE_DATABASE" || log_and_exit "Failed to set the database password in $CONFIG_FILE_DATABASE"

# === Zabbix Frontend Configuration ===
echo "🔃 Configuring Zabbix frontend (Nginx)..."

sed -i "/^ *# *listen/s/^ *# *//; s/listen .*/listen $LISTEN_PORT;/" "$CONFIG_FILE_FRONTEND"
sed -i "/^ *# *server_name/s/^ *# *//; s/server_name .*/server_name $SERVER_NAME;/" "$CONFIG_FILE_FRONTEND"


# === Restart Services ===
echo "🔃 Restarting services..."
systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm
systemctl enable zabbix-server zabbix-agent nginx php8.3-fpm
# === Verification ===
echo "🔃 Verifying installation and configuration..."

# Check if Services Are Active and Enabled
for service in zabbix-server zabbix-agent nginx php8.3-fpm; do
    if ! systemctl is-active --quiet "$service"; then
        echo "❌ Error: $service is not active."
        exit 1
    else
        echo "✅ $service is active."
    fi

    if ! systemctl is-enabled --quiet "$service"; then
        echo "❌ Error: $service is not enabled."
        exit 1
    else
        echo "✅ $service is enabled."
    fi
done


echo "✅ Zabbix installation and configuration completed successfully! 🎉"
