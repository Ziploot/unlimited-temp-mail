#!/bin/bash
# [ZipLoot] Private Temp Mail Installer
# ==============================================
cd "$(dirname "$0")"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] Python 3 is not installed or not in your PATH."
    echo "Please install Python 3 and try again."
    read -p "Press Enter to exit..."
    exit
fi

python3 deploy_helper.py
