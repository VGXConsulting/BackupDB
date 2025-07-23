#!/bin/bash
###############################################################################
# Database Backup Script with Multi-Storage Backend Support
# Copyright (c) 2025 VGX Consulting by Vijendra Malhotra. All rights reserved.
# 
# Version: 5.0
# Modified: July 22, 2025
#
# DESCRIPTION:
# This script automates MySQL database backups for multiple database hosts,
# compresses the backups, and supports multiple storage backends including Git,
# Amazon S3, and Microsoft OneDrive for versioning and remote storage.
# Features intelligent backup detection and only uploads new backups when changes
# are detected from the previous day. This major release adds flexible storage
# options to meet diverse backup retention and compliance requirements.
###############################################################################


#######################
# SETUP INSTRUCTIONS #
#######################
# 
# === PREREQUISITES ===
# Before using this script, please ensure you have:
#   1. MySQL Client tools installed (mysql and mysqldump commands)
#   2. Storage backend dependencies based on your chosen storage type:
#      - Git: Git installed, SSH keys configured, GitHub repository created
#      - S3: AWS CLI installed and configured with credentials
#      - OneDrive: rclone installed and configured with OneDrive remote
# 
# === INITIAL SETUP ===
# 
# 1. CHOOSE YOUR STORAGE BACKEND:
#    Set environment variable: export VGX_DB_STORAGE_TYPE="git|s3|onedrive"
#    Default is "git" for backward compatibility
# 
# 2. CONFIGURE STORAGE-SPECIFIC SETTINGS:
# 
#    === GIT STORAGE SETUP ===
#    - Create a private repository on GitHub for your backups
#    - Configure SSH keys: ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
#    - Add SSH key to GitHub: cat ~/.ssh/id_rsa.pub
#    - Test connection: ssh -T git@github.com
#    - Set repository: export VGX_DB_GIT_REPO="git@github.com:username/repo.git"
# 
#    === AWS S3 STORAGE SETUP ===
#    - Install AWS CLI: pip install awscli (or use package manager)
#    - Set AWS credentials via environment variables
#      * AWS Access Key ID: [Your AWS Access Key]
#      * AWS Secret Access Key: [Your AWS Secret Key]
#      * Default region name: [e.g., us-east-1]
#      * Default output format: json
#    - Create S3 bucket: aws s3 mb s3://your-backup-bucket
#    - Set bucket: export AWS_S3_BUCKET="your-backup-bucket"
#    - Optional prefix: export AWS_S3_PREFIX="database-backups/"
# 
#    === ONEDRIVE STORAGE SETUP ===
#    - Install rclone: https://rclone.org/downloads/
#    - Configure OneDrive remote: rclone config
#      * Choose "New remote" → Enter name (e.g., "onedrive")
#      * Choose "Microsoft OneDrive" → Follow authentication flow
#      * Test connection: rclone ls onedrive:
#    - Set remote name: export ONEDRIVE_REMOTE="onedrive"
#    - Set path: export ONEDRIVE_PATH="/DatabaseBackups"
# 
# 3. CONFIGURE DATABASE CONNECTION:
#    - Set database hosts: export VGX_DB_HOSTS="host1,host2,host3"
#    - Set database users: export VGX_DB_USERS="user1,user2,user3"
#    - Set database passwords: export VGX_DB_PASSWORDS="pass1,pass2,pass3"
#    - Set backup directory: export VGX_DB_OPATH="/path/to/backups"
# 
# 4. Make the script executable: chmod +x BackupDB.sh
# 
# === RUNNING THE SCRIPT ===
# 
# Manual execution with different storage backends:
# 
#   Git Storage (default):
#     ./BackupDB.sh
# 
#   S3 Storage:
#     export VGX_DB_STORAGE_TYPE="s3"
#     export AWS_S3_BUCKET="my-backup-bucket"
#     ./BackupDB.sh
# 
#   OneDrive Storage:
#     export VGX_DB_STORAGE_TYPE="onedrive" 
#     export ONEDRIVE_REMOTE="onedrive"
#     ./BackupDB.sh
# 
# Automated execution via crontab:
#   1. Create environment file: /home/user/.backup_env
#      export VGX_DB_STORAGE_TYPE="s3"
#      export AWS_S3_BUCKET="my-backup-bucket"
#      export VGX_DB_HOSTS="db1.example.com"
#      # ... other variables
#   2. Open crontab editor: crontab -e  
#   3. Add: 0 2 * * * source ~/.backup_env && /path/to/BackupDB.sh >> /path/to/backup.log 2>&1
# 
# === TROUBLESHOOTING ===
# 
#   Storage-Specific Issues:
# 
#   1. Git Authentication Failures:
#      - Ensure SSH keys are properly set up with GitHub
#      - Test connection: ssh -T git@github.com
#      - Check repository permissions and SSH agent
# 
#   2. AWS S3 Authentication Failures:
#      - Verify credentials: aws sts get-caller-identity
#      - Check bucket exists: aws s3 ls s3://your-bucket-name
#      - Verify IAM permissions for s3:PutObject, s3:GetObject, s3:DeleteObject
#      - Test AWS CLI: aws s3 ls
# 
#   3. OneDrive Authentication Failures:
#      - Check rclone config: rclone config show
#      - Test connection: rclone ls onedrive:
#      - Re-authenticate if needed: rclone config reconnect onedrive
#      - Verify remote name matches ONEDRIVE_REMOTE variable
# 
#   General Issues:
# 
#   4. Database Connection Errors:
#      - Verify credentials and network connectivity
#      - Check that database hosts allow connections from your server
#   5. Permission Issues:
#      - Ensure script has execute permissions
#      - Verify write permissions to backup directory
#   6. Missing Dependencies:
#      - Script will attempt to install missing packages automatically
#      - Manual installation may be required for some systems
# 
# === SECURITY NOTES ===
#   - Store this script in a secure location with restricted access
#   - ALWAYS use environment variables for credentials (never hardcode passwords)
#   - Storage security best practices:
#     * Git: Use private repositories and SSH keys
#     * S3: Use IAM roles/policies, enable bucket encryption, restrict access
#     * OneDrive: Use app passwords, enable 2FA on Microsoft account
#   - Consider encrypting database dumps before upload for sensitive data
#   - Regularly rotate access keys and review permissions
#   - Monitor backup access logs for unauthorized usage
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

