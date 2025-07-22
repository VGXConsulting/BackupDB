# Database Backup Script with Multi-Storage Backend Support

## Overview
This script automates MySQL database backups for multiple database hosts, compresses the backups, and supports multiple storage backends including Git repositories, AWS S3, and Microsoft OneDrive. It features intelligent backup detection and only uploads new backups when changes are detected from the previous day.

**Version:** 5.0  
**Last Modified:** July 22, 2025  
**Created by:** VGX Consulting by Vijendra Malhotra

## 🚀 New in Version 5.0: Multi-Storage Backend Support

Choose from multiple storage backends:
- **Git Repository** - Version-controlled storage with Git LFS support
- **AWS S3** - Cloud object storage with automated retention
- **S3-Compatible Storage** - Backblaze B2, Wasabi, DigitalOcean Spaces, MinIO, etc.
- **Microsoft OneDrive** - Personal/business cloud storage via rclone

## Features

- **Multi-Storage Backends**: Git, AWS S3, S3-compatible storage, and Microsoft OneDrive support
- **Smart Dependencies**: Only installs required packages based on storage type
- **Intelligent Backup Detection**: Only uploads when changes are detected
- **Automated Retention**: Configurable cleanup policies for each storage type
- **Cross-Platform**: Linux, macOS, and Windows (WSL) support
- **Environment Variables**: Secure configuration without hardcoded credentials
- **Database Support**: MySQL with system database exclusion
- **Compression**: Automatic gzip compression to save storage space

## Prerequisites

### Core Requirements
- MySQL Client tools (`mysql` and `mysqldump` commands)
- Bash shell environment

### Storage-Specific Requirements

#### Git Storage
- Git installed and configured
- SSH keys set up for Git authentication
- Private repository created for backups

#### AWS S3 Storage  
- AWS CLI installed
- AWS credentials configured
- S3 bucket created with appropriate permissions

#### S3-Compatible Storage (Backblaze B2, Wasabi, etc.)
- AWS CLI installed  
- Storage service credentials configured
- Bucket created on your chosen service
- Endpoint URL for your service

#### OneDrive Storage
- rclone installed and configured
- OneDrive remote authenticated
- OneDrive folder access permissions

## Installation

1. **Download the script**:
   ```bash
   curl -O https://raw.githubusercontent.com/username/repo/main/BackupDB.sh
   ```

2. **Make executable**:
   ```bash
   chmod +x BackupDB.sh
   ```

3. **Configure storage backend** (see Configuration section below)

## Configuration

The script uses environment variables for secure configuration. Choose your storage backend and set the appropriate variables:

### 1. Choose Storage Backend

```bash
export VGX_DB_STORAGE_TYPE="git"        # Default
export VGX_DB_STORAGE_TYPE="s3"         # AWS S3 or S3-compatible
export VGX_DB_STORAGE_TYPE="onedrive"   # Microsoft OneDrive
```

### 2. Storage-Specific Configuration

#### Git Storage Setup
```bash
# Create SSH key (if not exists)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Add to GitHub (copy public key)
cat ~/.ssh/id_rsa.pub

# Test connection
ssh -T git@github.com

# Configure repository
export VGX_DB_GIT_REPO="git@github.com:username/your-backup-repo.git"
```

#### AWS S3 Storage Setup
```bash
# Install and configure AWS CLI
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

# Create S3 bucket
aws s3 mb s3://your-backup-bucket

# Configure script variables
export AWS_S3_BUCKET="your-backup-bucket"
export AWS_S3_PREFIX="database-backups/"  # Optional
```

#### S3-Compatible Storage Setup (Backblaze B2, Wasabi, etc.)

**Backblaze B2:**
```bash
# Install AWS CLI
pip install awscli

# Configure with B2 credentials
aws configure
# Access Key ID: [Your B2 keyID]
# Secret Access Key: [Your B2 applicationKey]  
# Region: us-west-002 (or your B2 region)
# Output: json

# Configure for B2
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ENDPOINT_URL="https://s3.us-west-002.backblazeb2.com"
export AWS_S3_REGION="us-west-002"
export AWS_S3_BUCKET="your-b2-bucket"
```

