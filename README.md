# BackupDB - Database Backup Script v6.7

**Automated MySQL backups with multi-storage backend support, automatic cleanup, and flexible retention policies**

[![Version](https://img.shields.io/badge/version-6.7-blue.svg)](RELEASE_NOTES.md)
[![Storage](https://img.shields.io/badge/storage-Git%20%7C%20S3%20%7C%20OneDrive-green.svg)](#storage-backends)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)](#supported-platforms)

## 📋 Table of Contents
- [Quick Start](#-quick-start)
- [Installation Methods](#-installation-methods)
- [Configuration](#-configuration)
- [Environment Variables](#-environment-variables-reference)
- [Storage Backends](#-storage-backends)
- [Running from Git](#-running-directly-from-git)
- [Automation & Cron](#-automation--cron-jobs)
- [Troubleshooting](#-troubleshooting)
- [What's New](#-whats-new-in-v67)

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

## 📦 Installation Methods

### Method 1: Download & Configure (Recommended)
```bash
# Download the script
wget https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sh
# OR
curl -O https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sh

# Make executable
chmod +x BackupDB.sh

# Download sample configuration
wget https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sample.env
cp BackupDB.sample.env BackupDB.env

# Edit configuration
nano BackupDB.env  # or vim, code, etc.

# Test configuration
./BackupDB.sh --test
```

### Method 2: Git Clone
```bash
git clone https://github.com/VGXConsulting/BackupDB.git
cd BackupDB
cp BackupDB.sample.env BackupDB.env
nano BackupDB.env  # Configure your settings
./BackupDB.sh --test
```

## ⚙️ Configuration

### Using Environment Files (Recommended)
The script automatically loads configuration from `.env` files in this priority order:
1. `./BackupDB.env` (current directory)
2. `$HOME/BackupDB.env` (home directory)

```bash
# Create your configuration file
cp BackupDB.sample.env BackupDB.env
# Edit with your settings
nano BackupDB.env
```

### Using Environment Variables
```bash
# Export variables directly
export VGX_DB_STORAGE_TYPE="s3"
export VGX_DB_HOSTS="db1.example.com"
export VGX_DB_USERS="backup_user"
# ... other variables
./BackupDB.sh
```

## 📊 Environment Variables Reference

### Mandatory Variables
| Variable | Description | Example |
|----------|-------------|--------|
| `VGX_DB_HOSTS` | Database hostnames (comma-separated) | `"db1.com,db2.com"` |
| `VGX_DB_USERS` | Database usernames (comma-separated) | `"user1,user2"` |
| `VGX_DB_PASSWORDS` | Database passwords (comma-separated) | `"pass1,pass2"` |

### Storage-Specific Mandatory Variables

#### For Git Storage (`VGX_DB_STORAGE_TYPE="git"`)
| Variable | Description | Example |
|----------|-------------|--------|
| `VGX_DB_GIT_REPO` | Git repository URL | `"git@github.com:user/repo.git"` |

#### For S3 Storage (`VGX_DB_STORAGE_TYPE="s3"`)
| Variable | Description | Example |
|----------|-------------|--------|
| `AWS_ACCESS_KEY_ID` | S3 access key | `"AKIAEXAMPLE"` |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key | `"secretkey123"` |
| `VGX_DB_S3_BUCKET` | S3 bucket name | `"my-backups"` |
| `VGX_DB_S3_ENDPOINT_URL` | S3 endpoint (for non-AWS) | `"https://s3.backblaze.com"` |

#### For OneDrive Storage (`VGX_DB_STORAGE_TYPE="onedrive"`)
| Variable | Description | Example |
|----------|-------------|--------|
| `ONEDRIVE_REMOTE` | rclone remote name | `"onedrive"` |

### Optional Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `VGX_DB_STORAGE_TYPE` | `"git"` | Storage backend: git, s3, onedrive |
| `VGX_DB_OPATH` | `"$HOME/DBBackup/"` | Local backup directory |
| `VGX_DB_PORTS` | `"3306"` | Database ports (comma-separated) |
| `VGX_DB_DELETE_LOCAL_BACKUPS` | `"true"` | Delete local files after upload |
| `VGX_DB_INCREMENTAL_BACKUPS` | `"true"` | Skip unchanged databases (incremental backups) |
| `VGX_DB_GIT_RETENTION_DAYS` | `"-1"` | Git backup retention (-1=never delete) |
| `VGX_DB_S3_PREFIX` | `"backups/"` | S3 folder prefix |
| `VGX_DB_S3_REGION` | `"us-east-1"` | S3 region |
| `ONEDRIVE_PATH` | `"/DatabaseBackups"` | OneDrive folder path |

## 🗄️ Storage Backends

### 1. Git Storage (Default)
```bash
export VGX_DB_GIT_REPO="git@github.com:username/backup-repo.git"
```

### 2. S3-Compatible Storage (AWS S3, Backblaze B2, Wasabi, etc.)
```bash
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export VGX_DB_S3_BUCKET="your-bucket-name"

# For non-AWS services, add endpoint:
export VGX_DB_S3_ENDPOINT_URL="https://s3.us-west-004.backblazeb2.com"  # Backblaze B2
export VGX_DB_S3_ENDPOINT_URL="https://s3.us-central-1.wasabisys.com"   # Wasabi
```

### 3. OneDrive Storage
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

## 🌐 Running Directly from Git

### One-liner Download & Run
```bash
# Download, configure, and run in one go
curl -s https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sh | bash -s -- --help

# Or with wget
wget -q -O - https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sh | bash -s -- --help
```

### Download & Configure
```bash
# Download script and sample config
curl -O https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sh
curl -O https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sample.env
chmod +x BackupDB.sh

# Configure
cp BackupDB.sample.env BackupDB.env
nano BackupDB.env  # Edit your settings

# Test and run
./BackupDB.sh --test
./BackupDB.sh
```

### Use with Environment Variables
```bash
# Set variables and run directly
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ACCESS_KEY_ID="your-key"
export VGX_DB_S3_BUCKET="your-bucket"
# ... other variables ...
curl -s https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sh | bash
```

## ⏰ Automation & Cron Jobs

### Method 1: Using BackupDB.env file
```bash
# Create system-wide config
sudo mkdir -p /etc/backupdb
sudo cp BackupDB.env /etc/backupdb/
sudo chmod 600 /etc/backupdb/BackupDB.env

# Install script
sudo cp BackupDB.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/BackupDB.sh

# Add to cron
crontab -e
```

Add to crontab:
```bash
# Daily backup at 2:00 AM
0 2 * * * cd /etc/backupdb && /usr/local/bin/BackupDB.sh >> /var/log/backup.log 2>&1

# Weekly backup on Sundays at 3:00 AM
0 3 * * 0 cd /etc/backupdb && /usr/local/bin/BackupDB.sh >> /var/log/backup-weekly.log 2>&1

# Hourly backup during business hours (9 AM - 5 PM, Mon-Fri)
0 9-17 * * 1-5 cd /etc/backupdb && /usr/local/bin/BackupDB.sh >> /var/log/backup-hourly.log 2>&1
```

### Method 2: Using Environment Variables in Cron
```bash
# Edit crontab
crontab -e
```

Add environment variables and job:
```bash
# Environment variables
VGX_DB_STORAGE_TYPE=s3
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
VGX_DB_S3_BUCKET=production-backups
VGX_DB_S3_ENDPOINT_URL=https://s3.us-west-004.backblazeb2.com
VGX_DB_HOSTS=prod-db1.example.com,prod-db2.example.com
VGX_DB_USERS=backup_svc,backup_svc
VGX_DB_PASSWORDS=secure_pass1,secure_pass2
VGX_DB_DELETE_LOCAL_BACKUPS=true

# Daily backup at 2 AM with email notifications
MAILTO=admin@example.com
0 2 * * * /usr/local/bin/BackupDB.sh
```

### Method 3: Direct from GitHub (No Installation Required)
```bash
# Edit crontab
crontab -e
```

Add environment variables and run script directly from GitHub:
```bash
# Environment variables
VGX_DB_STORAGE_TYPE=s3
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
VGX_DB_S3_BUCKET=production-backups
VGX_DB_HOSTS=db1.example.com
VGX_DB_USERS=backup_user
VGX_DB_PASSWORDS=secure_password

# Daily backup at 2 AM - runs directly from GitHub
MAILTO=admin@example.com
0 2 * * * curl -s https://raw.githubusercontent.com/VGXConsulting/BackupDB/main/BackupDB.sh | /bin/bash >> /var/log/backup.log 2>&1
```

### Method 3: Systemd Timer (Linux)
```bash
# Create service file
sudo tee /etc/systemd/system/backupdb.service << EOF
[Unit]
Description=BackupDB Database Backup Service
Wants=backupdb.timer

[Service]
Type=oneshot
WorkingDirectory=/etc/backupdb
EnvironmentFile=/etc/backupdb/BackupDB.env
ExecStart=/usr/local/bin/BackupDB.sh
User=backup
Group=backup
EOF

# Create timer file
sudo tee /etc/systemd/system/backupdb.timer << EOF
[Unit]
Description=Run BackupDB Daily
Requires=backupdb.service

[Timer]
OnCalendar=daily
RandomizedDelaySec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable backupdb.timer
sudo systemctl start backupdb.timer

# Check status
sudo systemctl status backupdb.timer
```

### Cron Examples for Different Scenarios

```bash
# Production: Daily at 2 AM with retention
0 2 * * * cd /etc/backupdb && VGX_DB_GIT_RETENTION_DAYS=30 /usr/local/bin/BackupDB.sh

# Development: Every 4 hours, keep 7 days
0 */4 * * * cd /etc/backupdb && VGX_DB_GIT_RETENTION_DAYS=7 /usr/local/bin/BackupDB.sh

# Critical systems: Every 2 hours with multiple storage
0 */2 * * * cd /etc/backupdb && VGX_DB_STORAGE_TYPE=git /usr/local/bin/BackupDB.sh
30 */2 * * * cd /etc/backupdb && VGX_DB_STORAGE_TYPE=s3 /usr/local/bin/BackupDB.sh

# Weekend full backup with extended retention
0 3 * * 6,0 cd /etc/backupdb && VGX_DB_GIT_RETENTION_DAYS=90 /usr/local/bin/BackupDB.sh
```

### Monitoring Cron Jobs

```bash
# View cron logs
sudo tail -f /var/log/cron

# View backup logs
tail -f /var/log/backup.log

# Check last backup status
grep "BACKUP COMPLETED" /var/log/backup.log | tail -1

# Monitor disk usage
df -h ~/DBBackup/

# Check for failed backups
grep "ERROR\|FAILED" /var/log/backup.log | tail -10
```

## 🆕 What's New in v6.7

[![Release Notes](https://img.shields.io/badge/📋-Release%20Notes-blue)](RELEASE_NOTES.md)

### 🧹 **Enhanced Cleanup Features**
- **Default Cleanup Enabled**: Local backup cleanup now defaults to `true`
- **Git Retention Control**: New `VGX_DB_GIT_RETENTION_DAYS` variable
- **Flexible Retention**: Set days to keep, 0 to delete all, -1 to never delete

### 📈 **Incremental Backup Support**
- **Smart Backups**: Skip unchanged databases automatically
- **Storage Savings**: Only backup databases that have changed since yesterday
- **New Variable**: `VGX_DB_INCREMENTAL_BACKUPS` (default: `true`)

### ⚠️ **Breaking Changes**
- Local backup cleanup now enabled by default - set `VGX_DB_DELETE_LOCAL_BACKUPS="false"` to disable

### 📚 **Complete Release History**
For detailed version history, features, and migration guides, see **[RELEASE_NOTES.md](RELEASE_NOTES.md)**

---

## 📋 Supported Platforms
- **macOS** (Homebrew package management)
- **Ubuntu/Debian** (APT package management)  
- **RHEL/CentOS/Fedora** (YUM/DNF package management)
- **openSUSE** (Zypper package management)

## 🤝 Contributing
See [RELEASE_NOTES.md](RELEASE_NOTES.md) for version history and [BackupDB.sample.env](BackupDB.sample.env) for configuration examples.

---

**Version:** 6.7 (August 2025)  
**Author:** VGX Consulting by Vijendra Malhotra  
**Repository:** https://github.com/VGXConsulting/BackupDB  
**Support:** support.backupdb@vgx.email
