#!/bin/bash

# Script Name: install_awscli.sh
# Description: Installs AWS CLI on Ubuntu

# Exit on any error
set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)." 
   exit 1
fi

# Check if unzip is installed, if not, install it
if ! command -v unzip &> /dev/null
then
    apt update
    apt install unzip -y
fi


# Download the installer
AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
AWS_CLI_ZIP="awscliv2.zip"

echo "Downloading AWS CLI installer..."
curl -L "$AWS_CLI_URL" -o "$AWS_CLI_ZIP"

# Extract the zip file
echo "Extracting AWS CLI installer..."
unzip -o "$AWS_CLI_ZIP"

# Install AWS CLI
echo "Installing AWS CLI..."
sudo ./aws/install --update

# Clean up
echo "Cleaning up..."
rm -rf "$AWS_CLI_ZIP"

# Verify installation
echo "Verifying AWS CLI installation..."
if aws --version &> /dev/null; then
    echo "AWS CLI installed successfully! ✅✅✅"
else
    echo "Error: AWS CLI installation failed. Please check the logs for details.❎❎❎"
    exit 1
fi
