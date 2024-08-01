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
