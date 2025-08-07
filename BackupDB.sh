#!/bin/bash
###############################################################################
# Database Backup Script - Simplified & Optimized
# Copyright (c) 2025 VGX Consulting by Vijendra Malhotra. All rights reserved.
# https://vgx.digital
# 
# Version: 6.8
# Modified: August 6, 2025
#
# DESCRIPTION:
# Automated MySQL database backups with multi-storage backend support.
# Supports Git repositories, AWS S3, S3-compatible storage, and OneDrive.
#
# QUICK START:
# 1. Set storage type: export VGX_DB_STORAGE_TYPE="git|s3|onedrive" 
# 2. Configure credentials (see --help for details)
# 3. Set database connection: export VGX_DB_HOSTS="host1,host2"
# 4. Run: ./BackupDB.sh
#
# HELP: ./BackupDB.sh --help
###############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Unified logging function
log() {
    local level=$1
    shift
    local message="$*"
    
    # In production mode (not test/debug mode), only show WARN and ERROR
    if [[ "$TEST_MODE" != "true" && "$DEBUG_MODE" != "true" && "$level" != "ERROR" && "$level" != "WARN" ]]; then
        return 0
    fi
    
    case $level in
        "ERROR")   echo -e "${RED}[ERROR] $message${NC}" ;;
        "WARN")    echo -e "${YELLOW}[WARN] $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS] $message${NC}" ;;
        "INFO")    echo "[INFO] $message" ;;
        *)         echo "[$level] $message" ;;
    esac
}

#########################
# ENVIRONMENT LOADING   #
#########################

