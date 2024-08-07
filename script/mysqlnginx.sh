#!/bin/bash

# === Configuration Variables ===
CONFIG_FILE_FRONTEND="/etc/zabbix/nginx.conf"
CONFIG_FILE_DATABASE="/etc/zabbix/zabbix_server.conf"
LISTEN_PORT="80"          # Or 443 if using HTTPS
NEW_PASSWORD=$(openssl rand -base64 12)
ZABBIX_USER="zabbix"
ZABBIX_DB_NAME="zabbix"
LOG_FILE="/var/log/zabbix_install.log" # Log file for error tracking

# === Helper Functions ===
log_and_exit() {
    local message="$1"
    echo "$(date) - ❌ Error: $message" >> "$LOG_FILE" 
    echo "❌ Error: $message"
    exit 1
}

# === Server Public IP Detection ===
echo "🔃 Detecting server's public IP address..."
IP_ADDRESS=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ident.me)
echo "✅ Public IP Address is $IP_ADDRESS"
SERVER_NAME="$IP_ADDRESS" #get IP address of server
# read -p "Enter IP or DNS server: " SERVER_NAME


# === Download and Install Zabbix Release Package ===
echo "🔃 Downloading and installing Zabbix release package..."
wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-6+ubuntu24.04_all.deb || log_and_exit "❌ Error downloading Zabbix release package"
dpkg -i zabbix-release_6.0-6+ubuntu24.04_all.deb
apt update
rm -rf zabbix-release_6.0-6+ubuntu24.04_all.deb
# === Zabbix and PostgreSQL Package Installation ===
echo "🔃 Checking and installing required packages..."
# packages=(zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent postgresql postgresql-contrib)
packages=(zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent mysql-server)
for package in "${packages[@]}"; do
    if ! dpkg -s "$package" &> /dev/null; then
        apt install -y "$package" || log_and_exit "❌ Failed to install $package"
    else
        echo "✅ $package is already installed."
    fi
done