# Storage backend configuration
# Environment variable: VGX_DB_STORAGE_TYPE (options: git, s3, onedrive)
STORAGE_TYPE=${VGX_DB_STORAGE_TYPE:-"git"}

# Git repository for storing backups (used when STORAGE_TYPE=git)
# Environment variable: VGX_DB_GIT_REPO
# Replace with your own repository URL
# IMPORTANT: Use SSH format (git@github.com:username/repo.git)
git_repo=${VGX_DB_GIT_REPO:-"git@github.com:YourUsername/DBBackups.git"}

# AWS S3 configuration (used when STORAGE_TYPE=s3)
# Environment variables: AWS_S3_BUCKET, AWS_S3_PREFIX, AWS_ENDPOINT_URL, AWS_S3_REGION
AWS_S3_BUCKET=${AWS_S3_BUCKET:-""}
AWS_S3_PREFIX=${AWS_S3_PREFIX:-"backups/"}
AWS_ENDPOINT_URL=${AWS_ENDPOINT_URL:-""}  # For S3-compatible storage (Backblaze, Wasabi, etc.)
AWS_S3_REGION=${AWS_S3_REGION:-"us-east-1"}  # Default region

# OneDrive configuration (used when STORAGE_TYPE=onedrive)
# Environment variables: ONEDRIVE_REMOTE, ONEDRIVE_PATH
ONEDRIVE_REMOTE=${ONEDRIVE_REMOTE:-""}
ONEDRIVE_PATH=${ONEDRIVE_PATH:-"/DatabaseBackups"}

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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help function
show_help() {
    cat << 'EOF'
====================================================================
DATABASE BACKUP SCRIPT v5.0 - HELP
====================================================================

DESCRIPTION:
  Automated MySQL backup script with multi-storage backend support.
  Supports Git repositories, AWS S3, S3-compatible storage, and OneDrive.

USAGE:
  ./BackupDB.sh [OPTIONS]

OPTIONS:
  -h, --help              Show this help message
  -v, --version           Show version information  
  -t, --test-config       Test configuration without running backups
  -d, --dry-run           Show what would be done without executing

STORAGE BACKENDS:
  git                     Git repository with LFS support (default)
  s3                      AWS S3 or S3-compatible storage
  onedrive                Microsoft OneDrive via rclone

ENVIRONMENT VARIABLES:
  VGX_DB_STORAGE_TYPE     Storage backend: git|s3|onedrive
  VGX_DB_OPATH           Backup directory (default: ~/DBBackup/)
  
  Database Configuration:
  VGX_DB_HOSTS           Database hosts (comma-separated)
  VGX_DB_USERS           Database users (comma-separated)  
  VGX_DB_PASSWORDS       Database passwords (comma-separated)
  
  Git Storage:
  VGX_DB_GIT_REPO        Git repository URL (SSH format)
  
  S3/S3-Compatible Storage:
  AWS_S3_BUCKET          S3 bucket name
  AWS_S3_PREFIX          S3 key prefix (optional)
  AWS_ENDPOINT_URL       S3 endpoint (for S3-compatible services)
  AWS_S3_REGION          S3 region (optional, defaults to us-east-1)
  
  OneDrive Storage:
  ONEDRIVE_REMOTE        rclone remote name
  ONEDRIVE_PATH          OneDrive folder path

AUTHENTICATION SETUP:

  Git Storage:
    1. Generate SSH key: ssh-keygen -t rsa -b 4096 -C "email@example.com"
    2. Add key to GitHub: cat ~/.ssh/id_rsa.pub
    3. Test: ssh -T git@github.com
    4. Set: export VGX_DB_GIT_REPO="git@github.com:user/repo.git"

  AWS S3:
    1. Install AWS CLI: pip install awscli
    2. Set credentials via environment variables:
       - export AWS_ACCESS_KEY_ID="AKIA..."
       - export AWS_SECRET_ACCESS_KEY="wJal..."
    3. Create bucket: aws s3 mb s3://backup-bucket
    4. Set: export AWS_S3_BUCKET="backup-bucket"

  S3-Compatible Storage (Backblaze B2, Wasabi, etc.):
    1. Install AWS CLI: pip install awscli
    2. Set credentials via environment variables:
       - export AWS_ACCESS_KEY_ID="your-access-key"
       - export AWS_SECRET_ACCESS_KEY="your-secret-key"
    3. Set endpoint: export AWS_ENDPOINT_URL="https://s3.us-west-002.backblazeb2.com"
    4. Set bucket: export AWS_S3_BUCKET="your-bucket"

  OneDrive:
    1. Install rclone: curl https://rclone.org/install.sh | sudo bash
    2. Configure: rclone config
       - Choose: "n) New remote"
       - Name: onedrive (or your preferred name)
       - Storage: "Microsoft OneDrive"
       - Option client_id: [Leave blank for default or use your app ID]
       - Option client_secret: [Leave blank for default or use your secret]
       - Option region: global (or your region: us, de, cn)
       - Option config_type: onedrive (personal) or sharepoint (business)
       - Advanced config: No
       - Auto config: Yes (opens browser for authentication)
       - Choose account type when prompted
       - Complete browser authentication
    3. Test: rclone ls onedrive:
    4. Set: export ONEDRIVE_REMOTE="onedrive"
    5. Optional: export ONEDRIVE_PATH="/DatabaseBackups"
  
  OneDrive Business/SharePoint:
    - Use config_type: sharepoint
    - Provide your SharePoint site URL when prompted
    - Authentication works the same way
    - May require app registration for enterprise environments

EXAMPLES:

  # Git storage (default)
  ./BackupDB.sh

  # AWS S3
  export VGX_DB_STORAGE_TYPE="s3"
  export AWS_S3_BUCKET="my-backups"
  ./BackupDB.sh

  # Backblaze B2
  export VGX_DB_STORAGE_TYPE="s3" 
  export AWS_ENDPOINT_URL="https://s3.us-west-002.backblazeb2.com"
  export AWS_S3_BUCKET="my-b2-bucket"
  ./BackupDB.sh

  # Wasabi
  export VGX_DB_STORAGE_TYPE="s3"
  export AWS_ENDPOINT_URL="https://s3.us-central-1.wasabisys.com"
  export AWS_S3_BUCKET="my-wasabi-bucket"
  ./BackupDB.sh

  # OneDrive
  export VGX_DB_STORAGE_TYPE="onedrive"
  export ONEDRIVE_REMOTE="onedrive"
  ./BackupDB.sh

TROUBLESHOOTING:
  
  Test Configuration:
    ./BackupDB.sh --test-config
  
  Common Issues:
    - Missing dependencies: Script auto-installs required packages
    - Auth failures: Check credentials with service-specific test commands
    - Permission errors: Ensure script has execute permissions
  
  Storage-Specific Tests:
    Git:      ssh -T git@github.com
    AWS S3:   aws sts get-caller-identity
    B2/S3:    aws --endpoint-url=$AWS_ENDPOINT_URL s3 ls
    OneDrive: rclone ls onedrive:
  
  OneDrive Troubleshooting:
    List remotes:     rclone listremotes
    Show config:      rclone config show
    Re-authenticate:  rclone config reconnect onedrive
    Test folder:      rclone ls onedrive:/DatabaseBackups
    Create folder:    rclone mkdir onedrive:/DatabaseBackups

SUPPORT:
  Email: support.backupdb@vgx.email
  Documentation: See README.md and script header for detailed setup

====================================================================
EOF
}

