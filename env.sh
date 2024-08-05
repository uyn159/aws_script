#!/bin/bash

# Update package lists
sudo apt update

# Check if Git is already installed
if ! command -v git &> /dev/null; then
  # Install Git
  sudo apt install git -y
  echo "Git has been successfully installed!✅✅✅"
else
  echo "Git is already installed on this system.❎❎❎"
fi
# === User Information ===
GIT_USER_NAME="UynLe"       # Replace with your actual name
GIT_USER_EMAIL="uynle76@gmail.com"  # Replace with your actual email

# === Git Configuration ===
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

echo "Git user name and email configured successfully!"