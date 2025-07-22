#!/bin/bash
###############################################################################
# Database Backup Script with Git Upload
# Copyright (c) 2025 VGX Consulting by Vijendra Malhotra. All rights reserved.
# 
# Version: 4.3
# Modified: July 22, 2025
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
#   3. Make the script executable: chmod +x BackupDB.sh
# 
# === RUNNING THE SCRIPT ===
#   - Manual execution: ./BackupDB.sh
#   - Automated execution via crontab:
#     1. Open crontab editor: crontab -e
#     2. Add: 0 2 * * * /path/to/BackupDB.sh >> /path/to/backup.log 2>&1
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

#######################
# CONFIGURATION PRIORITY: Environment Variables > Local Values #
#######################

# Backup storage directory
# Environment variable: VGX_DB_OPATH
# Change this to your preferred backup location
opath=${VGX_DB_OPATH:-"$HOME/DBBackup/"}

# Git repository for storing backups
# Environment variable: VGX_DB_GIT_REPO
# Replace with your own repository URL
# IMPORTANT: Use SSH format (git@github.com:username/repo.git)
git_repo=${VGX_DB_GIT_REPO:-"git@github.com:YourUsername/DBBackups.git"}

# Database connection information
# Environment variables: VGX_DB_HOSTS, VGX_DB_PORTS, VGX_DB_USERS, VGX_DB_PASSWORDS
# NOTE: You must replace these example values with your actual database information
# For environment variables, use comma-separated values: "host1,host2,host3"

# Parse environment variables or use defaults
if [[ -n "$VGX_DB_HOSTS" ]]; then
    IFS=',' read -ra mysqlhost <<< "$VGX_DB_HOSTS"
else
    mysqlhost=( "your-db-host-1" "your-db-host-2" "your-db-host-3" )
fi

if [[ -n "$VGX_DB_PORTS" ]]; then
    IFS=',' read -ra mysqlport <<< "$VGX_DB_PORTS"
else
    # Usually 3306 for MySQL, but may vary depending on your setup
    mysqlport=( "3306" "3306" "3306" )
fi

if [[ -n "$VGX_DB_USERS" ]]; then
    IFS=',' read -ra username <<< "$VGX_DB_USERS"
else
    # IMPORTANT: Ensure these accounts have proper backup privileges
    username=( "your-db-user-1" "your-db-user-2" "your-db-user-3" )
fi

if [[ -n "$VGX_DB_PASSWORDS" ]]; then
    IFS=',' read -ra password <<< "$VGX_DB_PASSWORDS"
else
    # SECURITY NOTE: Consider using environment variables for secure password management
    password=( "your-db-password-1" "your-db-password-2" "your-db-password-3" )
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function with color support
logme() {
    local level=$1
    shift
    local message="$*"
    
    case $level in
        "ERROR")
            echo -e "${RED}[ERROR] $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING] $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS] $message${NC}"
            ;;
        "INFO")
            echo "[INFO] $message"
            ;;
        *)
            echo "$level $message"
            ;;
    esac
}

# Function to display configuration source
show_config() {
    echo "[CONFIG] Configuration loaded from:"
    echo "  Backup Path: $([ -n "$VGX_DB_OPATH" ] && echo "VGX_DB_OPATH" || echo "script default") -> $opath"
    echo "  Git Repo: $([ -n "$VGX_DB_GIT_REPO" ] && echo "VGX_DB_GIT_REPO" || echo "script default") -> $git_repo"
    echo "  DB Hosts: $([ -n "$VGX_DB_HOSTS" ] && echo "VGX_DB_HOSTS" || echo "script default") -> ${mysqlhost[*]}"
    echo "  DB Users: $([ -n "$VGX_DB_USERS" ] && echo "VGX_DB_USERS" || echo "script default") -> ${username[*]}"
    echo "  Credentials: $([ -n "$VGX_DB_PASSWORDS" ] && echo "VGX_DB_PASSWORDS (secured)" || echo "script default (insecure)")"
}

# Enhanced OS detection
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS_TYPE="macos"
  PACKAGE_MANAGER="brew"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS_TYPE="linux"
  if command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER="apt"
  elif command -v yum >/dev/null 2>&1; then
    PACKAGE_MANAGER="yum"
  elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
  elif command -v zypper >/dev/null 2>&1; then
    PACKAGE_MANAGER="zypper"
  else
    PACKAGE_MANAGER="unknown"
  fi
else
  OS_TYPE="unknown"
  PACKAGE_MANAGER="unknown"
fi

# Set date variables for backup files
today=$(date +%Y%m%d)
if [[ "$OS_TYPE" == "macos" ]]; then
  # macOS date command syntax
  yesterday=$(date -v -1d +%Y%m%d)
else
  # Linux date command syntax
  yesterday=$(date --date="yesterday" +%Y%m%d)
fi

#############################
# DEPENDENCY VERIFICATION   #
#############################

