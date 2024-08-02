# === Configuration Variables ===
CONFIG_FILE_FRONTEND="/etc/zabbix/nginx.conf"
CONFIG_FILE_DATABASE="/etc/zabbix/zabbix_server.conf"
LISTEN_PORT="8080"          # Or 443 if using HTTPS
SERVER_NAME="54.251.28.73"  # Replace with your domain or IP
NEW_PASSWORD="54.251.28.73"
ZABBIX_USER=zabix
ZABBIX_PASSWORD=zabix
ZABBIX_DB_NAME=zabix
# === Zabbix Repository Setup ===
echo "🔃🔃🔃Setting up Zabbix repository..."
wget -q https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-6+ubuntu24.04_all.deb  # -q for quiet download

if [ $? -ne 0 ]; then
    echo "Error downloading Zabbix release package. Please check your internet connection and try again."
    exit 1
fi

sudo dpkg -i zabbix-release_6.0-6+ubuntu24.04_all.deb
sudo apt update

# === Zabbix Installation ===
echo "🔃🔃🔃Installing Zabbix components..."
sudo apt install -y zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent
# === Install PostgreSQL ===

echo "🔃🔃🔃Installing PostgreSQL... "
sudo apt update
sudo apt install -y postgresql postgresql-contrib

# Set Up Password for 'postgres' User
echo "🔃🔃🔃Enter🔃🔃🔃 a strong password for the 🔃🔃🔃Default🔃🔃🔃 PostgreSQL user (postgres):"
sudo passwd postgres  # Secure way to set password, uses system prompt

# # Create a Separate User for Zabbix
# echo "🔃🔃🔃Enter🔃🔃🔃 a username 🔃🔃🔃for the new🔃🔃🔃 Zabbix database user:"
# # read ZABBIX_USER

# echo "🔃🔃🔃Enter🔃🔃🔃 a strong password 🔃🔃🔃for the new🔃🔃🔃 Zabbix user:"
# # read -s ZABBIX_PASSWORD

# sudo -u postgres psql -c "CREATE USER $ZABBIX_USER WITH PASSWORD '$ZABBIX_PASSWORD';"

# # Create Zabbix Database
# echo "🔃🔃🔃Enter🔃🔃🔃 the name for the Zabbix database (e.g., zabbix_db):"
# # read ZABBIX_DB_NAME

# sudo -u postgres psql -c "CREATE DATABASE $ZABBIX_DB_NAME WITH OWNER $ZABBIX_USER;"

# # Grant Privileges
# sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $ZABBIX_DB_NAME TO $ZABBIX_USER;"

sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix 
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix 
# Restart PostgreSQL Service
echo "Restarting PostgreSQL..."
sudo systemctl restart postgresql

echo "PostgreSQL installation and basic setup complete! ✅"

# === Zabbix Repository Setup ===

echo "Configuration file 🔃🔃🔃$CONFIG_FILE_DATABASE🔃🔃🔃"

