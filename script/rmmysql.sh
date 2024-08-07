#!/bin/bash

# === Uninstall MySQL Script ===
# This script thoroughly removes MySQL, its configuration files, and data directories.
# Use with caution, as it will delete all MySQL data!

log_and_exit() {
    local message="$1"
    echo "$(date) - ❌ Error: $message" >> "/var/log/mysql_uninstall.log"
    echo "❌ Error: $message"
    exit 1
}

echo "🔃 Checking for MySQL..."
if ! dpkg -l | grep -q mysql-server; then
    echo "❌ MySQL is not installed."
    exit 0
fi

read -p "Are you sure you want to completely remove MySQL (y/n)? " confirm
if [[ "$confirm" != "y" ]]; then
    echo "MySQL removal cancelled."
    exit 0
fi

echo "🔃 Stopping MySQL service..."
sudo systemctl stop mysql

echo "🔃 Purging MySQL packages and dependencies..."
sudo apt-get purge -y mysql\*

echo "🔃 Removing MySQL configuration files..."
sudo rm -rf /etc/mysql /etc/mysql/conf.d /etc/apparmor.d/abstractions/mysql /etc/apparmor.d/cache/usr.sbin.mysqld

echo "🔃 Removing MySQL data directories..."
sudo rm -rf /var/lib/mysql

echo "🔃 Removing MySQL user and group (if they exist)..."
sudo userdel -r mysql 2>/dev/null
sudo groupdel mysql 2>/dev/null

echo "✅ MySQL uninstalled successfully."
