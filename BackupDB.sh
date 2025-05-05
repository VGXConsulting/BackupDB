#!/bin/bash
###############################################################################
# Database Backup Script with Git Upload
# Copyright (c) 2025 VGX Consulting by Vijendra Malhotra. All rights reserved.
# 
# Version: 3.5
# Modified: April 20, 2025
#
# DESCRIPTION:
# This script automates MySQL database backups for multiple database hosts,
# compresses the backups, and uploads them to a Git repository for versioning.
# It only uploads new backups if changes are detected from the previous day.
###############################################################################

#######################
# SETUP INSTRUCTIONS #
#######################
# 
# === PREREQUISITES ===
# Before using this script, please ensure you have:
#   1. Git installed and configured with SSH access to GitHub
#   2. MySQL Client tools installed (mysql and mysqldump commands)
#   3. SSH Keys set up for GitHub authentication
#   4. A GitHub repository created for storing your backups
# 
# === INITIAL SETUP ===
#   1. Create a new private repository on GitHub for your backups
#   2. Update the configuration section below with your details:
#      - Set the backup directory path (opath)
#      - Set your GitHub repository URL (git_repo)
#      - Add your database hosts, ports, usernames, and passwords
#   3. Make the script executable: chmod +x backup_script.sh
# 
# === RUNNING THE SCRIPT ===
#   - Manual execution: ./backup_script.sh
#   - Automated execution via crontab:
#     1. Open crontab editor: crontab -e
#     2. Add: 0 2 * * * /path/to/backup_script.sh >> /path/to/backup.log 2>&1
# 
# === TROUBLESHOOTING ===
#   1. Git Authentication Failures:
#      - Ensure SSH keys are properly set up with GitHub
#      - Test connection: ssh -T git@github.com
#   2. Database Connection Errors:
#      - Verify credentials and network connectivity
#      - Check that database hosts allow connections from your server
#   3. Permission Issues:
#      - Ensure script has execute permissions
#      - Verify write permissions to backup directory
# 
# === SECURITY NOTES ===
#   - Store this script in a secure location with restricted access
#   - Consider using environment variables for credentials
#   - Use a private GitHub repository for your backups
#   - Consider encrypting sensitive database backups
#
#######################
# CONFIGURATION SETTINGS #
#######################

# Backup storage directory
# Change this to your preferred backup location
opath=$HOME/DBBackup/

# Git repository for storing backups
# Replace with your own repository URL
# IMPORTANT: Use SSH format (git@github.com:username/repo.git)
git_repo="git@github.com:YourUsername/DBBackups.git"

# Database connection information
# NOTE: You must replace these example values with your actual database information
# Example structure (Add all your database hosts in the array below):
# mysqlhost=( "db1.example.com" "db2.example.com" "db3.example.com" )
mysqlhost=( "your-db-host-1" "your-db-host-2" "your-db-host-3" )

# Database ports
# Add corresponding ports for each database host
# Usually 3306 for MySQL, but may vary depending on your setup
mysqlport=( "3306" "3306" "3306" )

# Database usernames
# Add corresponding usernames for each database host
# IMPORTANT: Ensure these accounts have proper backup privileges
username=( "your-db-user-1" "your-db-user-2" "your-db-user-3" )

# Database passwords
# Add corresponding passwords for each database host
# SECURITY NOTE: Consider using environment variables or secure password management
# rather than hardcoding passwords here
password=( "your-db-password-1" "your-db-password-2" "your-db-password-3" )

# Set date variables for backup files
today=$(date +%Y%m%d)
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS date command syntax
  yesterday=$(date -v -1d +%Y%m%d)
else
  # Linux date command syntax
  yesterday=$(date --date="yesterday" +%Y%m%d)
fi

#########################
# SCRIPT FUNCTIONALITY  #
#########################

echo "======================================================================"
echo "DATABASE BACKUP SCRIPT - Starting backup process at $(date)"
echo "======================================================================"

