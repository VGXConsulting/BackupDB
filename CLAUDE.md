# BackupDB Script - Version History & Updates

This file tracks version changes and improvements made to the BackupDB script.

**REMINDER: When making changes to BackupDB.sh, always update the version number in:**
1. Script header (line 6): `# Version: X.X`
2. Startup banner (around line 397): `echo "DATABASE BACKUP SCRIPT vX.X"`
3. Add entry to this CLAUDE.md file

## Version 5.0 (2025-07-22)

### Major Feature: Multi-Storage Backend Support
- **Storage Options**: Added support for Git, AWS S3, and Microsoft OneDrive storage backends
- **Storage Configuration**: New environment variable `VGX_DB_STORAGE_TYPE` (options: git, s3, onedrive)
- **Storage-Specific Settings**: 
  - Git: `VGX_DB_GIT_REPO` (unchanged from previous versions)
  - S3: `AWS_S3_BUCKET`, `AWS_S3_PREFIX` for bucket and path configuration
  - OneDrive: `ONEDRIVE_REMOTE`, `ONEDRIVE_PATH` for rclone integration

### Key Architecture Changes
- **Storage Abstraction**: Refactored upload logic into storage-agnostic functions
  - `upload_to_git()` - Git repository with LFS support
  - `upload_to_s3()` - AWS S3 with automatic retention management
  - `upload_to_onedrive()` - OneDrive via rclone with organized folder structure
- **Smart Dependencies**: Only checks and installs dependencies based on selected storage type
- **Cleanup Strategy**: Git keeps local files, object storage removes local files after successful upload
- **Backward Compatibility**: Git remains the default storage type for existing deployments

### Enhanced Features
- **Dynamic Dependency Management**: Installs aws-cli for S3, rclone for OneDrive based on storage selection
- **Storage Validation**: Pre-flight checks for storage credentials and connectivity
- **S3-Compatible Support**: Full support for Backblaze B2, Wasabi, DigitalOcean Spaces, MinIO with endpoint URLs
- **Comprehensive OneDrive Auth**: Detailed setup for personal, business, SharePoint, and enterprise scenarios
- **Built-in Help System**: Interactive help with `--help`, `--version`, and `--test-config` commands
- **Organized Storage**: S3 and OneDrive use date-based folder structure for better organization
- **Automatic Retention**: Object storage backends implement 30-day retention policies
- **Enhanced Configuration Display**: Shows active storage backend and configuration sources

### Usage Examples
```bash
# Default Git storage (backward compatible)
./BackupDB.sh

# AWS S3 storage
export VGX_DB_STORAGE_TYPE="s3"
export AWS_S3_BUCKET="my-db-backups"
export AWS_S3_PREFIX="prod-backups/"
./BackupDB.sh

# OneDrive storage
export VGX_DB_STORAGE_TYPE="onedrive"
export ONEDRIVE_REMOTE="onedrive"
export ONEDRIVE_PATH="/DatabaseBackups"
./BackupDB.sh

# Backblaze B2 storage
export VGX_DB_STORAGE_TYPE="s3"
export AWS_ENDPOINT_URL="https://s3.us-west-002.backblazeb2.com"
export AWS_S3_BUCKET="my-b2-bucket"
./BackupDB.sh

# Built-in help and testing
./BackupDB.sh --help
./BackupDB.sh --test-config
```

## Version 4.2 (2025-07-22)

### Major Feature: Environment Variable Support
- **Secure Configuration**: Script now prioritizes environment variables over hardcoded values
- **Environment Variables**: 
  - `VGX_DB_OPATH` - Backup directory path
  - `VGX_DB_GIT_REPO` - Git repository URL
  - `VGX_DB_HOSTS` - Database hosts (comma-separated)
  - `VGX_DB_PORTS` - Database ports (comma-separated)  
  - `VGX_DB_USERS` - Database usernames (comma-separated)
  - `VGX_DB_PASSWORDS` - Database passwords (comma-separated)

### Testing & Security Benefits
- **Easy Testing**: No need to modify script for different environments
- **Security**: Passwords can be stored in environment variables instead of script
- **Configuration Display**: Shows source of each configuration value at startup
- **Fallback Support**: Uses script defaults if environment variables not set

### Usage Example
```bash
export VGX_DB_HOSTS="db1.example.com,db2.example.com"
export VGX_DB_USERS="backup_user1,backup_user2"
export VGX_DB_PASSWORDS="secret1,secret2"
./BackupDB.sh
```

## Version 4.1 (2025-07-22)

### New Features
- **Centralized Logging**: Added `logme()` function with color-coded output
  - ERROR messages in red
  - WARNING messages in yellow  
  - SUCCESS messages in green
  - INFO messages normal
- **Cleaner Code**: Replaced all scattered color echo statements with single function calls

### Code Quality
- More maintainable logging system
- Consistent message formatting throughout script
- Easier to modify colors/formatting in future

## Version 4.0 (2025-07-22)

### Major Enhancements
- **Comprehensive Dependency Management**: Auto-detection and installation of missing dependencies
- **Smart Git LFS Integration**: Pattern-based tracking for large database backups (>100MB)
- **Enhanced OS Support**: macOS (brew), Ubuntu/Debian (apt), RHEL/CentOS (yum/dnf), openSUSE (zypper)
- **Color-coded Logging**: Added `logme()` function with RED (errors), YELLOW (warnings), GREEN (success)
- **Improved Error Handling**: Better git operation handling and dynamic branch detection

### Technical Improvements
- Fixed duplicate Step 5 numbering (renamed to Step 4.5 for LFS)
- Simplified LFS file detection using `find` with size filtering
- Added dynamic git branch detection instead of hardcoded 'main'
- Replaced unsafe `eval` with `bash -c` for command execution
- Fixed syntax errors and documentation inconsistencies

### New Features
- **Step 0**: System dependency verification with auto-installation
- **Smart LFS Patterns**: Database-specific patterns like `customer_db/*.gz`
- **Permission Detection**: Automatic detection of elevated privileges
- **Cross-platform Compatibility**: Enhanced OS and package manager detection

### Bug Fixes
- Fixed missing quote in final echo statement
- Corrected script name references in documentation
- Added proper error handling for git pull operations
- Moved functions to appropriate locations

---

## Previous Versions

### Version 3.5 (2025-04-20)
- Basic MySQL backup functionality
- Git integration for backup versioning
- Simple file compression and cleanup
- Manual dependency management

---

## Usage Instructions

To update the version in the script header:

1. Update version number in script header (lines 6-7)
2. Update this CLAUDE.md file with new version details
3. Update version display in startup banner (around line 340)

## Maintenance Notes

- All major changes should be documented in this file
- Version numbers should follow semantic versioning (major.minor)
- Include both technical details and user-facing improvements
- Update dates in ISO format (YYYY-MM-DD)