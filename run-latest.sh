#!/bin/bash
###############################################################################
# BackupDB Latest Version Runner
# Downloads and executes the latest BackupDB script from GitHub
###############################################################################

REPO_URL="https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sh"
TEMP_SCRIPT="/tmp/BackupDB-latest.sh"

echo "Downloading latest BackupDB script..."
if wget -q -O "$TEMP_SCRIPT" "$REPO_URL" || curl -s -o "$TEMP_SCRIPT" "$REPO_URL"; then
    chmod +x "$TEMP_SCRIPT"
    echo "Running BackupDB script..."
    "$TEMP_SCRIPT"
    rm -f "$TEMP_SCRIPT"
else
    echo "ERROR: Failed to download script from $REPO_URL"
    exit 1
fi