# Database Backup Script with Git Upload

## Overview
This script automates MySQL database backups for multiple database hosts, compresses the backups, and uploads them to a Git repository for versioning. It only uploads new backups if changes are detected from the previous day.

**Version:** 3.5  
**Last Modified:** April 20, 2025  
**Created by:** VGX Consulting by Vijendra Malhotra

## Features

- Backs up multiple MySQL database hosts
- Excludes system databases (mysql, information_schema, performance_schema, sys)
- Compresses backups to save storage space
- Uploads to Git repository for version control
- Only keeps new backups when changes are detected
- Automatically cleans up backups older than 5 days
- Cross-platform compatibility (Linux and macOS)

## Prerequisites

Before using this script, ensure you have the following:

1. Git installed and configured with SSH access to GitHub
2. MySQL Client tools installed (`mysql` and `mysqldump` commands)
3. SSH Keys set up for GitHub authentication
4. A GitHub repository created for storing your backups (should be private)

## Installation

1. Download the `BackupDB-Clients.sh` script to your server
2. Make the script executable:
   ```bash
   chmod +x BackupDB-Clients.sh
   ```
3. Edit the script to update configuration settings (see below)

## Configuration

Edit the script and update the following settings in the CONFIGURATION SETTINGS section:

1. **Backup Directory**: Change `opath` variable to your preferred backup location
   ```bash
   opath=$HOME/DBBackup/
   ```

2. **Git Repository**: Replace with your own GitHub repository URL (SSH format)
   ```bash
   git_repo="git@github.com:YourUsername/DBBackups.git"
   ```

3. **Database Connection Information**: Replace the example values with your actual database information
   ```bash
   # Database hosts
   mysqlhost=( "your-db-host-1" "your-db-host-2" "your-db-host-3" )
   
   # Database ports
   mysqlport=( "3306" "3306" "3306" )
   
   # Database usernames
   username=( "your-db-user-1" "your-db-user-2" "your-db-user-3" )
   
   # Database passwords
   password=( "your-db-password-1" "your-db-password-2" "your-db-password-3" )
   ```

### Security Note

For better security, consider using environment variables or a secure password management system rather than hardcoding database passwords in the script.

## Usage

### Manual Execution

Run the script manually with:
```bash
./BackupDB-Clients.sh
```

### Automated Execution

Set up a cron job to run the script automatically:

1. Open the crontab editor:
   ```bash
   crontab -e
   ```

2. Add a line to run the script daily at 2:00 AM:
   ```
   0 2 * * * /path/to/BackupDB-Clients.sh >> /path/to/backup.log 2>&1
   ```

## How It Works

The script performs the following operations:

1. **Git Repository Setup**:
   - Checks if the backup directory is a Git repository
   - If not, clones the remote repository
   - If it exists, pulls latest changes

2. **Cleanup**:
   - Removes backups older than 5 days
   - Removes deleted files from Git tracking

3. **Database Backup Process**:
   - For each configured database host:
     - Tests connection
     - Retrieves list of databases (excluding system DBs)
     - Creates a backup for each database
     - Compares with yesterday's backup (if exists)
     - Only keeps new backup if changes are detected
     - Compresses backup files with gzip

4. **Git Commit and Push**:
   - Commits changes with timestamp
   - Pushes to the remote GitHub repository
   - Only performs Git operations if changes were detected

## Backup File Naming

The backup files follow this naming convention:
```
YYYYMMDD_database-name.sql.gz
```

For example: `20250505_customers.sql.gz`

## Troubleshooting

### Git Authentication Failures
- Ensure SSH keys are properly set up with GitHub
- Test your connection with: `ssh -T git@github.com`

### Database Connection Errors
- Verify credentials and network connectivity
- Check that database hosts allow connections from your server
- Verify the MySQL client is installed properly

### Permission Issues
- Ensure script has execute permissions
- Verify write permissions to backup directory

## Support

For support, contact: support.backupdb@vgx.email

## License

Copyright (c) 2025 VGX Consulting by Vijendra Malhotra. All rights reserved.