# Version function
show_version() {
    echo "Database Backup Script v5.0"
    echo "Copyright (c) 2025 VGX Consulting by Vijendra Malhotra"
    echo "Multi-storage backend support: Git, S3, S3-compatible, OneDrive"
}

# Test configuration function
test_config() {
    echo "======================================================================"
    echo "TESTING CONFIGURATION - NO BACKUPS WILL BE PERFORMED"
    echo "======================================================================"
    
    show_config
    echo
    
    echo "[TEST] Checking dependencies..."
    check_dependencies
    echo
    
    echo "[TEST] Validating storage configuration..."
    if validate_storage_config; then
        logme SUCCESS "Configuration test passed!"
        echo
        echo "[INFO] Ready to perform backups. Run without --test-config to proceed."
    else
        logme ERROR "Configuration test failed!"
        echo
        echo "[INFO] Fix the issues above before running backups."
        exit 1
    fi
}

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
    echo "[CONFIG] Storage Backend: $STORAGE_TYPE"
    echo "[CONFIG] Configuration loaded from:"
    echo "  Storage Type: $([ -n "$VGX_DB_STORAGE_TYPE" ] && echo "VGX_DB_STORAGE_TYPE" || echo "script default") -> $STORAGE_TYPE"
    echo "  Backup Path: $([ -n "$VGX_DB_OPATH" ] && echo "VGX_DB_OPATH" || echo "script default") -> $opath"
    
    # Storage-specific configuration
    case $STORAGE_TYPE in
        "git")
            echo "  Git Repository: $([ -n "$VGX_DB_GIT_REPO" ] && echo "VGX_DB_GIT_REPO" || echo "script default") -> $git_repo"
            ;;
        "s3")
            echo "  S3 Bucket: $([ -n "$AWS_S3_BUCKET" ] && echo "AWS_S3_BUCKET" || echo "not configured") -> $AWS_S3_BUCKET"
            echo "  S3 Prefix: $([ -n "$AWS_S3_PREFIX" ] && echo "AWS_S3_PREFIX" || echo "script default") -> $AWS_S3_PREFIX"
            echo "  S3 Endpoint: $([ -n "$AWS_ENDPOINT_URL" ] && echo "AWS_ENDPOINT_URL" || echo "default (AWS)") -> ${AWS_ENDPOINT_URL:-"https://s3.amazonaws.com"}"
            echo "  S3 Region: $([ -n "$AWS_S3_REGION" ] && echo "AWS_S3_REGION" || echo "script default") -> $AWS_S3_REGION"
            ;;
        "onedrive")
            echo "  OneDrive Remote: $([ -n "$ONEDRIVE_REMOTE" ] && echo "ONEDRIVE_REMOTE" || echo "not configured") -> $ONEDRIVE_REMOTE"
            echo "  OneDrive Path: $([ -n "$ONEDRIVE_PATH" ] && echo "ONEDRIVE_PATH" || echo "script default") -> $ONEDRIVE_PATH"
            ;;
    esac
    
    # Database configuration
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
                "aws") install_cmd="brew install awscli" ;;
                "rclone") install_cmd="brew install rclone" ;;
                *) install_cmd="brew install $dep" ;;
            esac
            ;;
        "apt")
            case $dep in
                "mysql") install_cmd="sudo apt-get update && sudo apt-get install -y mysql-client" ;;
                "git") install_cmd="sudo apt-get update && sudo apt-get install -y git" ;;
                "git-lfs") install_cmd="sudo apt-get update && sudo apt-get install -y git-lfs" ;;
                "aws") install_cmd="sudo apt-get update && sudo apt-get install -y awscli" ;;
                "rclone") install_cmd="sudo apt-get update && sudo apt-get install -y rclone" ;;
                *) install_cmd="sudo apt-get update && sudo apt-get install -y $dep" ;;
            esac
            ;;
        "yum"|"dnf")
            case $dep in
                "mysql") install_cmd="sudo $PACKAGE_MANAGER install -y mysql" ;;
                "git") install_cmd="sudo $PACKAGE_MANAGER install -y git" ;;
                "git-lfs") install_cmd="sudo $PACKAGE_MANAGER install -y git-lfs" ;;
                "aws") install_cmd="sudo $PACKAGE_MANAGER install -y awscli" ;;
                "rclone") install_cmd="sudo $PACKAGE_MANAGER install -y rclone" ;;
                *) install_cmd="sudo $PACKAGE_MANAGER install -y $dep" ;;
            esac
            ;;
        "zypper")
            case $dep in
                "mysql") install_cmd="sudo zypper install -y mysql-client" ;;
                "git") install_cmd="sudo zypper install -y git" ;;
                "git-lfs") install_cmd="sudo zypper install -y git-lfs" ;;
                "aws") install_cmd="sudo zypper install -y awscli" ;;
                "rclone") install_cmd="sudo zypper install -y rclone" ;;
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
                "aws") echo "  brew install awscli" ;;
                "rclone") echo "  brew install rclone" ;;
                *) echo "  brew install $dep" ;;
            esac
            ;;
        "apt")
            case $dep in
                "mysql") echo "  sudo apt-get update && sudo apt-get install mysql-client" ;;
                "git") echo "  sudo apt-get update && sudo apt-get install git" ;;
                "git-lfs") echo "  sudo apt-get update && sudo apt-get install git-lfs" ;;
                "aws") echo "  sudo apt-get update && sudo apt-get install awscli" ;;
                "rclone") echo "  sudo apt-get update && sudo apt-get install rclone" ;;
                *) echo "  sudo apt-get install $dep" ;;
            esac
            ;;
        "yum"|"dnf")
            case $dep in
                "mysql") echo "  sudo $PACKAGE_MANAGER install mysql" ;;
                "git") echo "  sudo $PACKAGE_MANAGER install git" ;;
                "git-lfs") echo "  sudo $PACKAGE_MANAGER install git-lfs" ;;
                "aws") echo "  sudo $PACKAGE_MANAGER install awscli" ;;
                "rclone") echo "  sudo $PACKAGE_MANAGER install rclone" ;;
                *) echo "  sudo $PACKAGE_MANAGER install $dep" ;;
            esac
            ;;
        "zypper")
            case $dep in
                "mysql") echo "  sudo zypper install mysql-client" ;;
                "git") echo "  sudo zypper install git" ;;
                "git-lfs") echo "  sudo zypper install git-lfs" ;;
                "aws") echo "  sudo zypper install awscli" ;;
                "rclone") echo "  sudo zypper install rclone" ;;
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
    local required_commands=("mysql" "mysqldump" "gzip" "gunzip" "find" "diff")
    
    # Add storage-specific dependencies
    case $STORAGE_TYPE in
        "git")
            required_commands+=("git")
            ;;
        "s3")
            required_commands+=("aws")
            ;;
        "onedrive")
            required_commands+=("rclone")
            ;;
    esac
    
    echo "[INFO] Checking system dependencies for storage type: $STORAGE_TYPE"
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
    
    # Check Git LFS separately (only for Git storage)
    if [[ "$STORAGE_TYPE" == "git" ]] && command -v "git" >/dev/null 2>&1; then
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
# STORAGE ABSTRACTION   #
#########################

