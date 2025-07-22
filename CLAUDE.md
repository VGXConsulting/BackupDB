# BackupDB Script - Version History & Updates

This file tracks version changes and improvements made to the BackupDB script.

**REMINDER: When making changes to BackupDB.sh, always update the version number in:**
1. Script header (line 6): `# Version: X.X`
2. Startup banner (around line 370): `echo "DATABASE BACKUP SCRIPT vX.X"`
3. Add entry to this CLAUDE.md file

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