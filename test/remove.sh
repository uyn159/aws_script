#!/bin/bash

# List of Zabbix packages to remove
zabbix_packages=(
    zabbix-server-pgsql 
    zabbix-frontend-php 
    zabbix-apache-conf 
    zabbix-agent
    zabbix-release  # Optional: If you installed a specific release package
    zabbix-sql-scripts
    zabbix-nginx-conf # Optional: If you are using Nginx web server
)
# List of PostgreSQL packages to remove
postgresql_packages=(
    postgresql
    postgresql-contrib 
)

# Function to remove packages
remove_packages() {
    local packages=("$@")
    for package in "${packages[@]}"; do
        echo "🗑️  Removing package: $package"
        sudo apt-get purge --auto-remove "$package" -y || echo "⚠️  Warning: Could not remove $package. Check for errors."
    done
}

# Function to check and remove config files
remove_config_files() {
    local config_files=("$@")
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            echo "🗑️  Removing config file: $config_file"
            sudo rm -f "$config_file" || echo "⚠️  Warning: Could not remove $config_file. Check for errors."
        else
            echo "ℹ️  Config file not found: $config_file"
        fi
    done
}

# Function to drop Zabbix database (if it exists)
drop_zabbix_database() {
    echo "Checking for Zabbix database..."
    if sudo -u postgres psql -lqt | grep -qw "zabbix"; then
        echo "🗑️  Dropping Zabbix database 'zabbix'..."
        sudo -u postgres psql -c "DROP DATABASE zabbix;"
    else
        echo "ℹ️  Zabbix database not found."
    fi
}

# Function to remove Zabbix user (if it exists)
remove_zabbix_user() {
    echo "Checking for Zabbix user..."
    if sudo -u postgres psql -c "\du" | grep -q "zabbix"; then
        echo "🗑️  Removing Zabbix user 'zabbix'..."
        sudo -u postgres psql -c "DROP USER zabbix;"
    else
        echo "ℹ️  Zabbix user not found."
    fi
}

# Remove Zabbix packages
remove_packages "${zabbix_packages[@]}"

# Remove PostgreSQL packages
remove_packages "${postgresql_packages[@]}"

# Remove Zabbix configuration files
remove_config_files "/etc/zabbix" "/etc/nginx/sites-enabled/zabbix" "/etc/php/*/fpm/pool.d/zabbix.conf"

# Drop Zabbix database and user
drop_zabbix_database
remove_zabbix_user

echo "✅ Zabbix and PostgreSQL removal complete."