**Wasabi Hot Cloud Storage:**
```bash
# Configure with Wasabi credentials
aws configure
# Access Key ID: [Your Wasabi Access Key]
# Secret Access Key: [Your Wasabi Secret Key]
# Region: us-central-1 (or your Wasabi region)

# Configure for Wasabi
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ENDPOINT_URL="https://s3.us-central-1.wasabisys.com"
export AWS_S3_REGION="us-central-1"  
export AWS_S3_BUCKET="your-wasabi-bucket"
```

**DigitalOcean Spaces:**
```bash
# Configure with DO Spaces credentials
aws configure
# Access Key ID: [Your Spaces Access Key]
# Secret Access Key: [Your Spaces Secret Key]

# Configure for DO Spaces
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ENDPOINT_URL="https://nyc3.digitaloceanspaces.com"
export AWS_S3_REGION="nyc3"
export AWS_S3_BUCKET="your-spaces-bucket"
```

#### OneDrive Storage Setup

**Prerequisites:**
- Microsoft account (personal or business)
- Browser access for authentication
- Optional: Custom app registration for enterprise environments

**Step-by-Step Setup:**

```bash
# 1. Install rclone
curl https://rclone.org/install.sh | sudo bash

# 2. Configure OneDrive remote
rclone config
```

**During rclone config, follow these steps:**