# Function to check if running with elevated permissions
check_elevated_permissions() {
    if [[ $EUID -eq 0 ]] || [[ -n "$SUDO_USER" ]] || groups $USER | grep -q '\(admin\|sudo\|wheel\)'; then
        return 0  # Has elevated permissions
    else
        return 1  # No elevated permissions
    fi
}

# Function to install missing dependencies automatically
install_dependency() {
    local dep=$1
    local install_cmd=""
    
    case $PACKAGE_MANAGER in
        "brew")
            case $dep in
                "mysql") install_cmd="brew install mysql-client" ;;
                "git") install_cmd="brew install git" ;;
                "git-lfs") install_cmd="brew install git-lfs" ;;
                *) install_cmd="brew install $dep" ;;
            esac
            ;;
        "apt")
            case $dep in
                "mysql") install_cmd="sudo apt-get update && sudo apt-get install -y mysql-client" ;;
                "git") install_cmd="sudo apt-get update && sudo apt-get install -y git" ;;
                "git-lfs") install_cmd="sudo apt-get update && sudo apt-get install -y git-lfs" ;;
                *) install_cmd="sudo apt-get update && sudo apt-get install -y $dep" ;;
            esac
            ;;
        "yum"|"dnf")
            case $dep in
                "mysql") install_cmd="sudo $PACKAGE_MANAGER install -y mysql" ;;
                "git") install_cmd="sudo $PACKAGE_MANAGER install -y git" ;;
                "git-lfs") install_cmd="sudo $PACKAGE_MANAGER install -y git-lfs" ;;
                *) install_cmd="sudo $PACKAGE_MANAGER install -y $dep" ;;
            esac
            ;;
        "zypper")
            case $dep in
                "mysql") install_cmd="sudo zypper install -y mysql-client" ;;
                "git") install_cmd="sudo zypper install -y git" ;;
                "git-lfs") install_cmd="sudo zypper install -y git-lfs" ;;
                *) install_cmd="sudo zypper install -y $dep" ;;
            esac
            ;;
    esac
    
    if [[ -n "$install_cmd" ]]; then
        echo "[INFO] Installing $dep using: $install_cmd"
        if check_elevated_permissions || [[ "$install_cmd" == *"sudo "* ]]; then
            bash -c "$install_cmd"
        else
            echo "[INFO] Running with sudo: sudo $install_cmd"
            sudo bash -c "$install_cmd"
        fi
        return $?
    else
        logme WARNING "Could not determine installation command for $dep on $OS_TYPE with $PACKAGE_MANAGER"
        return 1
    fi
}

# Function to provide manual installation instructions
provide_install_instructions() {
    local dep=$1
    echo "[MANUAL INSTALLATION REQUIRED] Please install $dep using:"
    
    case $PACKAGE_MANAGER in
        "brew")
            case $dep in
                "mysql") echo "  brew install mysql-client" ;;
                "git") echo "  brew install git" ;;
                "git-lfs") echo "  brew install git-lfs" ;;
                *) echo "  brew install $dep" ;;
            esac
            ;;
        "apt")
            case $dep in
                "mysql") echo "  sudo apt-get update && sudo apt-get install mysql-client" ;;
                "git") echo "  sudo apt-get update && sudo apt-get install git" ;;
                "git-lfs") echo "  sudo apt-get update && sudo apt-get install git-lfs" ;;
                *) echo "  sudo apt-get install $dep" ;;
            esac
            ;;
        "yum"|"dnf")
            case $dep in
                "mysql") echo "  sudo $PACKAGE_MANAGER install mysql" ;;
                "git") echo "  sudo $PACKAGE_MANAGER install git" ;;
                "git-lfs") echo "  sudo $PACKAGE_MANAGER install git-lfs" ;;
                *) echo "  sudo $PACKAGE_MANAGER install $dep" ;;
            esac
            ;;
        "zypper")
            case $dep in
                "mysql") echo "  sudo zypper install mysql-client" ;;
                "git") echo "  sudo zypper install git" ;;
                "git-lfs") echo "  sudo zypper install git-lfs" ;;
                *) echo "  sudo zypper install $dep" ;;
            esac
            ;;
        *)
            logme ERROR "Unknown package manager. Please install $dep manually."
            ;;
    esac
}

