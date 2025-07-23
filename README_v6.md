# Database Backup Script v6.0 - Simplified

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
export AWS_S3_BUCKET="your-bucket-name"

# For non-AWS services, add endpoint:
export AWS_ENDPOINT_URL="https://s3.us-west-004.backblazeb2.com"  # Backblaze B2
export AWS_ENDPOINT_URL="https://s3.us-central-1.wasabisys.com"   # Wasabi
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
1. Install rclone: `curl https://rclone.org/install.sh | sudo bash`
2. Configure: `rclone config` → Choose Microsoft OneDrive
3. Test: `rclone ls onedrive:`
4. Set: `export ONEDRIVE_REMOTE="onedrive"`

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
aws --endpoint-url=$AWS_ENDPOINT_URL s3 ls  # S3-compatible

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
export AWS_S3_BUCKET="your-bucket"
export AWS_ENDPOINT_URL="https://your-endpoint"
export VGX_DB_HOSTS="db1.com,db2.com"
export VGX_DB_USERS="user1,user2"
export VGX_DB_PASSWORDS="pass1,pass2"
```

Schedule with cron:
```bash
# Daily backup at 2 AM
0 2 * * * source ~/.backup_env && /path/to/BackupDB.sh >> /var/log/backup.log 2>&1
```

## 📊 What's New in v6.0

### 🎯 **Simplified & Optimized**
- **Reduced from 1230 to 400 lines** (67% smaller)
- **Single `aws_cmd()` function** eliminates 6 duplicate endpoint patterns
- **Unified `log()` function** replaces 29 inconsistent error messages
- **Clear error messages** with specific instructions
- **Streamlined validation** - one function per storage type

### 🚀 **Improved Performance**
- **Faster startup** - removed redundant checks
- **Better error handling** - fail fast with clear messages
- **Optimized file operations** - reduced disk I/O

### 📚 **Better Documentation**
- **Built-in help** - `./BackupDB.sh --help`
- **Quick start guide** - get running in minutes
- **Clear examples** - copy-paste configuration

---

**Version:** 6.0  
**Author:** VGX Consulting by Vijendra Malhotra  
**Support:** support.backupdb@vgx.email