# Validate storage configuration based on selected storage type
validate_storage_config() {
    local storage_type=${STORAGE_TYPE:-"git"}
    
    case $storage_type in
        "git")
            if [[ -z "$git_repo" ]] || [[ "$git_repo" == "git@github.com:YourUsername/DBBackups.git" ]]; then
                logme ERROR "Git repository URL not configured. Please set git_repo or VGX_DB_GIT_REPO environment variable."
                return 1
            fi
            
            # Test SSH connection to Git host
            if [[ "$git_repo" == *"github.com"* ]]; then
                if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                    logme WARNING "GitHub SSH authentication may not be properly configured."
                    logme WARNING "Please ensure your SSH keys are set up: ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'"
                fi
            fi
            ;;
        "s3")
            if [[ -z "$AWS_S3_BUCKET" ]]; then
                logme ERROR "AWS S3 bucket not configured. Please set AWS_S3_BUCKET environment variable."
                return 1
            fi
            
            if ! command -v aws >/dev/null 2>&1; then
                logme ERROR "AWS CLI not found. Please install it: pip install awscli"
                return 1
            fi
            
            # Test S3 credentials (works for AWS S3 and all S3-compatible services)
            local s3_test_cmd="aws s3 ls"
            if [[ -n "$AWS_ENDPOINT_URL" ]]; then
                s3_test_cmd="aws --endpoint-url=$AWS_ENDPOINT_URL s3 ls"
                logme INFO "Testing S3-compatible storage at: $AWS_ENDPOINT_URL"
            else
                logme INFO "Testing AWS S3 credentials"
            fi
            
            if ! $s3_test_cmd >/dev/null 2>&1; then
                logme ERROR "S3 credentials test failed."
                logme ERROR "Please ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables are set."
                return 1
            fi
            
            # Test S3 bucket access
            local s3_test_cmd="aws s3 ls s3://$AWS_S3_BUCKET"
            if [[ -n "$AWS_ENDPOINT_URL" ]]; then
                s3_test_cmd="aws --endpoint-url=$AWS_ENDPOINT_URL s3 ls s3://$AWS_S3_BUCKET"
            fi
            
            if ! $s3_test_cmd >/dev/null 2>&1; then
                logme WARNING "Cannot access S3 bucket '$AWS_S3_BUCKET'. It may not exist or you may lack permissions."
                if [[ -n "$AWS_ENDPOINT_URL" ]]; then
                    logme INFO "Using S3-compatible endpoint: $AWS_ENDPOINT_URL"
                fi
            fi
            ;;
        "onedrive")
            if [[ -z "$ONEDRIVE_REMOTE" ]]; then
                logme ERROR "OneDrive remote not configured. Please set ONEDRIVE_REMOTE environment variable."
                return 1
            fi
            
            if ! command -v rclone >/dev/null 2>&1; then
                logme ERROR "rclone not found. Please install it from: https://rclone.org/downloads/"
                return 1
            fi
            
            # Test rclone configuration
            if ! rclone listremotes | grep -q "^${ONEDRIVE_REMOTE}:$"; then
                logme ERROR "OneDrive remote '$ONEDRIVE_REMOTE' not configured in rclone."
                logme ERROR "Please configure it: rclone config"
                return 1
            fi
            ;;
        *)
            logme ERROR "Unsupported storage type: $storage_type. Supported types: git, s3, onedrive"
            return 1
            ;;
    esac
    
    return 0
}

