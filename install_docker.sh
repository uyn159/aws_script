#!/bin/bash

# Script Name: install_docker.sh
# Description: Installs Docker CE on Ubuntu

# Exit on any error
set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)." 
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

echo "Docker installation complete!"

# Install Docker-compose
curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)"  -o /usr/local/bin/docker-compose
mv /usr/local/bin/docker-compose /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

echo "Docker compose installation complete "
# Optional: Add user to the 'docker' group (for non-root usage)
read -p "Enter your username to add to the 'docker' group (optional): " username
if [[ -n "$username" ]]; then
    usermod -aG docker "$username"
    echo "User '$username' added to 'docker' group. You may need to log out and back in."
    echo "Check user group 'docker'"
    grep docker /etc/group
fi

# Fix permission
echo "Fix:'Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock'"
newgrp docker
chmod 666 /var/run/docker.sock