1. **Choose**: `n) New remote`
2. **Name**: Enter `onedrive` (or your preferred remote name)
3. **Storage**: Choose `Microsoft OneDrive`
4. **Client ID**: Leave blank (uses rclone's default) or enter your custom app ID
5. **Client Secret**: Leave blank (uses rclone's default) or enter your custom secret
6. **Region**: Choose your region:
   - `global` - Global (most common)
   - `us` - US Government 
   - `de` - Germany
   - `cn` - China (21Vianet)
7. **Config Type**: Choose based on your account:
   - `onedrive` - Personal OneDrive account
   - `sharepoint` - Business/SharePoint account
8. **Advanced config**: Choose `n) No`
9. **Auto config**: Choose `y) Yes` (opens browser for authentication)

**Authentication Process:**
1. Browser opens automatically to Microsoft login page
2. Sign in with your Microsoft account
3. Grant permissions to rclone
4. Return to terminal when prompted
5. Choose your account type if multiple options appear
6. Configuration complete!

**For Business/SharePoint Accounts:**
- Choose `sharepoint` as config type
- Provide your SharePoint site URL when prompted: `https://yourcompany.sharepoint.com/sites/yoursite`
- Complete the same browser authentication flow
- May require admin approval in enterprise environments

**Test Configuration:**
```bash
# Test connection
rclone ls onedrive:

# Test with subfolder
rclone ls onedrive:/DatabaseBackups

# Create test folder
rclone mkdir onedrive:/DatabaseBackups

# Configure script variables
export ONEDRIVE_REMOTE="onedrive"
export ONEDRIVE_PATH="/DatabaseBackups"
```

**Enterprise/Custom App Setup (Optional):**

For enhanced security or enterprise requirements, you can register a custom app:

1. **Register App**: Go to [Azure App Registrations](https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps)
2. **Create New Registration**: 
   - Name: "Database Backup Tool"
   - Supported account types: Choose appropriate option
   - Redirect URI: `http://localhost:53682`
3. **Get Credentials**:
   - Copy Application (client) ID
   - Create client secret in "Certificates & secrets"
4. **Configure Permissions**:
   - Add API permissions for Microsoft Graph
   - Add `Files.ReadWrite.All` permission
   - Grant admin consent if required
5. **Use in rclone**: Enter your client ID and secret during configuration

**Advanced Configuration:**
```bash
# For headless/server setup (no browser)
rclone config
# Choose "n) No" for auto config
# Follow manual auth flow with auth token
```

### 3. Database Configuration

```bash
# Database connection settings
export VGX_DB_HOSTS="db1.example.com,db2.example.com"
export VGX_DB_USERS="backup_user1,backup_user2"
export VGX_DB_PASSWORDS="secure_pass1,secure_pass2"
export VGX_DB_OPATH="/home/user/backups"  # Optional, defaults to ~/DBBackup/
```

### 4. Environment File for Automation

Create `/home/user/.backup_env`:
```bash
#!/bin/bash
export VGX_DB_STORAGE_TYPE="s3"
export AWS_S3_BUCKET="my-company-db-backups"
export AWS_S3_PREFIX="production/"
export VGX_DB_HOSTS="prod-db1.example.com,prod-db2.example.com"
export VGX_DB_USERS="backup_user,backup_user"
export VGX_DB_PASSWORDS="secure_password1,secure_password2"
```

## Usage

### Manual Execution

```bash
# Git storage (default)
./BackupDB.sh

# S3 storage
export VGX_DB_STORAGE_TYPE="s3"
export AWS_S3_BUCKET="my-backup-bucket"
./BackupDB.sh

# OneDrive storage
export VGX_DB_STORAGE_TYPE="onedrive"
export ONEDRIVE_REMOTE="onedrive"
./BackupDB.sh

# Backblaze B2 storage
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ENDPOINT_URL="https://s3.us-west-002.backblazeb2.com"
export AWS_S3_BUCKET="my-b2-bucket"
./BackupDB.sh

# Wasabi storage
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ENDPOINT_URL="https://s3.us-central-1.wasabisys.com"
export AWS_S3_BUCKET="my-wasabi-bucket"
./BackupDB.sh
```

### Automated Execution (Cron)

```bash
# Edit crontab
crontab -e

# Add daily backup at 2:00 AM
0 2 * * * source ~/.backup_env && /path/to/BackupDB.sh >> /var/log/backup.log 2>&1

# Weekly backup with different storage
0 3 * * 0 VGX_DB_STORAGE_TYPE=s3 AWS_S3_BUCKET=weekly-backups /path/to/BackupDB.sh

# Backblaze B2 with cron
0 4 * * 0 VGX_DB_STORAGE_TYPE=s3 AWS_ENDPOINT_URL=https://s3.us-west-002.backblazeb2.com AWS_S3_BUCKET=b2-weekly /path/to/BackupDB.sh
```

## How It Works

### Workflow Overview

1. **Storage Initialization**: Validates configuration and dependencies for selected backend
2. **Database Discovery**: Connects to each MySQL host and discovers databases (excluding system DBs)
3. **Backup Creation**: Creates compressed SQL dumps for each database
4. **Change Detection**: Compares with previous day's backup to detect changes
5. **Storage Upload**: Uploads only changed backups to configured storage backend
6. **Cleanup**: Removes old local files (object storage) or manages retention (Git)

### Storage-Specific Behavior

| Feature | Git | S3/S3-Compatible | OneDrive |
|---------|-----|------------------|---------| 
| **Local Files** | Kept (Git manages) | Removed after upload | Removed after upload |
| **Versioning** | Git history | S3 versioning (optional) | Folder-based by date |
| **Retention** | Manual Git management | 30-day automatic | 30-day automatic |
| **Large Files** | Git LFS (>100MB) | Native support | Native support |
| **Organization** | Git structure | Date-based prefixes | Date-based folders |
| **Endpoints** | Git hosting service | Configurable (AWS/B2/Wasabi/etc.) | Microsoft OneDrive |

## Backup File Structure

### Git Storage
```
/backup-directory/
├── .git/
├── .gitattributes (LFS patterns)
├── database1/
│   ├── 20250722_database1.sql.gz
│   └── 20250721_database1.sql.gz
└── database2/
    ├── 20250722_database2.sql.gz
    └── 20250721_database2.sql.gz
```

### S3 Storage (AWS S3, Backblaze B2, Wasabi, etc.)
```
s3://bucket/prefix/
├── 20250722/
│   ├── database1/20250722_database1.sql.gz
│   └── database2/20250722_database2.sql.gz
└── 20250721/
    ├── database1/20250721_database1.sql.gz
    └── database2/20250721_database2.sql.gz
```

### OneDrive Storage
```
/DatabaseBackups/
├── 20250722/
│   ├── database1/20250722_database1.sql.gz
│   └── database2/20250722_database2.sql.gz
└── 20250721/
    ├── database1/20250721_database1.sql.gz
    └── database2/20250721_database2.sql.gz
```

## Troubleshooting

### Storage Authentication Issues

**Git Authentication**:
```bash
# Test SSH connection
ssh -T git@github.com

# Check SSH agent
ssh-add -l

# Re-add keys if needed
ssh-add ~/.ssh/id_rsa
```

**AWS S3 Authentication**:
```bash
# Verify credentials
aws sts get-caller-identity

# Test bucket access
aws s3 ls s3://your-bucket-name

# Check IAM permissions (PutObject, GetObject, DeleteObject required)
```

**S3-Compatible Storage Authentication**:
```bash
# Test credentials with endpoint URL
aws --endpoint-url=$AWS_ENDPOINT_URL sts get-caller-identity

# Test bucket access
aws --endpoint-url=$AWS_ENDPOINT_URL s3 ls s3://your-bucket-name

# Test with specific endpoints
# Backblaze B2:
aws --endpoint-url=https://s3.us-west-002.backblazeb2.com s3 ls s3://your-b2-bucket

# Wasabi:
aws --endpoint-url=https://s3.us-central-1.wasabisys.com s3 ls s3://your-wasabi-bucket

# DigitalOcean Spaces:
aws --endpoint-url=https://nyc3.digitaloceanspaces.com s3 ls s3://your-spaces-bucket
```

**OneDrive Authentication**:
```bash
# Check rclone configuration
rclone config show

# Test connection
rclone ls onedrive:

# Re-authenticate if expired
rclone config reconnect onedrive

# Test specific folder
rclone ls onedrive:/DatabaseBackups

# Check available remotes
rclone listremotes

# Detailed connection test
rclone check onedrive: onedrive: --one-way
```

**OneDrive Common Issues:**

1. **"Token expired" errors**:
   ```bash
   rclone config reconnect onedrive
   ```

2. **"Remote not found" error**:
   ```bash
   # Check remote name matches exactly
   rclone listremotes
   export ONEDRIVE_REMOTE="your-actual-remote-name"
   ```

3. **Permission denied**:
   - Re-run `rclone config` and re-authenticate
   - Check Microsoft account permissions
   - For business accounts, contact admin

4. **Browser authentication fails**:
   ```bash
   # Use manual auth for headless servers
   rclone config
   # Choose "n) No" for auto config
   # Copy provided URL to browser on another machine
   # Paste auth code back to terminal
   ```

5. **Enterprise/SharePoint issues**:
   - Register custom app in Azure Portal
   - Get admin approval for app permissions
   - Use sharepoint config type instead of onedrive
   - Provide correct SharePoint site URL

6. **Multi-factor authentication (MFA)**:
   - Complete MFA during browser authentication
   - Use app passwords if required by organization
   - Configure conditional access policies to allow rclone

### Common Issues

- **Missing Dependencies**: Script auto-installs required packages
- **Permission Errors**: Ensure script has execute permissions and write access to backup directory
- **Database Connection**: Verify network connectivity and credentials
- **Storage Quotas**: Monitor storage usage, especially for cloud backends

## Security Best Practices

- **Never hardcode passwords** - Always use environment variables
- **Use private repositories** for Git storage
- **Enable S3 bucket encryption** and restrict access with IAM policies  
- **Enable 2FA** on Microsoft accounts for OneDrive
- **Rotate access keys** regularly
- **Monitor access logs** for unauthorized usage
- **Encrypt sensitive dumps** before upload if required by compliance

## Performance Optimization

- **Large Databases**: Git automatically uses LFS for files >100MB
- **Network Optimization**: S3 uses multipart uploads, OneDrive has resumable transfers
- **Compression**: All backups are gzip compressed (level 9)
- **Parallel Processing**: Multiple database hosts processed concurrently

## Support

For support, contact: support.backupdb@vgx.email

## License

Copyright (c) 2025 VGX Consulting by Vijendra Malhotra. All rights reserved.

---

## Changelog

### Version 5.0 (2025-07-22)
- Added multi-storage backend support (Git, S3, OneDrive)
- Implemented storage abstraction layer
- Added smart dependency management
- Enhanced security with environment variables
- Improved error handling and validation

### Version 4.x
- Environment variable support
- Enhanced logging system
- Cross-platform compatibility improvements

### Version 3.x
- Basic Git integration
- MySQL backup functionality
- Compression and cleanup features