# Upload backups to Git repository (refactored existing logic)
upload_to_git() {
    local backup_path="$1"
    
    logme INFO "Uploading backups to Git repository..."
    
    # Step 1: Ensure Git repository exists or clone it
    if [ ! -d "$backup_path/.git" ]; then
        logme INFO "Git repository not found. Cloning from remote..."
        mkdir -p "$backup_path"
        git clone "$git_repo" "$backup_path"
        if [ $? -ne 0 ]; then
            logme ERROR "Failed to clone Git repository. Please check your Git URL and SSH keys."
            return 1
        fi
    fi

    # Step 2: Update local repository
    logme INFO "Updating local Git repository..."
    cd "$backup_path" || { logme ERROR "Failed to change to backup directory '$backup_path'"; return 1; }
    if ! git pull; then
        logme WARNING "Failed to pull from remote repository. Continuing with local state..."
    fi

    # Step 3: Manage Git LFS tracking for large backup files
    logme INFO "Checking for large backup files and managing LFS tracking..."
    
    # Find files larger than 100MB and add LFS patterns for their databases
    find "$backup_path" -name "*.gz" -size +100M 2>/dev/null | while read -r file; do
        db_name=$(basename "$(dirname "$file")")
        logme INFO "Large backup detected: $file"
        add_lfs_pattern "$db_name/*.gz"
    done

    # Add and commit .gitattributes first if it exists (required for LFS to work)
    if [[ -f "$backup_path/.gitattributes" ]]; then
        git add .gitattributes 2>/dev/null
        if git diff --cached --quiet; then
            logme INFO ".gitattributes unchanged, no commit needed."
        else
            logme INFO "Committing .gitattributes for LFS tracking..."
            git commit -m "Update LFS tracking patterns"
        fi
    fi

    # Step 4: Commit and push changes to Git repository
    if git status --porcelain | grep -q '.'; then
        logme INFO "Changes detected. Committing and pushing to GitHub..."

        git add .
        git commit -m "Database backup update: $today"
        
        # Get the current branch name
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        git push origin "$current_branch"
        if [ $? -ne 0 ]; then
            logme ERROR "Failed to push to Git repository. Please check your connectivity and permissions."
            return 1
        fi
        
        logme SUCCESS "Successfully uploaded backups to Git repository."
    else
        logme INFO "No changes detected. Skipping Git push."
    fi
    
    return 0
}

