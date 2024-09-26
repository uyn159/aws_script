#!/bin/bash

# Script Name: install_docker.sh
# Description: Installs Docker CE and Docker Compose on Ubuntu

set -e  # Exit on any error

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use 'sudo'."
    exit 1
fi

# Update package lists
apt-get update

# Install prerequisites
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists again
apt-get update

# Install Docker CE
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Check if Docker Compose is already installed
if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose is already installed."
else
    echo "❌ Docker Compose is not installed. Installing..."

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # Verify installation
    if command -v docker-compose &> /dev/null; then
        echo "✅ Docker Compose installation complete!"
    else
        echo "❌ Docker Compose installation failed. Please check for errors."
    fi
fi

# Add user to the 'docker' group (optional)
read -rp "Enter your username to add to the 'docker' group (or press Enter to skip): " username
if [[ -n "$username" ]]; then
    usermod -aG docker "$username"
    echo "User '$username' added to 'docker' group. Log out and back in for changes to take effect."
    grep docker /etc/group  # Verify group membership
fi

# Check Docker installation
if command -v docker &> /dev/null; then
    echo "✅ Docker is installed and available."
else
    echo "❌ Docker installation failed. Please check the logs for errors."
fi

# Fix Docker daemon socket permissions (if needed)
    sudo chmod 666 /var/run/docker.sock
    echo "✅ Docker daemon socket permissions fixed."
