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

# === MySQL Installation Script ===
# This script installs MySQL on Ubuntu, sets the root password, and performs basic security hardening.
# It is suitable for Ubuntu 18.04, 20.04, 22.04, and later.

# === Helper Functions ===

log_and_exit() {
    local message="$1"
    echo "$(date) - ❌ Error: $message" >> "/var/log/mysql_install.log"
    echo "❌ Error: $message"
    exit 1
}

# === Check for Existing MySQL Installation ===
echo "🔃 Checking for existing MySQL installation..."
if dpkg -l | grep -q mysql-server; then
    log_and_exit "MySQL is already installed. Exiting."
fi

# === Update Package Lists ===
echo "🔃 Updating package lists..."
apt-get update || log_and_exit "Failed to update package lists"

# === Install MySQL Server ===
echo "🔃 Installing MySQL server..."
DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server || log_and_exit "Failed to install MySQL server"

# === Secure MySQL Installation (Optional) ===
echo "🔃 Running initial MySQL security script (recommended)..."
mysql_secure_installation

# === Set MySQL Root Password (Optional) ===
# If you didn't set the root password during the secure installation, you can do it now:
# read -s -p "Enter new MySQL root password: " MYSQL_ROOT_PASSWORD
# mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
# echo "✅ MySQL root password set."

# === Verify MySQL Installation ===
echo "🔃 Verifying MySQL installation..."
if ! systemctl is-active --quiet mysql; then
    log_and_exit "MySQL service is not running."
fi

echo "✅ MySQL installation completed successfully! 🎉"
sed -i "s@^DBPassword=.*@DBPassword=$NEW_PASSWORD@" "$CONFIG_FILE_DATABASE" || log_and_exit "Failed to set the database password in $CONFIG_FILE_DATABASE"
echo "🔃 Configuring Zabbix frontend (Nginx)..."

sed -i "/^ *# *listen/s/^ *# *//; s/listen .*/listen $LISTEN_PORT;/" "$CONFIG_FILE_FRONTEND"
sed -i "/^ *# *server_name/s/^ *# *//; s/server_name .*/server_name $SERVER_NAME;/" "$CONFIG_FILE_FRONTEND"