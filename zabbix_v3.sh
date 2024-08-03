#!/bin/bash

# === Configuration Variables ===
CONFIG_FILE_FRONTEND="/etc/zabbix/nginx.conf"
CONFIG_FILE_DATABASE="/etc/zabbix/zabbix_server.conf"
LISTEN_PORT="80"          # Or 443 if using HTTPS
NEW_PASSWORD=$(openssl rand -base64 12) 
ZABBIX_USER="zabbix"
ZABBIX_DB_NAME="zabbix"

# === Helper Functions ===
# log_and_exit() {
#     echo "❌ Error: $1"
#     exit 1
# }
log_and_exit() {
    local message="$1"
    echo "$(date) - ❌ Error: $message" >> "$LOG_FILE"  # Log ❌ Error to file
    echo "❌ Error: $message"
    exit 1
}
# log_message() {
#     local message="$1"
#     echo "$(date) - $message" >> "$LOG_FILE"
# }

get_confirmation() {
    local message="$1"
    local default_answer="$2"
    local response=""
    while true; do
        read -p "$message (y/n) [${default_answer}]: " response
        response=${response:-$default_answer} # Use default if empty
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Get Server's Public IP
echo "🔃 Detecting server's public IP address..."

# Attempt to get the IP from multiple sources
# The script will keep trying till one works
IP_ADDRESS=$(
    curl -s ifconfig.me || 
    curl -s icanhazip.com || 
    curl -s ident.me
)

if [ -z "$IP_ADDRESS" ]; then
    log_and_exit "❌Unable to determine public IP address. Please check your network connection."
fi
echo "✅ Public IP Address is $IP_ADDRESS"
# Assign the IP to SERVER_NAME
SERVER_NAME="$IP_ADDRESS"

# === Zabbix Package Check ===
echo "🔃 Checking for Zabbix package installation..."
packages_to_check=(zabbix-server-pgsql zabbix-frontend-php)
for package in "${packages_to_check[@]}"; do
    if dpkg -s "$package" &> /dev/null; then
        echo "✅ $package is already installed."
    else
        if ! get_confirmation "🔃 Zabbix is not installed. Do you want to install it now?" "n"; then
            log_and_exit "❌ Zabbix installation cancelled by user."
        else
            # === Zabbix Repository Setup ===
            echo "🔃 Setting up Zabbix repository..."
            if ! wget -q https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-6+ubuntu24.04_all.deb; then
                log_and_exit "❌ Error downloading Zabbix release package. Please check your internet connection."
            fi

            sudo dpkg -i zabbix-release_6.0-6+ubuntu24.04_all.deb || log_and_exit "❌ Failed to install Zabbix release package."
            sudo apt update

            # === Zabbix Installation ===
            echo "🔃 Installing Zabbix components..."
            sudo apt install -y zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent || log_and_exit "❌ Failed to install Zabbix components."

        fi
    fi
done

# === PostgreSQL Check ===
echo "🔃 Checking for PostgreSQL installation..."
if dpkg -s postgresql &> /dev/null; then
    echo "✅ postgresql is already installed."
else
    if ! get_confirmation "PostgreSQL is not installed. Do you want to install it now?" "n"; then
        log_and_exit "❌PostgreSQL installation cancelled by user."
    else
        # === PostgreSQL Installation ===
        echo "🔃 Installing PostgreSQL..."
        sudo apt install -y postgresql postgresql-contrib || log_and_exit "❌ Failed to install PostgreSQL."
    fi
fi

# === Zabbix Database Check ===
echo "🔃 Checking for Zabbix database..."
if sudo -u postgres psql -lqt | grep -qw "$ZABBIX_DB_NAME"; then
    echo "✅ Zabbix database '$ZABBIX_DB_NAME' already exists."
else
    if ! get_confirmation "🔃 Zabbix database not found. Do you want to create it now?" "n"; then
        log_and_exit "❌ Zabbix database creation cancelled by user."
    else
        # Check for Zabbix user database
        echo "🔃 Checking for Zabbix user database"
        if sudo -u postgres psql -c "\du" | grep -q "$ZABBIX_USER"; then
            echo "✅ Zabbix user '$ZABBIX_USER' already exists."
        else
            if ! get_confirmation "🔃 Zabbix user not found. Do you want to create it now?" "n"; then
                log_and_exit "❌ Zabbix user creation cancelled by user."
            else
                echo "🔃 Enter a strong password for the default PostgreSQL user (postgres):"
                sudo passwd postgres

                echo "🔃 Creating Zabbix database user..."
                sudo -u postgres createuser --pwprompt "$ZABBIX_USER" || log_and_exit "❌ Failed to create Zabbix database user."
            fi
        fi
        # === PostgreSQL & Zabbix Database Configuration ===
        # Check for Zabbix database

        echo "🔃 Creating Zabbix database..."
        sudo -u postgres createdb -O "$ZABBIX_USER" "$ZABBIX_DB_NAME" || log_and_exit "❌ Failed to create Zabbix database."

        # === Zabbix Configuration ===
        echo "🔃 Importing Zabbix schema..."
        START_TIME=$(date +%s) # Record the start time in seconds
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
            echo -e "\n ✅Zabbix schema imported successfully."
        else
            # If import fails, print remaining logs
            echo "❌ Import failed. Remaining logs:"
            wait $IMPORT_PID 2>&1 | tee -a "$LOG_FILE"  # Log remaining output to file
            log_and_exit "❌ Failed to import Zabbix schema."
        fi
        echo "🔃 Restarting PostgreSQL..."
        sudo systemctl restart postgresql
    fi
fi

# === Zabbix Frontend Configuration ===
echo "🔃 Configuring Zabbix server..."
# Check if Configuration File Exists
echo "🔃 Configuring Zabbix frontend (Nginx)..."
if [ ! -f "$CONFIG_FILE_FRONTEND" ]; then
    log_and_exit "❌❌ Error: Configuration file not found at $CONFIG_FILE_FRONTEND"
fi
sed -i "/^ *# *listen/s/^ *# *//; s/listen .*/listen $LISTEN_PORT;/" "$CONFIG_FILE_FRONTEND"
sed -i "/^ *# *server_name/s/^ *# *//; s/server_name .*/server_name $SERVER_NAME;/" "$CONFIG_FILE_FRONTEND"

echo "🔃 Configuring Zabbix database..."
# Check if Configuration File Exists
if [ ! -f "$CONFIG_FILE_DATABASE" ]; then
    echo "❌ Error: Configuration file not found at $CONFIG_FILE_DATABASE"
    exit 1
fi

# Set the Zabbix database password
sed -i "s/^DBPassword=.*/DBPassword=$NEW_PASSWORD/" "$CONFIG_FILE_DATABASE"

# === Restart Services ===
echo "🔃 Restarting services..."
systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm
systemctl enable zabbix-server zabbix-agent nginx php8.3-fpm

# === Verification ===
echo "🔃 Verifying installation and configuration..."

# Check if Services Are Active 
services=(zabbix-server zabbix-agent nginx php8.3-fpm)
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "❌ ❌ Error: $service is not active (running)."
        exit 1
    else
        echo "✅ $service is active (running)."
    fi
done

# Check if Services Are Enabled 
for service in "${services[@]}"; do
    if ! systemctl is-enabled --quiet "$service"; then
        echo "❌ ❌ Error: $service is not enabled."
        exit 1
    else 
        echo "✅ $service is enabled."
    fi
done

echo "Zabbix user and database checks completed successfully! 🎉"