# Check if Configuration File Exists
if [ ! -f "$CONFIG_FILE_DATABASE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE_DATABASE"
    exit 1
fi

# Check if Password Setting Exists
if grep -q "^DBPassword=" "$CONFIG_FILE_DATABASE"; then
    # Update Existing Password
    sed -i "s/^DBPassword=.*/DBPassword=$NEW_PASSWORD/" "$CONFIG_FILE_DATABASE"
    echo "Zabbix database password updated ✅Successfully."
else
    # Add New Password Setting
    echo "DBPassword=$NEW_PASSWORD" >> "$CONFIG_FILE_DATABASE"
    echo "Zabbix database password added ✅Successfully."
fi


# Check if Configuration File Exists
if [ ! -f "$CONFIG_FILE_FRONTEND" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE_FRONTEND"
    exit 1
fi

# === Zabbix Frontend Configuration ===
echo "🔃🔃🔃Configuring Zabbix frontend (Nginx)..."
# Uncomment and Update 'listen' Directive
sed -i "/^ *# *listen/s/^ *# *//; s/listen .*/listen $LISTEN_PORT;/" "$CONFIG_FILE_FRONTEND"

# Uncomment and Update 'server_name' Directive
sed -i "/^ *# *server_name/s/^ *# *//; s/server_name .*/server_name $SERVER_NAME;/" "$CONFIG_FILE_FRONTEND"

# Restart
echo "Restart services...🔃🔃🔃"
systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm
systemctl enable zabbix-server zabbix-agent nginx php8.3-fpm 

# Check if Zabbix User Exists
echo "Checking for Zabbix user..."
sudo -u postgres psql -c "\du" | grep -q zabbix  # Search for 'zabbix' in the list of users

if [ $? -eq 0 ]; then
  echo "Zabbix user 'zabbix' exists. ✅"
else
  echo "ERROR: Zabbix user 'zabbix' not found. ❌"
  exit 1  # Exit script with error code if user not found
fi

# Check if Zabbix Database Exists
echo "Checking for Zabbix database..."
sudo -u postgres psql -c "\l" | grep -q zabbix  # Search for 'zabbix' in the list of databases

if [ $? -eq 0 ]; then
  echo "Zabbix database 'zabbix' exists. ✅"
else
  echo "ERROR: Zabbix database 'zabbix' not found. ❌"
  exit 1  # Exit script with error code if database not found
fi

echo "Zabbix user and database checks completed successfully! 🎉"

# Check for Errors
if [ $? -ne 0 ]; then
    echo "ERROR: An error occurred during the SQL import. Please check the PostgreSQL logs for details."
    exit 1  # Exit with an error code if the import failed
fi

# Check if Zabbix Tables Exist
echo "Verifying Zabbix tables..."
TABLES_FOUND=$(sudo -u zabbix psql -lqt zabbix | wc -l)

if [ $TABLES_FOUND -gt 0 ]; then
    echo "Zabbix tables found in the database. ✅"
else
    echo "ERROR: No Zabbix tables found. The import may not have been successful. ❌"
    exit 1
fi

# Check for Specific Tables (Optional)
# You can add checks for specific critical Zabbix tables here:
# REQUIRED_TABLES=("users" "hosts" "items" "history")  
# for table in "${REQUIRED_TABLES[@]}"; do
#     if ! sudo -u zabbix psql -lqt zabbix | grep -qw "$table"; then
#         echo "ERROR: Required table '$table' not found. ❌"
#         exit 1
#     fi
# done

if grep -q "^listen $LISTEN_PORT;" "$CONFIG_FILE_FRONTEND"; then
    echo "Successfully updated 'listen' directive in $CONFIG_FILE_FRONTEND . ✅"
else
    echo "Error: Failed to update 'listen' directive in $CONFIG_FILE_FRONTEND. Please check manually. ❌"
fi

if grep -q "^server_name $SERVER_NAME;" "$CONFIG_FILE_FRONTEND"; then
    echo "Successfully updated 'server_name' directive in $CONFIG_FILE_FRONTEND. ✅"
else
    echo "Error: Failed to update 'server_name' directive in $CONFIG_FILE_FRONTEND. Please check manually. ❌"
fi

services=(zabbix-server zabbix-agent nginx php8.3-fpm)

# Check if Services Are Active (Running)
echo "Checking service status..."
for service in "${services[@]}"; do
  if systemctl is-active --quiet "$service"; then
    echo "$service is active (running). ✅"
  else
    echo "ERROR: $service is not active (running). ❌"
    exit 1
  fi
done

# Check if Services Are Enabled (Start at Boot)
echo "Checking if services are enabled..."
for service in "${services[@]}"; do
  if systemctl is-enabled --quiet "$service"; then
    echo "$service is enabled. ✅"
  else
    echo "ERROR: $service is not enabled. ❌"
    exit 1
  fi
done