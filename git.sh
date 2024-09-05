#!/bin/bash

# List of packages to check
# PACKAGES_TO_CHECK=("git" "package2" "package3")  # Replace with your package names

# for package in "${PACKAGES_TO_CHECK[@]}"; do
#   if dpkg -s "$package" &> /dev/null; then
#     echo "$package is installed. ✅"
#   else
#     echo "$package is not installed. ❌"
#     # Uncomment the following line if you want to install missing packages automatically
#     # sudo apt install -y "$package" 
#   fi
# done
# Check for Git
echo "Checking for Git installation..."
if command -v git &> /dev/null; then
    echo "✅ Git is installed."
else
    echo "❌ Git is not installed. You can install it with 'sudo apt install git'"
fi
# Get current Git configuration
current_name=$(git config --global user.name)
current_email=$(git config --global user.email)

# Display current configuration
echo "Current Git configuration:"
echo "  Name:  $current_name"
echo "  Email: $current_email"

# Ask if user wants to change configuration
echo -n "Do you want to change these settings? (y/n): "
read answer

# Handle user's response
case $answer in
  [Yy]* )
    # Prompt for new information
    echo -n "Enter new Git user name(example:"uynle"): "
    read new_name
    echo -n "Enter new Git user email(example:"uynle...@gmail.com"): "
    read new_email

    # Set new configuration
    git config --global user.name "$new_name"
    git config --global user.email "$new_email"

    echo "Git user name and email updated successfully!"
    ;;
  [Nn]* )
    echo "Git configuration remains unchanged."
    ;;
  * )
    echo "Invalid input. Please enter 'y' or 'n'."
    ;;
esac


# # Check for netstat
# echo "🔃 Checking for netstat installation..."
# if command -v netstat &> /dev/null; then
#     echo "✅ netstat is installed."

#     # Popular netstat Commands
#     echo -e "\nHere are some popular netstat commands:"
#     echo "-----------------------------------------"
#     echo "- List all active connections:"
#     echo "  sudo netstat -tulpn"
#     echo "- List listening ports:"
#     echo "  sudo netstat -ltunp"
#     echo "- Show statistics for network protocols:"
#     echo "  netstat -s"
#     echo "- Display routing table:"
#     echo "  netstat -rn"

# else
#     echo "Install net-tools."
#     apt install net-tools
#     echo "✅ netstat is installed."
# fi
