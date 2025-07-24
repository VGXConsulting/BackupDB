# Database Backup Script v6.4 - Simplified

**Automated MySQL backups with multi-storage backend support**

## 🚀 Quick Start

1. **Choose storage type:**
   ```bash
   export VGX_DB_STORAGE_TYPE="git"     # Default
   export VGX_DB_STORAGE_TYPE="s3"      # S3-compatible storage  
   export VGX_DB_STORAGE_TYPE="onedrive" # OneDrive
   ```

2. **Configure credentials** (see examples below)

3. **Set database connection:**
   ```bash
   export VGX_DB_HOSTS="db1.com,db2.com"
   export VGX_DB_USERS="user1,user2" 
   export VGX_DB_PASSWORDS="pass1,pass2"
   ```

4. **Test and run:**
   ```bash
   ./BackupDB.sh --test    # Test configuration
   ./BackupDB.sh           # Run backup
   ```

## 📋 Storage Setup Examples

### Git Storage (Default)
```bash
export VGX_DB_GIT_REPO="git@github.com:username/backup-repo.git"
```

### S3-Compatible Storage (AWS S3, Backblaze B2, Wasabi, etc.)
```bash
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export VGX_DB_S3_BUCKET="your-bucket-name"

# For non-AWS services, add endpoint:
export VGX_DB_S3_ENDPOINT_URL="https://s3.us-west-004.backblazeb2.com"  # Backblaze B2
export VGX_DB_S3_ENDPOINT_URL="https://s3.us-central-1.wasabisys.com"   # Wasabi
```

### OneDrive Storage
```bash
export VGX_DB_STORAGE_TYPE="onedrive"
export ONEDRIVE_REMOTE="onedrive"  # From: rclone config
```

## 🔧 Setup Instructions

### Prerequisites
- **All storage types:** MySQL client tools (`mysql`, `mysqldump`)
- **Git storage:** Git with SSH keys configured
- **S3 storage:** AWS CLI installed (`brew install awscli`)
- **OneDrive storage:** rclone installed and configured

### Git Setup
1. Generate SSH key: `ssh-keygen -t rsa -b 4096`
2. Add to GitHub/GitLab
3. Create private repository
4. Set: `export VGX_DB_GIT_REPO="git@github.com:user/repo.git"`

### S3/S3-Compatible Setup
1. Install AWS CLI: `brew install awscli` (macOS) or `pip install awscli`
2. Get credentials from your service:
   - **AWS S3:** IAM Access Keys
   - **Backblaze B2:** Application Keys (keyID + applicationKey)
   - **Wasabi:** Access Keys
3. Export credentials and endpoint (see examples above)

### OneDrive Setup

#### Step 1: Install rclone
```bash
# macOS
brew install rclone

# Linux/Unix
curl https://rclone.org/install.sh | sudo bash
```

#### Step 2: Configure OneDrive
```bash
rclone config
```

**Follow the interactive prompts:**
1. Choose: `n` (New remote)
2. **Name:** `onedrive` (or your preferred name)
3. **Storage:** Choose Microsoft OneDrive (usually option `26`)
4. **Client ID:** Leave blank (press Enter)
5. **Client Secret:** Leave blank (press Enter)
6. **Region:** Choose your region (usually `1` for global)
7. **Advanced config:** `n` (No)
8. **Auto config:** `y` (Yes) - opens browser for authentication

**Browser Authentication:**
- Sign in to your Microsoft account
- Grant permissions to rclone
- Return to terminal when complete

#### Step 3: Test Connection
```bash
# List configured remotes
rclone listremotes

# Test connection (should show your OneDrive files)
rclone ls onedrive:

# Create backup folder
rclone mkdir onedrive:/DatabaseBackups
```

#### Step 4: Set Environment Variables
```bash
export VGX_DB_STORAGE_TYPE="onedrive"
export ONEDRIVE_REMOTE="onedrive"  # Must match your rclone remote name
export ONEDRIVE_PATH="/DatabaseBackups"  # Optional: folder for backups
```

#### Step 5: Test Script Configuration
```bash
./BackupDB.sh --test
```

## 🎯 Usage

```bash
# Basic usage
./BackupDB.sh

# Test configuration first
./BackupDB.sh --test

# See what would be done
./BackupDB.sh --dry-run

# Get help
./BackupDB.sh --help

# Specific storage type
VGX_DB_STORAGE_TYPE=s3 ./BackupDB.sh
```

## 📁 File Organization

### Git Storage
```
/backup-directory/
├── .git/
├── database1/
│   ├── 20250722_database1.sql.gz
│   └── 20250721_database1.sql.gz
└── database2/
    └── 20250722_database2.sql.gz
```

### S3/OneDrive Storage
```
bucket-or-folder/
├── backups/20250722/
│   ├── database1/20250722_database1.sql.gz
│   └── database2/20250722_database2.sql.gz
└── backups/20250721/
    └── database1/20250721_database1.sql.gz
```

## 🔍 Troubleshooting

### Test Your Setup
```bash
# Test storage connection
./BackupDB.sh --test

# For S3 storage:
aws s3 ls  # AWS S3
aws --endpoint-url=$VGX_DB_S3_ENDPOINT_URL s3 ls  # S3-compatible

# For OneDrive:
rclone ls onedrive:

# For Git:
ssh -T git@github.com
```

### Common Issues

**"Command not found" errors:**
- Install missing tools: `brew install awscli` or `pip install awscli`
- For OneDrive: Install rclone from https://rclone.org

**"Connection failed" errors:**
- Check credentials are exported correctly
- For S3: Verify endpoint URL is correct
- For Git: Check SSH keys with `ssh -T git@github.com`

**"Permission denied" errors:**
- Make script executable: `chmod +x BackupDB.sh`
- Check database connection permissions

## 🚀 Automation

Create environment file:
```bash
# ~/.backup_env
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export VGX_DB_S3_BUCKET="your-bucket"
export VGX_DB_S3_ENDPOINT_URL="https://your-endpoint"
export VGX_DB_HOSTS="db1.com,db2.com"
export VGX_DB_USERS="user1,user2"
export VGX_DB_PASSWORDS="pass1,pass2"
```

Schedule with cron:
```bash
# Daily backup at 2 AM
0 2 * * * source ~/.backup_env && /path/to/BackupDB.sh >> /var/log/backup.log 2>&1
```

## 📊 What's New in v6.4

### 🎯 **Major Fixes & Optimizations**
- **Fixed AWS CLI Quoting Issues** - resolved argument parsing errors
- **Optimized S3 Uploads** - single recursive command instead of file-by-file
- **Consistent Environment Variables** - all script vars use `VGX_DB_` prefix
- **Automatic Version Checking** - checks GitHub for updates on startup
- **Improved Error Handling** - visible AWS commands for debugging

### 🔧 **Technical Improvements**
- **Conditional Connection Testing** - S3/OneDrive tests only with `--test` flag
- **Recursive S3 Upload** - `aws s3 cp . target --recursive` for speed
- **Directory Structure Preserved** - maintains `<dbname>/<backup>` in S3
- **Non-blocking Update Checks** - doesn't slow down script startup

### 📚 **Environment Variable Consistency**
- **AWS Credentials** - keep standard `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY`
- **All Other S3 Variables** - use `VGX_DB_S3_*` prefix for consistency
- **Clear Documentation** - updated help and examples with correct variable names

---

**Version:** 6.4  
**Author:** VGX Consulting by Vijendra Malhotra  
**Support:** support.backupdb@vgx.email