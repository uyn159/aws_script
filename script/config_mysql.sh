#!/bin/bash

# Database configuration
ZABBIX_DB_NAME="zabbix"
ZABBIX_USER="zabbix"
ZABBIX_PASSWORD="qweQWE123!@#"  # Generate a strong, random password
MYSQL_ROOT_PASSWORD="1" # Enter your root password here (or leave blank for prompt)

# Create the database
echo "Creating Zabbix database..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS $ZABBIX_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"

# Create the Zabbix user with a secure password
echo "Creating Zabbix user..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '$ZABBIX_USER'@'localhost' IDENTIFIED BY '$ZABBIX_PASSWORD';"

# Grant permissions to the Zabbix user on the Zabbix database
echo "Granting privileges..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON $ZABBIX_DB_NAME.* TO '$ZABBIX_USER'@'localhost';"

# Enable creation of stored procedures and functions (if necessary)
echo "Enabling log_bin_trust_function_creators..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SET GLOBAL log_bin_trust_function_creators = 1;"

# Display the generated password for reference
echo "Zabbix user password (save this!): $ZABBIX_PASSWORD"
# Disable log_bin_trust_function_creators
echo "Disabling log_bin_trust_function_creators..."
if mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SET GLOBAL log_bin_trust_function_creators = 0;"
then
  echo "Successfully disabled log_bin_trust_function_creators."
else
  echo "Failed to disable log_bin_trust_function_creators. Check the MySQL error log for details." >&2  # Print to standard error in case of failure
fi