# Step 1: Ensure Git repository exists or clone it
if [ ! -d "$opath/.git" ]; then
  echo "[INFO] Git repository not found. Cloning from remote..."
  mkdir -p "$opath"
  git clone "$git_repo" "$opath"
  if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to clone Git repository. Please check your Git URL and SSH keys."
    exit 1
  fi
fi

# Step 2: Update local repository
echo "[INFO] Updating local Git repository..."
cd "$opath" || { echo "[ERROR] Failed to change to backup directory '$opath'"; exit 1; }
git pull

# Step 3: Clean up old backups (older than 5 days)
echo "[INFO] Deleting backups older than 5 days..."
find "$opath" -name "*.sql.gz" -mtime +5 -exec rm {} \;
git rm $(git ls-files --deleted) 2>/dev/null || true

# Step 4: Iterate over MySQL hosts for backups
for (( i = 0; i < ${#mysqlhost[@]}; i++ )); do
    echo "[INFO] Processing MySQL host: ${mysqlhost[$i]}"

    # Test connection before proceeding
    mysql -h "${mysqlhost[$i]}" -P "${mysqlport[$i]}" -u "${username[$i]}" -p"${password[$i]}" -e "SELECT 1;" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to connect to ${mysqlhost[$i]}. Skipping this host."
        continue
    fi

    # Fetch databases (excluding system databases)
    echo "[INFO] Retrieving database list..."
    databases=$(mysql -h "${mysqlhost[$i]}" -P "${mysqlport[$i]}" -u "${username[$i]}" -p"${password[$i]}" -e "SHOW DATABASES;" | tail -n +2 | grep -Ev "mysql|information_schema|performance_schema|sys")

    for db in $databases; do
        cpath="$opath/$db"
        mkdir -p "$cpath"
        backup_file="${cpath}/${today}_${db}.sql"

        echo "[INFO] Dumping database: $db from ${mysqlhost[$i]}"
        mysqldump --add-drop-table --allow-keywords --skip-dump-date -c \
          -h "${mysqlhost[$i]}" -P "${mysqlport[$i]}" -u "${username[$i]}" -p"${password[$i]}" "$db" \
          > "$backup_file" 2>/dev/null

        if [ ! -s "$backup_file" ]; then
            echo "[WARNING] Backup file $backup_file is empty. Skipping..."
            rm -f "$backup_file"
            continue
        fi

        # Compare with yesterday's backup if it exists
        if [ -f "${cpath}/${yesterday}_${db}.sql.gz" ]; then
            echo "[INFO] Comparing with yesterday's backup..."
            gunzip -c "${cpath}/${yesterday}_${db}.sql.gz" > "${cpath}/${yesterday}_${db}.sql"
            if diff -q "${cpath}/${yesterday}_${db}.sql" "$backup_file" >/dev/null; then
                echo "[INFO] No changes detected in $db, skipping this database."
                rm -f "$backup_file" "${cpath}/${yesterday}_${db}.sql"
                continue
            else
                echo "[INFO] Changes detected in $db, compressing new backup."
                gzip -9 -f "$backup_file"
            fi
            rm -f "${cpath}/${yesterday}_${db}.sql"  # Cleanup extracted file
        else
            echo "[INFO] No previous backup found for $db. Compressing and storing new backup."
            gzip -9 -f "$backup_file"
        fi
    done
done

# Step 5: Commit and push changes to Git repository
cd "$opath" || { echo "[ERROR] Failed to change to backup directory"; exit 1; }
if git status --porcelain | grep -q '.'; then
    echo "[INFO] Changes detected. Committing and pushing to GitHub..."
    git add .
    git commit -m "Database backup update: $today"
    git push origin main
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to push to Git repository. Please check your connectivity and permissions."
        exit 1
    fi
else
    echo "[INFO] No changes detected. Skipping Git push."
fi

echo "======================================================================"
echo "BACKUP PROCESS COMPLETED SUCCESSFULLY at $(date)"
echo " Script by - VGX Consulting. All rights reserved. For support, contact: support.backupdb@vgx.email
echo "======================================================================"