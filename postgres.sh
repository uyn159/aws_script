#!/bin/bash

# Install PostgreSQL
echo "Installing PostgreSQL...🔃 "
sudo apt update
sudo apt install -y postgresql postgresql-contrib

# Prompt for PostgreSQL Default User (postgres) Password
echo "Enter the password for the default PostgreSQL user (postgres):🔃"
read -s POSTGRES_PASSWORD  # Read the password silently

# Set Password for 'postgres' User
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"

# (Optional) Create a New User and Database
echo "Do you want to create a new PostgreSQL user and database? (y/n)🔃"
read CREATE_NEW_USER_DB

if [ "$CREATE_NEW_USER_DB" == "y" ] || [ "$CREATE_NEW_USER_DB" == "Y" ]; then
    echo "Enter the new PostgreSQL username:🔃"
    read NEW_USERNAME

    echo "Enter the password for the new user:🔃"
    read -s NEW_USER_PASSWORD

    echo "Enter the name for the new database:🔃"
    read NEW_DATABASE_NAME

    # Create New User
    sudo -u postgres createuser --interactive --pwprompt $NEW_USERNAME

    # Create New Database
    sudo -u postgres createdb -O $NEW_USERNAME $NEW_DATABASE_NAME

    echo "New user and database created.✅✅✅"
fi

# Restart PostgreSQL Service
echo "Restarting PostgreSQL..."
sudo systemctl restart postgresql

echo "PostgreSQL installation complete! ✅"
