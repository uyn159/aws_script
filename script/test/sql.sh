# === Function for Zabbix Database Setup ===
setup_database() {
    echo "🔃 Setting up Zabbix database..."
    # --- Common Setup ---
    ZABBIX_USER="zabbix"
    ZABBIX_DB_NAME="zabbix"
    NEW_PASSWORD=$(openssl rand -base64 12)

    case "$DATABASE" in
        mysql)
            sudo mysql -e "CREATE USER '$ZABBIX_USER'@'localhost' IDENTIFIED BY '$NEW_PASSWORD';" || echo "❌ Failed to create Zabbix user (already exists,..)"
            sudo mysql -e "CREATE DATABASE $ZABBIX_DB_NAME;" || echo "❌ Failed to create Zabbix database (already exists,..)"
            sudo mysql -e "GRANT ALL PRIVILEGES ON $ZABBIX_DB_NAME.* TO '$ZABBIX_USER'@'localhost';" || echo "❌ Failed to grant privileges (already granted,..)"
            sudo mysql -e "FLUSH PRIVILEGES;" 
            CONFIG_FILE_DATABASE="/etc/zabbix/zabbix_server.conf"  # Specific file for MySQL
            
            echo "🔃 Importing Zabbix schema..."
            zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | sudo mysql --user="$ZABBIX_USER" --password="$NEW_PASSWORD" "$ZABBIX_DB_NAME" 2>&1 | tee -a "$LOG_FILE" 
            ;;
        postgres)
            sudo -u postgres psql -c "CREATE USER $ZABBIX_USER WITH PASSWORD '$NEW_PASSWORD';" || echo "❌ Failed to create Zabbix user (already exists,..)"
            sudo -u postgres psql -c "CREATE DATABASE $ZABBIX_DB_NAME OWNER $ZABBIX_USER;" || echo "❌ Failed to create Zabbix database (already exists,..)"
            CONFIG_FILE_DATABASE="/etc/zabbix/zabbix_server.conf"  # Specific file for PostgreSQL

            echo "🔃 Importing Zabbix schema..."
            START_TIME=$(date +%s)
            LOG_COUNT=0
            {  
                zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u "$ZABBIX_USER" psql "$ZABBIX_DB_NAME" 2>&1 | while read -r line; do
                    if ((LOG_COUNT < 10)); then  
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
                echo -e "\n✅ Zabbix schema imported successfully."
            else
                echo "❌ Import failed. Remaining logs:"
                wait $IMPORT_PID 2>&1 | tee -a "$LOG_FILE" 
                log_and_exit "❌ Failed to import Zabbix schema."
            fi

            ;;
        *)
            log_and_exit "Unsupported database: $DATABASE" 
            ;;
    esac

    # Replace password in config file
    sed -i "s@^DBPassword=.*@DBPassword=$NEW_PASSWORD@" "$CONFIG_FILE_DATABASE" || log_and_exit "Failed to set the database password in $CONFIG_FILE_DATABASE"


    echo "✅ Finished Zabbix Database Setup"
}
# === Start Script ===

# ... (Operating System and Zabbix Version Check remains the same)

# === Database Selection ===
while true; do
    read -rp "Choose database (postgres or mysql): " DATABASE
    case "$DATABASE" in
        postgres|mysql) break ;;
        *) echo "Invalid choice. Please enter 'postgres' or 'mysql'." ;;
    esac
done

# ... (Server Public IP Detection, Download, and Installation remain the same)

# === Zabbix and Database Package Installation ===
echo "🔃 Checking and installing required packages..."
case "$DATABASE" in
    mysql)
        packages=(zabbix-server-mysql zabbix-frontend-php php8.3-mysql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent mariadb-server)
        ;;
    postgres)
        packages=(zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent postgresql postgresql-contrib)
        ;;
esac

for package in "${packages[@]}"; do
    if ! dpkg -s "$package" &> /dev/null; then
        apt install -y "$package" || log_and_exit "❌ Failed to install $package"
    else
        echo "✅ $package is already installed."
    fi
done


# Call the function
setup_database

# ... (Zabbix Frontend Configuration, Restart Services, Verification remain the same)