# Function to load environment variables from .env file
load_env_file() {
    local env_file="$1"
    if [[ -f "$env_file" ]]; then
        # Export variables from .env file, ignoring comments and empty lines
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # Process export statements and direct variable assignments
            if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
                local var_name="${BASH_REMATCH[2]}"
                local var_value="${BASH_REMATCH[3]}"
                
                # Remove surrounding quotes if present
                var_value=$(echo "$var_value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
                
                # Expand variables like $HOME
                var_value=$(eval echo "$var_value")
                
                # Export the variable
                export "$var_name"="$var_value"
            fi
        done < "$env_file"
        return 0
    fi
    return 1
}

# Silently load environment variables from .env files
load_env_file "./BackupDB.env" || load_env_file "$HOME/BackupDB.env" || true

#########################
# CONFIGURATION         #
#########################

# Script defaults
VERSION="6.8"
SCRIPT_NAME="BackupDB"
GITHUB_REPO="https://raw.githubusercontent.com/VGXConsulting/BackupDB/refs/heads/main/BackupDB.sh"

# Storage backend (git is default for backward compatibility)
STORAGE_TYPE=${VGX_DB_STORAGE_TYPE:-"git"}

# Local backup directory  
BACKUP_DIR=${VGX_DB_OPATH:-"$HOME/DBBackup/"}

# Cleanup settings - delete local backups after successful upload to save space
DELETE_LOCAL_BACKUPS=${VGX_DB_DELETE_LOCAL_BACKUPS:-"true"}

# Git backup retention period in days (-1 = never delete, 0 = delete all, >0 = days to keep)
GIT_RETENTION_DAYS=${VGX_DB_GIT_RETENTION_DAYS:-"-1"}

# Incremental backups (skip if no changes detected)
INCREMENTAL_BACKUPS=${VGX_DB_INCREMENTAL_BACKUPS:-"true"}

# Git configuration
GIT_REPO=${VGX_DB_GIT_REPO:-"git@github.com:YourUsername/DBBackups.git"}

# S3 configuration (works for AWS S3 and all S3-compatible services)
S3_BUCKET=${VGX_DB_S3_BUCKET:-""}
S3_PREFIX=${VGX_DB_S3_PREFIX:-"DatabaseBackups/"}
S3_ENDPOINT=${VGX_DB_S3_ENDPOINT_URL:-""}  # Leave empty for AWS S3
S3_REGION=${VGX_DB_S3_REGION:-""}

# OneDrive configuration
ONEDRIVE_REMOTE=${ONEDRIVE_REMOTE:-""}
ONEDRIVE_PATH=${ONEDRIVE_PATH:-"/DatabaseBackups"}

# Database configuration
if [[ -n "$VGX_DB_HOSTS" ]]; then
    IFS=',' read -ra DB_HOSTS <<< "$VGX_DB_HOSTS"
else
    DB_HOSTS=("localhost")
fi

if [[ -n "$VGX_DB_USERS" ]]; then
    IFS=',' read -ra DB_USERS <<< "$VGX_DB_USERS"
else
    DB_USERS=("root")
fi

if [[ -n "$VGX_DB_PASSWORDS" ]]; then
    IFS=',' read -ra DB_PASSWORDS <<< "$VGX_DB_PASSWORDS"
else
    DB_PASSWORDS=("password")
fi

# Date variables
TODAY=$(date +%Y%m%d)
if [[ "$OSTYPE" == "darwin"* ]]; then
    YESTERDAY=$(date -v -1d +%Y%m%d)
else
    YESTERDAY=$(date --date="yesterday" +%Y%m%d)
fi

#########################
# UTILITY FUNCTIONS     #
#########################

# Cleanup local backups after successful upload
cleanup_local_backups() {
    if [[ "$DELETE_LOCAL_BACKUPS" == "true" ]]; then
        if [[ -d "$BACKUP_DIR" ]]; then
            rm -rf "$BACKUP_DIR"
            log "WARN" "Deleted entire backup directory: $BACKUP_DIR"
        fi
    fi
}

# Execute AWS CLI command with optional endpoint
aws_cmd() {
    # AWS credentials already set as environment variables
    
    if [[ -n "$S3_ENDPOINT" ]]; then
        aws "$@" --endpoint-url="$S3_ENDPOINT"
    else
        aws "$@"
    fi
}

# Check for script updates
check_for_updates() {
    if command -v curl >/dev/null 2>&1; then
        local remote_version
        remote_version=$(curl -s --max-time 5 "$GITHUB_REPO" | grep "^VERSION=" | head -1 | cut -d'"' -f2 2>/dev/null)
        
        if [[ -n "$remote_version" ]] && [[ "$remote_version" != "$VERSION" ]]; then
            echo
            log WARN "New version available: $remote_version (current: $VERSION)"
            log INFO "Update available at: https://github.com/VGXConsulting/BackupDB"
            echo
        fi
    fi
}

# Show script help
show_help() {
    cat << 'EOF'
DATABASE BACKUP SCRIPT v6.8 - SIMPLIFIED & OPTIMIZED

USAGE:
  ./BackupDB.sh [OPTIONS]

OPTIONS:
  -h, --help         Show this help
  -v, --version      Show version
  -t, --test         Test configuration only
  -d, --debug        Debug mode (verbose logging)
  --dry-run          Show what would be done

STORAGE TYPES:
  git       Git repository (default)
  s3        AWS S3 or S3-compatible (Backblaze B2, Wasabi, etc.)
  onedrive  Microsoft OneDrive

CONFIGURATION METHODS:

  1. Environment Variables (export commands)
  2. BackupDB.env file in current directory
  3. BackupDB.env file in home directory ($HOME/BackupDB.env)

QUICK SETUP:

  Option 1: Environment Variables
  Git Storage:
    export VGX_DB_GIT_REPO="git@github.com:user/repo.git"

  S3/S3-Compatible:
    export VGX_DB_STORAGE_TYPE="s3"
    export AWS_ACCESS_KEY_ID="your-key"
    export AWS_SECRET_ACCESS_KEY="your-secret" 
    export VGX_DB_S3_BUCKET="your-bucket"
    export VGX_DB_S3_PREFIX="backups/"  # Optional folder prefix
    # For non-AWS (Backblaze B2, Wasabi, etc.):
    export VGX_DB_S3_ENDPOINT_URL="https://s3.region.service.com"

  OneDrive:
    # 1. Install rclone: brew install rclone
    # 2. Configure: rclone config → New remote → Microsoft OneDrive
    # 3. Test: rclone ls onedrive:
    export VGX_DB_STORAGE_TYPE="onedrive"
    export ONEDRIVE_REMOTE="onedrive"  # Name from rclone config
    export ONEDRIVE_PATH="/DatabaseBackups"  # Optional folder path

  Database:
    export VGX_DB_HOSTS="db1.com,db2.com"
    export VGX_DB_USERS="user1,user2"
    export VGX_DB_PASSWORDS="pass1,pass2"

  Cleanup Settings:
    export VGX_DB_DELETE_LOCAL_BACKUPS="false"      # Delete local backups after upload (default: true)
    export VGX_DB_GIT_RETENTION_DAYS="7"            # Git backup retention in days (default: -1 = never delete)

EXAMPLES:
  ./BackupDB.sh --test                    # Test configuration
  ./BackupDB.sh --debug                   # Run backup with debug logging
  ./BackupDB.sh                           # Run backup (quiet mode)
  VGX_DB_STORAGE_TYPE=s3 ./BackupDB.sh    # Use S3 storage

BACKBLAZE B2 EXAMPLE:
  export VGX_DB_STORAGE_TYPE="s3"
  export VGX_DB_S3_BUCKET="your-bucket"
  export AWS_ACCESS_KEY_ID="your-keyID"
  export AWS_SECRET_ACCESS_KEY="your-applicationKey" 
  export VGX_DB_S3_ENDPOINT_URL="https://s3.us-west-004.backblazeb2.com"
  ./BackupDB.sh

  Option 2: .env File Method
  Create BackupDB.env in current directory or $HOME:

    # BackupDB Configuration
    VGX_DB_STORAGE_TYPE=s3
    VGX_DB_S3_BUCKET=my-backup-bucket
    AWS_ACCESS_KEY_ID=your-access-key
    AWS_SECRET_ACCESS_KEY=your-secret-key
    VGX_DB_S3_ENDPOINT_URL=https://s3.amazonaws.com
    VGX_DB_HOSTS=db1.example.com,db2.example.com
    VGX_DB_USERS=backup_user1,backup_user2
    VGX_DB_PASSWORDS=secret1,secret2
    VGX_DB_DELETE_LOCAL_BACKUPS=false
    VGX_DB_GIT_RETENTION_DAYS=30

  Then simply run: ./BackupDB.sh
EOF
}

# Show version info
show_version() {
    echo "$SCRIPT_NAME v$VERSION"
    echo "Multi-storage database backup tool"
}

# Show current configuration
show_config() {
    log INFO "Configuration Summary:"
    echo "  Storage Type: $STORAGE_TYPE"
    echo "  Backup Directory: $BACKUP_DIR"
    
    case $STORAGE_TYPE in
        "git")
            echo "  Git Repository: $GIT_REPO"
            ;;
        "s3")
            echo "  S3 Bucket: $S3_BUCKET"
            echo "  S3 Prefix: $S3_PREFIX"
            if [[ -n "$S3_ENDPOINT" ]]; then
                echo "  S3 Endpoint: $S3_ENDPOINT"
            else
                echo "  S3 Endpoint: AWS Default"
            fi
            ;;
        "onedrive")
            echo "  OneDrive Remote: $ONEDRIVE_REMOTE"
            echo "  OneDrive Path: $ONEDRIVE_PATH"
            ;;
    esac
    
    echo "  Database Hosts: ${DB_HOSTS[*]}"
    echo "  Database Users: ${DB_USERS[*]}"
}