# Upload backups to AWS S3 or S3-compatible storage
upload_to_s3() {
    local backup_path="$1"
    local s3_bucket="${AWS_S3_BUCKET}"
    local s3_prefix="${AWS_S3_PREFIX:-backups/}"
    local endpoint_url="${AWS_ENDPOINT_URL}"
    
    if [[ -n "$endpoint_url" ]]; then
        logme INFO "Uploading backups to S3-compatible storage: $endpoint_url"
    else
        logme INFO "Uploading backups to AWS S3..."
    fi
    
    # Ensure prefix ends with /
    [[ "$s3_prefix" != */ ]] && s3_prefix="${s3_prefix}/"
    
    # Upload all .gz files with date-based organization
    local upload_count=0
    local error_count=0
    
    find "$backup_path" -name "*.gz" -type f | while read -r file; do
        local relative_path="${file#$backup_path/}"
        local s3_key="${s3_prefix}${today}/${relative_path}"
        
        logme INFO "Uploading: $relative_path -> s3://$s3_bucket/$s3_key"
        
        # Build AWS command with optional endpoint URL
        local aws_cp_cmd="aws s3 cp \"$file\" \"s3://$s3_bucket/$s3_key\""
        if [[ -n "$endpoint_url" ]]; then
            aws_cp_cmd="aws --endpoint-url=$endpoint_url s3 cp \"$file\" \"s3://$s3_bucket/$s3_key\""
        else
            # Only use storage class for AWS S3 (not all S3-compatible services support it)
            aws_cp_cmd="$aws_cp_cmd --storage-class STANDARD_IA"
        fi
        
        if eval $aws_cp_cmd; then
            ((upload_count++))
            logme SUCCESS "Uploaded: $relative_path"
        else
            ((error_count++))
            logme ERROR "Failed to upload: $relative_path"
        fi
    done
    
    # Cleanup old backups in S3 (older than 30 days)
    local cutoff_date
    if [[ "$OS_TYPE" == "macos" ]]; then
        cutoff_date=$(date -v -30d +%Y%m%d)
    else
        cutoff_date=$(date --date="30 days ago" +%Y%m%d)
    fi
    
    logme INFO "Cleaning up S3 backups older than $cutoff_date..."
    
    # Build AWS ls command with optional endpoint URL
    local aws_ls_cmd="aws s3 ls \"s3://$s3_bucket/$s3_prefix\" --recursive"
    if [[ -n "$endpoint_url" ]]; then
        aws_ls_cmd="aws --endpoint-url=$endpoint_url s3 ls \"s3://$s3_bucket/$s3_prefix\" --recursive"
    fi
    
    eval $aws_ls_cmd | while read -r line; do
        local s3_date=$(echo "$line" | awk '{print $1}' | tr -d '-')
        local s3_key=$(echo "$line" | awk '{print $4}')
        
        if [[ "$s3_date" -lt "$cutoff_date" ]]; then
            logme INFO "Deleting old backup: s3://$s3_bucket/$s3_key"
            
            # Build AWS rm command with optional endpoint URL
            local aws_rm_cmd="aws s3 rm \"s3://$s3_bucket/$s3_key\""
            if [[ -n "$endpoint_url" ]]; then
                aws_rm_cmd="aws --endpoint-url=$endpoint_url s3 rm \"s3://$s3_bucket/$s3_key\""
            fi
            
            eval $aws_rm_cmd
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        logme SUCCESS "Successfully uploaded all backups to S3."
        return 0
    else
        logme ERROR "Some uploads failed. Check AWS credentials and permissions."
        return 1
    fi
}

