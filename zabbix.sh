#!/bin/bash

# Ensure script is run with sudo (root privileges)
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Variables (Customize if needed)
ZABBIX_VERSION=6.0
POSTGRES_PASSWORD="your_strong_password"  # Set your PostgreSQL password here
ZABBIX_DB_PASSWORD="another_strong_password"  # Set your Zabbix database password here
TIMEZONE="Asia/Ho_Chi_Minh" # Set your timezone here


# 1. Update System Packages
echo "Updating system packages..."
sudo apt update

# 2. Install and Configure PostgreSQL 
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# 3. Set PostgreSQL Password
echo "Setting PostgreSQL password..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"

# 4. Create Zabbix User and Database
echo "Creating Zabbix user and database in PostgreSQL..."
sudo -u postgres psql -c "CREATE USER zabbix WITH PASSWORD '$ZABBIX_DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE zabbix OWNER zabbix;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE zabbix TO zabbix;"

# 5. Install Zabbix Repository
echo "Installing Zabbix repository..."
wget https://repo.zabbix.com/zabbix/$ZABBIX_VERSION/ubuntu/pool/main/z/zabbix-release/zabbix-release_$ZABBIX_VERSION-1+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_$ZABBIX_VERSION-1+ubuntu22.04_all.deb
sudo apt update

# 6. Install Zabbix Components
echo "Installing Zabbix components..."
sudo apt install -y zabbix-server-pgsql zabbix-frontend-php php8.1-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent 

# 7. Import Initial Schema and Data
echo "Importing Zabbix database schema..."
zcat /usr/share/doc/zabbix-server-pgsql/create.sql.gz | sudo -u zabbix psql zabbix

# 8. Configure Zabbix Server
echo "Configuring Zabbix server..."
sed -i "s/# DBPassword=.*/DBPassword=$ZABBIX_DB_PASSWORD/" /etc/zabbix/zabbix_server.conf
sed -i "s/# php_value\[date.timezone].*/php_value\[date.timezone] = $TIMEZONE/" /etc/zabbix/nginx.conf

# 9. Restart Services
echo "Restarting services..."
sudo systemctl restart zabbix-server zabbix-agent nginx php8.1-fpm

# 10. Enable Services on Boot (Optional)
echo "Enabling services on boot..."
sudo systemctl enable zabbix-server zabbix-agent nginx php8.1-fpm 


echo "Zabbix installation is complete! You can now access the frontend at http://your_server_ip/zabbix"