#########################
# VALIDATION FUNCTIONS  #
#########################

# Check if required commands exist
check_command() {
    local cmd=$1
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log ERROR "Required command '$cmd' not found. Please install it."
        return 1
    fi
}

# Validate storage configuration
validate_storage() {
    local test_connection=${1:-false}
    
    case $STORAGE_TYPE in
        "git")
            check_command git || return 1
            if [[ -z "$GIT_REPO" ]] || [[ "$GIT_REPO" == *"YourUsername"* ]]; then
                log ERROR "Git repository not configured. Set VGX_DB_GIT_REPO environment variable."
                return 1
            fi
            # Test Git connection only if requested
            if [[ "$test_connection" == "true" ]]; then
                log INFO "Testing Git connection..."
                if ! git ls-remote "$GIT_REPO" >/dev/null 2>&1; then
                    log ERROR "Git connection failed. Check repository URL and SSH keys."
                    return 1
                fi
            fi
            ;;
        "s3")
            check_command aws || return 1
            if [[ -z "$S3_BUCKET" ]]; then
                log ERROR "S3 bucket not configured. Set VGX_DB_S3_BUCKET environment variable."
                return 1
            fi
            if [[ -z "$AWS_ACCESS_KEY_ID" ]] || [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
                log ERROR "S3 credentials not configured. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."
                return 1
            fi
            # Test S3 connection only if requested
            if [[ "$test_connection" == "true" ]]; then
                log INFO "Testing S3 connection..."
                if ! aws_cmd s3 ls >/dev/null 2>&1; then
                    log ERROR "S3 connection failed. Check credentials and endpoint."
                    return 1
                fi
            fi
            ;;
        "onedrive")
            check_command rclone || return 1
            if [[ -z "$ONEDRIVE_REMOTE" ]]; then
                log ERROR "OneDrive remote not configured. Set ONEDRIVE_REMOTE environment variable."
                return 1
            fi
            # Test rclone connection only if requested
            if [[ "$test_connection" == "true" ]]; then
                log INFO "Testing OneDrive connection..."
                if ! rclone listremotes | grep -q "^${ONEDRIVE_REMOTE}:$"; then
                    log ERROR "OneDrive remote '$ONEDRIVE_REMOTE' not found. Run: rclone config"
                    return 1
                fi
            fi
            ;;
        *)
            log ERROR "Unsupported storage type: $STORAGE_TYPE"
            return 1
            ;;
    esac
}

