#!/bin/bash

# === Configuration Variables ===
CONFIG_FILE_FRONTEND="/etc/zabbix/nginx.conf"
CONFIG_FILE_DATABASE="/etc/zabbix/zabbix_server.conf"
LISTEN_PORT="80"         # Or 443 if using HTTPS
SERVER_NAME="13.250.181.206" # Replace with your domain or IP
NEW_PASSWORD="13.250.181.206"
ZABBIX_USER="zabbix"
ZABBIX_DB_NAME="zabbix"

# === Zabbix Repository Setup ===
echo "🔃 Setting up Zabbix repository..."
wget -q https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-6+ubuntu24.04_all.deb

if [ $? -ne 0 ]; then
    echo "Error downloading Zabbix release package. Please check your internet connection and try again."
    exit 1
fi

sudo dpkg -i zabbix-release_6.0-6+ubuntu24.04_all.deb
sudo apt update

# === Zabbix Installation ===
echo "🔃 Installing Zabbix components..."
sudo apt install -y zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent

# === PostgreSQL Installation & Configuration ===
echo "🔃 Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

echo "🔃 Enter a strong password for the default PostgreSQL user (postgres):"
sudo passwd postgres 

echo "🔃 Creating Zabbix database user..."
sudo -u postgres createuser --pwprompt "$ZABBIX_USER"

echo "🔃 Creating Zabbix database..."
sudo -u postgres createdb -O "$ZABBIX_USER" "$ZABBIX_DB_NAME"

echo "🔃 Importing Zabbix schema..."
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u "$ZABBIX_USER" psql "$ZABBIX_DB_NAME"

echo "🔃 Restarting PostgreSQL..."
sudo systemctl restart postgresql

# === Zabbix Server Configuration ===
echo "🔃 Configuring Zabbix server..."

# Check if Configuration File Exists
if [ ! -f "$CONFIG_FILE_DATABASE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE_DATABASE"
    exit 1
fi

# Set the Zabbix database password
sed -i "s/^DBPassword=.*/DBPassword=$NEW_PASSWORD/" "$CONFIG_FILE_DATABASE"

# === Zabbix Frontend Configuration ===
echo "🔃 Configuring Zabbix frontend (Nginx)..."

# Check if Configuration File Exists
if [ ! -f "$CONFIG_FILE_FRONTEND" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE_FRONTEND"
    exit 1
fi

sed -i "/^ *# *listen/s/^ *# *//; s/listen .*/listen $LISTEN_PORT;/" "$CONFIG_FILE_FRONTEND"
sed -i "/^ *# *server_name/s/^ *# *//; s/server_name .*/server_name $SERVER_NAME;/" "$CONFIG_FILE_FRONTEND"


# === Restart Services ===
echo "Restarting services..."
systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm
systemctl enable zabbix-server zabbix-agent nginx php8.3-fpm

# === Verification ===
echo "Verifying installation and configuration..."

# Check if Services Are Active 
services=(zabbix-server zabbix-agent nginx php8.3-fpm)
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "ERROR: $service is not active (running). ❌"
        exit 1
    else
        echo "$service is active (running). ✅"
    fi
done

# Check if Services Are Enabled 
for service in "${services[@]}"; do
    if ! systemctl is-enabled --quiet "$service"; then
        echo "ERROR: $service is not enabled. ❌"
        exit 1
    else 
        echo "$service is enabled. ✅"
    fi
done

echo "Zabbix user and database checks completed successfully! 🎉"