# Function to check all required dependencies
check_dependencies() {
    local missing_deps=()
    local required_commands=("git" "mysql" "mysqldump" "gzip" "gunzip" "find" "diff")
    
    echo "[INFO] Checking system dependencies..."
    echo "[INFO] Detected OS: $OS_TYPE, Package Manager: $PACKAGE_MANAGER"
    
    # Check basic commands
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            case $cmd in
                "mysql"|"mysqldump")
                    if [[ ! " ${missing_deps[@]} " =~ " mysql " ]]; then
                        missing_deps+=("mysql")
                    fi
                    ;;
                *)
                    missing_deps+=("$cmd")
                    ;;
            esac
        fi
    done
    
    # Check Git LFS separately
    if command -v "git" >/dev/null 2>&1; then
        if ! git lfs version >/dev/null 2>&1; then
            missing_deps+=("git-lfs")
        fi
    fi
    
    # Handle missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        logme WARNING "Missing dependencies detected: ${missing_deps[*]}"
        
        if check_elevated_permissions; then
            echo "[INFO] Running with elevated permissions."
            read -p "[QUESTION] Would you like to automatically install missing dependencies? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                local install_failed=false
                for dep in "${missing_deps[@]}"; do
                    if ! install_dependency "$dep"; then
                        install_failed=true
                        provide_install_instructions "$dep"
                    fi
                done
                
                if $install_failed; then
                    logme ERROR "Some dependencies failed to install automatically."
                    logme ERROR "Please install them manually and run the script again."
                    exit 1
                fi
                
                # Initialize git-lfs if it was just installed
                if [[ " ${missing_deps[@]} " =~ " git-lfs " ]] && command -v "git" >/dev/null 2>&1; then
                    echo "[INFO] Initializing Git LFS..."
                    git lfs install --system 2>/dev/null || git lfs install
                fi
            else
                echo "[INFO] Please install the missing dependencies and run the script again."
                for dep in "${missing_deps[@]}"; do
                    provide_install_instructions "$dep"
                done
                exit 1
            fi
        else
            echo "[INFO] No elevated permissions detected."
            logme ERROR "Please install the missing dependencies and run the script again."
            for dep in "${missing_deps[@]}"; do
                provide_install_instructions "$dep"
            done
            exit 1
        fi
    else
        logme SUCCESS "All required dependencies are installed."
        
        # Ensure git-lfs is initialized even if already installed
        if command -v "git" >/dev/null 2>&1 && git lfs version >/dev/null 2>&1; then
            git lfs install --system 2>/dev/null || git lfs install 2>/dev/null || true
        fi
    fi
}

# Function to add LFS pattern if not already tracked
add_lfs_pattern() {
    local pattern=$1
    if [[ ! -f "$opath/.gitattributes" ]] || ! grep -q "$pattern" "$opath/.gitattributes"; then
        echo "[INFO] Adding LFS pattern: $pattern"
        git lfs track "$pattern"
        return 0
    else
        echo "[INFO] Pattern $pattern already tracked in LFS"
        return 1
    fi
}

#########################
# SCRIPT FUNCTIONALITY  #
#########################

echo "======================================================================"
echo "DATABASE BACKUP SCRIPT v4.3"
echo "Copyright (c) 2025 VGX Consulting https://vgx.digital"
echo
echo "Starting backup process at $(date)"
echo "======================================================================"

# Step 0a: Show configuration
show_config
echo

# Step 0b: Check system dependencies
check_dependencies

# Step 1: Ensure Git repository exists or clone it
if [ ! -d "$opath/.git" ]; then
  echo "[INFO] Git repository not found. Cloning from remote..."
  mkdir -p "$opath"
  git clone "$git_repo" "$opath"
  if [ $? -ne 0 ]; then
    logme ERROR "Failed to clone Git repository. Please check your Git URL and SSH keys."
    exit 1
  fi
fi

# Step 2: Update local repository
echo "[INFO] Updating local Git repository..."
cd "$opath" || { logme ERROR "Failed to change to backup directory '$opath'"; exit 1; }
if ! git pull; then
    logme WARNING "Failed to pull from remote repository. Continuing with local state..."
fi

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
        logme ERROR "Failed to connect to ${mysqlhost[$i]}. Skipping this host."
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
            logme WARNING "Backup file $backup_file is empty. Skipping..."
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

# Step 4.5: Manage Git LFS tracking for large backup files
echo "[INFO] Checking for large backup files and managing LFS tracking..."

# Find files larger than 100MB and add LFS patterns for their databases
find "$opath" -name "*.gz" -size +100M 2>/dev/null | while read -r file; do
    db_name=$(basename "$(dirname "$file")")
    echo "[INFO] Large backup detected: $file"
    add_lfs_pattern "$db_name/*.gz"
done

# Add .gitattributes if it exists
[[ -f "$opath/.gitattributes" ]] && git add .gitattributes 2>/dev/null

# Step 5: Commit and push changes to Git repository
cd "$opath" || { logme ERROR "Failed to change to backup directory"; exit 1; }
if git status --porcelain | grep -q '.'; then
    echo "[INFO] Changes detected. Committing and pushing to GitHub..."

    git add .
    git commit -m "Database backup update: $today"
    
    # Get the current branch name
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git push origin "$current_branch"
    if [ $? -ne 0 ]; then
        logme ERROR "Failed to push to Git repository. Please check your connectivity and permissions."
        exit 1
    fi
else
    echo "[INFO] No changes detected. Skipping Git push."
fi

echo "======================================================================"
echo "BACKUP PROCESS COMPLETED SUCCESSFULLY at $(date)"
echo " Script by - VGX Consulting. All rights reserved. For support, contact: support.backupdb@vgx.email"
echo "======================================================================"