# Upload backups to OneDrive via rclone
upload_to_onedrive() {
    local backup_path="$1"
    local remote_name="${ONEDRIVE_REMOTE}"
    local remote_path="${ONEDRIVE_PATH:-/DatabaseBackups}"
    
    logme INFO "Uploading backups to OneDrive..."
    
    # Ensure remote path starts with /
    [[ "$remote_path" != /* ]] && remote_path="/$remote_path"
    
    # Create date-based directory structure
    local target_path="${remote_name}:${remote_path}/${today}"
    
    # Upload all .gz files
    local upload_count=0
    local error_count=0
    
    find "$backup_path" -name "*.gz" -type f | while read -r file; do
        local relative_path="${file#$backup_path/}"
        local target_file="${target_path}/${relative_path}"
        
        # Create directory structure if needed
        local target_dir=$(dirname "$target_file")
        rclone mkdir "$target_dir" 2>/dev/null || true
        
        logme INFO "Uploading: $relative_path -> $target_file"
        
        if rclone copy "$file" "$target_dir" --progress; then
            ((upload_count++))
            logme SUCCESS "Uploaded: $relative_path"
        else
            ((error_count++))
            logme ERROR "Failed to upload: $relative_path"
        fi
    done
    
    # Cleanup old backups in OneDrive (older than 30 days)
    local cutoff_date
    if [[ "$OS_TYPE" == "macos" ]]; then
        cutoff_date=$(date -v -30d +%Y%m%d)
    else
        cutoff_date=$(date --date="30 days ago" +%Y%m%d)
    fi
    
    logme INFO "Cleaning up OneDrive backups older than $cutoff_date..."
    rclone lsd "${remote_name}:${remote_path}" | while read -r line; do
        local dir_date=$(echo "$line" | awk '{print $5}')
        
        if [[ "$dir_date" =~ ^[0-9]{8}$ ]] && [[ "$dir_date" -lt "$cutoff_date" ]]; then
            logme INFO "Deleting old backup directory: ${remote_name}:${remote_path}/${dir_date}"
            rclone purge "${remote_name}:${remote_path}/${dir_date}"
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        logme SUCCESS "Successfully uploaded all backups to OneDrive."
        return 0
    else
        logme ERROR "Some uploads failed. Check rclone configuration and connectivity."
        return 1
    fi
}

# Main orchestrator function for backup uploads
upload_backups() {
    local backup_path="$1"
    local storage_type="${STORAGE_TYPE:-git}"
    
    logme INFO "Starting backup upload process using storage type: $storage_type"
    
    # Validate storage configuration
    if ! validate_storage_config; then
        logme ERROR "Storage configuration validation failed."
        return 1
    fi
    
    # Upload based on storage type
    case $storage_type in
        "git")
            upload_to_git "$backup_path"
            ;;
        "s3")
            upload_to_s3 "$backup_path"
            ;;
        "onedrive")
            upload_to_onedrive "$backup_path"
            ;;
        *)
            logme ERROR "Unsupported storage type: $storage_type"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        logme SUCCESS "Backup upload completed successfully."
    else
        logme ERROR "Backup upload failed."
    fi
    
    return $result
}

#########################
# COMMAND LINE PARSING  #
#########################

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -t|--test-config)
            test_config
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

#########################
# SCRIPT FUNCTIONALITY  #
#########################

echo "======================================================================"
echo "DATABASE BACKUP SCRIPT v5.0"
echo "Copyright (c) 2025 VGX Consulting https://vgx.digital"
echo
echo "Starting backup process at $(date)"
echo "======================================================================"

# Step 0a: Show configuration
show_config
echo

# Step 0b: Check system dependencies
check_dependencies

# Step 1: Initialize storage backend and create backup directory
logme INFO "Initializing storage backend: $STORAGE_TYPE"
mkdir -p "$opath"

# For Git storage, ensure repository exists
if [[ "$STORAGE_TYPE" == "git" ]]; then
    if [ ! -d "$opath/.git" ]; then
        echo "[INFO] Git repository not found. Cloning from remote..."
        git clone "$git_repo" "$opath"
        if [ $? -ne 0 ]; then
            logme ERROR "Failed to clone Git repository. Please check your Git URL and SSH keys."
            exit 1
        fi
    fi
    
    # Update local repository
    echo "[INFO] Updating local Git repository..."
    cd "$opath" || { logme ERROR "Failed to change to backup directory '$opath'"; exit 1; }
    if ! git pull; then
        logme WARNING "Failed to pull from remote repository. Continuing with local state..."
    fi
fi

# Step 2: Storage-aware cleanup of old backups
if [[ "$STORAGE_TYPE" == "git" ]]; then
    # For Git: Keep local files, let Git manage versions
    echo "[INFO] Deleting local backups older than 5 days..."
    find "$opath" -name "*.sql.gz" -mtime +5 -exec rm {} \;
    if [[ -d "$opath/.git" ]]; then
        cd "$opath" && git rm $(git ls-files --deleted) 2>/dev/null || true
    fi
else
    # For object storage: Keep local files for comparison, remote storage manages retention
    logme INFO "Object storage mode: Local files will be cleaned after successful upload"
fi

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

# Step 4.5: Upload backups using configured storage backend
logme INFO "Starting backup upload process..."
if ! upload_backups "$opath"; then
    logme ERROR "Backup upload failed. Exiting."
    exit 1
fi

# Step 4.6: Post-upload cleanup for object storage
if [[ "$STORAGE_TYPE" != "git" ]]; then
    logme INFO "Cleaning up local backup files after successful upload..."
    find "$opath" -name "*.sql.gz" -mtime +1 -delete
    logme SUCCESS "Local cleanup completed."
fi

echo "======================================================================"
echo "BACKUP PROCESS COMPLETED SUCCESSFULLY at $(date)"
echo " Script by - VGX Consulting. All rights reserved. For support, contact: support.backupdb@vgx.email"
echo "======================================================================"