# Validate database configuration
validate_database() {
    local test_connection=${1:-false}
    
    check_command mysql || return 1
    check_command mysqldump || return 1
    
    if [[ ${#DB_HOSTS[@]} -ne ${#DB_USERS[@]} ]] || [[ ${#DB_HOSTS[@]} -ne ${#DB_PASSWORDS[@]} ]]; then
        log ERROR "Database configuration mismatch. Hosts, users, and passwords arrays must have same length."
        return 1
    fi
    
    # Test database connections only if requested
    if [[ "$test_connection" == "true" ]]; then
        log INFO "Testing database connections..."
        for i in "${!DB_HOSTS[@]}"; do
            local host="${DB_HOSTS[$i]}"
            local user="${DB_USERS[$i]}"
            local password="${DB_PASSWORDS[$i]}"
            local port="3306"  # Default MySQL port
            
            log INFO "Testing connection to database: $host"
            if ! mysql -h "$host" -P "$port" -u "$user" -p"$password" -e "SELECT 1;" >/dev/null 2>&1; then
                log ERROR "Cannot connect to database: $host"
                return 1
            fi
        done
        log SUCCESS "All database connections successful!"
    fi
}

# Run all validations
validate_config() {
    local test_connection=${1:-false}
    log INFO "Validating configuration..."
    validate_storage "$test_connection" || return 1
    validate_database "$test_connection" || return 1
    log SUCCESS "Configuration validation passed!"
}

#########################
# STORAGE FUNCTIONS     #
#########################

# Upload to Git repository
upload_git() {
    local backup_path="$1"
    
    log INFO "Uploading to Git repository..."
    
    # Update repository
    if [[ -d "$backup_path/.git" ]]; then
        log INFO "Updating Git repository..."
        cd "$backup_path" && git pull || true
    fi
    
    cd "$backup_path" || return 1
    
    # Check for changes
    if git status --porcelain | grep -q '.'; then
        log INFO "Changes detected. Committing..."
        git add .
        git commit -m "Database backup: $TODAY"
        git push origin "$(git rev-parse --abbrev-ref HEAD)" || return 1
        log SUCCESS "Git upload completed."
        cleanup_local_backups
    else
        log INFO "No changes to commit."
        cleanup_local_backups
    fi
}

# Upload to S3 (works with all S3-compatible services)
upload_s3() {
    local backup_path="$1"
    
    log INFO "Uploading to S3 storage..."
    
    cd "$backup_path" || return 1
    
    # Upload all .gz files recursively to S3
    local s3_target="s3://$S3_BUCKET/${S3_PREFIX}${TODAY}/"
    log INFO "AWS Command: aws s3 cp . \"$s3_target\" --recursive --endpoint-url=\"$S3_ENDPOINT\""
    
    if aws_cmd s3 cp . "$s3_target" --recursive; then
        log SUCCESS "S3 upload completed."
        cleanup_local_backups
    else
        log ERROR "S3 upload failed."
        return 1
    fi
}

# Upload to OneDrive
upload_onedrive() {
    local backup_path="$1"
    
    log INFO "Uploading to OneDrive..."
    
    local target_path="${ONEDRIVE_REMOTE}:${ONEDRIVE_PATH}/${TODAY}"
    
    find "$backup_path" -name "*.gz" -type f | while read -r file; do
        local relative_path="${file#$backup_path/}"
        local target_dir=$(dirname "$target_path/$relative_path")
        
        rclone mkdir "$target_dir" 2>/dev/null || true
        
        log INFO "Uploading: $relative_path"
        if ! rclone copy "$file" "$target_dir"; then
            log ERROR "Failed to upload: $relative_path"
            return 1
        fi
    done
    
    log SUCCESS "OneDrive upload completed."
    cleanup_local_backups
}

# Main upload function
upload_backups() {
    local backup_path="$1"
    
    case $STORAGE_TYPE in
        "git")      upload_git "$backup_path" ;;
        "s3")       upload_s3 "$backup_path" ;;
        "onedrive") upload_onedrive "$backup_path" ;;
        *)          log ERROR "Unknown storage type: $STORAGE_TYPE"; return 1 ;;
    esac
}

