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