#########################
# BACKUP FUNCTIONS      #
#########################

# Create database backup
backup_database() {
    local host="$1"
    local port="$2"
    local user="$3"
    local password="$4"
    local db="$5"
    local backup_path="$6"
    
    local backup_file="${backup_path}/${TODAY}_${db}.sql"
    
    log INFO "Backing up database: $db from $host"
    
    # Create backup
    mysqldump --add-drop-table --allow-keywords --skip-dump-date -c \
        -h "$host" -P "$port" -u "$user" -p"$password" "$db" > "$backup_file" 2>/dev/null
    
    if [[ ! -s "$backup_file" ]]; then
        log WARN "Backup file is empty, skipping: $db"
        rm -f "$backup_file"
        return 1
    fi
    
    # Compare with yesterday's backup if incremental backups are enabled
    if [[ "$INCREMENTAL_BACKUPS" == "true" ]]; then
        local yesterday_file="${backup_path}/${YESTERDAY}_${db}.sql.gz"
        if [[ -f "$yesterday_file" ]]; then
            log INFO "Comparing with yesterday's backup..."
            gunzip -c "$yesterday_file" > "${backup_path}/${YESTERDAY}_${db}.sql"
            
            if diff -q "${backup_path}/${YESTERDAY}_${db}.sql" "$backup_file" >/dev/null; then
                log INFO "No changes detected in $db, skipping."
                rm -f "$backup_file" "${backup_path}/${YESTERDAY}_${db}.sql"
                return 2  # Special code for "no changes"
            fi
            
            rm -f "${backup_path}/${YESTERDAY}_${db}.sql"
        fi
    fi
    
    # Compress backup
    gzip -f -9 "$backup_file"
    log SUCCESS "Database backup created: $db"
}

# Run backups for all configured databases
run_backups() {
    local backup_path="$1"
    mkdir -p "$backup_path"
    
    # Clean up old Git backups based on retention policy
    if [[ "$STORAGE_TYPE" == "git" && "$GIT_RETENTION_DAYS" -ge 0 ]]; then
        find "$backup_path" -name "*.sql.gz" -mtime "+$GIT_RETENTION_DAYS" -type f -delete 2>/dev/null || true
        log "INFO" "Cleaned up old Git backups (older than $GIT_RETENTION_DAYS days)"
    fi
    
    # Process each database host
    for (( i = 0; i < ${#DB_HOSTS[@]}; i++ )); do
        local host="${DB_HOSTS[$i]}"
        local user="${DB_USERS[$i]}"
        local password="${DB_PASSWORDS[$i]}"
        local port="3306"  # Default MySQL port
        
        log INFO "Processing database host: $host"
        
        # Test connection
        if ! mysql -h "$host" -P "$port" -u "$user" -p"$password" -e "SELECT 1;" >/dev/null 2>&1; then
            log ERROR "Cannot connect to database: $host"
            continue
        fi
        
        # Get database list (exclude system databases)
        local databases
        databases=$(mysql -h "$host" -P "$port" -u "$user" -p"$password" -e "SHOW DATABASES;" 2>/dev/null | \
                   tail -n +2 | grep -Ev "mysql|information_schema|performance_schema|sys")
        
        # Backup each database
        for db in $databases; do
            backup_database "$host" "$port" "$user" "$password" "$db" "$backup_path"
            case $? in
                0) ;; # Success, continue
                2) ;; # No changes detected, continue  
                *) log ERROR "Failed to backup database: $db"; return 1 ;;
            esac
        done
    done
}

#########################
# MAIN SCRIPT           #
#########################

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)    show_help; exit 0 ;;
        -v|--version) show_version; exit 0 ;;
        -t|--test)    TEST_MODE=true; shift ;;
        -d|--debug)   DEBUG_MODE=true; shift ;;
        --dry-run)    DRY_RUN=true; shift ;;
        *)            log ERROR "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Capture start time for timing
START_TIME=$(date +%s)

# Script header
echo "======================================================================"
echo "DATABASE BACKUP SCRIPT v$VERSION"
echo "Copyright (c) 2025 VGX Consulting"
echo "https://vgx.digital"
echo
echo "Starting at $(date)"
echo "======================================================================"

# Check for updates (non-blocking)
check_for_updates

# Show configuration
show_config
echo

# Validate configuration
if ! validate_config; then
    log ERROR "Configuration validation failed. Use --help for setup instructions."
    exit 1
fi

# Test mode - just validate and exit
if [[ "$TEST_MODE" == "true" ]]; then
    log INFO "Running connection tests..."
    if ! validate_config true; then
        log ERROR "Configuration test failed."
        exit 1
    fi
    log SUCCESS "Configuration test passed! Ready for backups."
    exit 0
fi

# Dry run mode
if [[ "$DRY_RUN" == "true" ]]; then
    log INFO "DRY RUN MODE - No actual backups will be performed"
    log INFO "Would backup databases from: ${DB_HOSTS[*]}"
    log INFO "Would upload to: $STORAGE_TYPE"
    exit 0
fi

# Run the backup process
log INFO "Starting backup process..."

# Setup Git repository if needed
if [[ "$STORAGE_TYPE" == "git" ]]; then
    if [[ -d "$BACKUP_DIR" && ! -d "$BACKUP_DIR/.git" ]]; then
        log INFO "Removing existing backup directory for Git setup..."
        rm -rf "$BACKUP_DIR"
    fi
    
    if [[ ! -d "$BACKUP_DIR/.git" ]]; then
        log INFO "Cloning Git repository..."
        git clone "$GIT_REPO" "$BACKUP_DIR" || {
            log ERROR "Failed to clone Git repository."
            exit 1
        }
    fi
fi

# Create backups
if ! run_backups "$BACKUP_DIR"; then
    log ERROR "Backup process failed."
    exit 1
fi

# Upload backups
if ! upload_backups "$BACKUP_DIR"; then
    log ERROR "Upload process failed."
    exit 1
fi

# Final cleanup message
log INFO "Backup process completed successfully!"

# Final success message
echo "======================================================================"
echo "SUCCESS: Backup process completed successfully at $(date)"
echo "Total execution time: $(( $(date +%s) - START_TIME )) seconds"
echo "======================================================================"