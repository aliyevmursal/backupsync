🚀 BackupSync is a powerful backup solution that efficiently manages full and incremental backups. It optimizes storage usage while ensuring fast and reliable data protection.

A comprehensive backup solution for Linux system administrators with advanced features.

| Language | README |
| --- | --- |
| <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/us.svg" width="22"> 🇺🇸 Английский | [English](README.md) |
| <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/tr.svg" width="22"> 🇹🇷 Турецкий | [Türkçe](README.tr.md) |
| <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/az.svg" width="22"> 🇦🇿 Азербайджанский | [Azərbaycanca](README.az.md) |
| <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/ru.svg" width="22"> 🇷🇺 Русский | [Русский](README.ru.md) |

🚀 BackupSync – Key Features

- **🕒 Timestamped Backups**: Creates a unique timestamped folder for each backup operation
- **🔄 Incremental Backups**: Save space and time by only backing up changes since the last full backup
- **📂 Configurable Source/Destination**: Easily specify what to backup and where
- **📦 Optional Compression**: Choose whether to compress backups using tar.gz format
- **📢 Notification System**: Get email or Telegram alerts when backups complete
- **🗑️ Automatic Cleanup**: Automatically remove backups older than specified days
- **☁️ Cloud/Network Support**: Upload backups to AWS S3, FTP servers, or remote servers via SSH
- **⏳ Scheduling Support**: Designed to work seamlessly with cron jobs
- **🔄 Restore Functionality**: Easily restore from any full or incremental backup
- **🔐 Encryption Support**: Secure your backups with AES-256 encryption
- **✅ Backup Verification**: Ensure backup integrity with automatic verification
- **🗃️ Database Backup**: Support for MySQL/MariaDB, PostgreSQL, and MSSQL databases
- **⚙️ Advanced Backup Features**: File exclusion patterns and deduplication
- **💾 Disk Space Monitoring**: Automatically check for sufficient disk space before backup

## Requirements

- Bash shell
- Standard Linux utilities (tar, rsync)
- For notifications: mail command (for email) or curl (for Telegram)
- For encryption: openssl
- For database backup: mysqldump (MySQL/MariaDB), pg_dump (PostgreSQL), or sqlcmd (MSSQL)
- For cloud backup: aws CLI (for S3), curl (for FTP), or rsync/ssh (for remote servers)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/aliyevmursal/backupsync.git
   cd backupsync
   ```

2. Make the script executable:
   ```bash
   chmod +x backup_sync.sh
   ```

3. Customize the configuration:
   ```bash
   nano backup_config.conf
   ```

## Configuration

Edit `backup_config.conf` to customize your backup settings:

```bash
# Basic settings
SOURCE_DIR="/path/to/source"  # Directory to backup
DESTINATION_DIR="/path/to/backups"  # Where to store backups
BACKUP_RETENTION_DAYS=30  # How long to keep old backups (0 for unlimited)

# Backup type settings
ENABLE_COMPRESSION=true
ENABLE_INCREMENTAL=false
INCREMENTAL_MAX_FULL=7  # Days between full backups when using incremental

# Database backup settings
ENABLE_DATABASE_BACKUP=false
DATABASE_TYPE="mysql"  # mysql, postgresql, or mssql
DB_HOST="localhost"
DB_PORT="3306"  # 3306 for MySQL, 5432 for PostgreSQL, 1433 for MSSQL
DB_USER="root"
DB_PASSWORD=""
DB_NAMES=""  # Empty for all databases, comma-separated list for specific ones

# MSSQL Specific Settings
MSSQL_AUTH_TYPE="sql"  # sql or windows
MSSQL_INSTANCE=""  # Empty for default instance
MSSQL_BACKUP_TYPE="full"  # full, differential, or log

# Advanced backup features
FILE_EXCLUSION_PATTERNS="*.tmp,*.log,*~,.git/,.svn/"
ENABLE_DEDUPLICATION=false
MIN_DISK_SPACE_MB=1024  # Minimum free space required in MB

# Security settings
ENABLE_ENCRYPTION=false
ENCRYPTION_PASSWORD=""
ENABLE_BACKUP_VERIFICATION=true

# Enable/disable features
ENABLE_EMAIL_NOTIFICATION=false
ENABLE_TELEGRAM_NOTIFICATION=false
ENABLE_CLOUD_BACKUP=false

# Additional settings for enabled features
# ...see the config file for all options
```

## Usage

### Manual Execution

Run the script manually:

```bash
./backup_sync.sh
```

### Scheduled Execution

Add to crontab to run automatically:

```bash
# Edit crontab
crontab -e

# Add a line like this to run daily at 2 AM:
0 2 * * * /path/to/backup_sync.sh
```

### Restore from Backup

To restore from a backup:

```bash
# Restore to original location
./backup_sync.sh restore /path/to/backup_directory

# Restore to different location
./backup_sync.sh restore /path/to/backup_directory /path/to/restore/target
```

When restoring from an incremental backup, the script automatically applies the full backup and any intermediate incremental backups in the correct order.

## Understanding Incremental Backups

When incremental backups are enabled:
- The first backup is always a full backup
- Subsequent backups only contain files that have changed since the last backup
- A new full backup is created after INCREMENTAL_MAX_FULL days
- When restoring, the system automatically reconstructs the complete backup from the full backup and all incremental backups

Benefits:
- Significantly reduced backup size
- Faster backup operations
- Reduced network traffic for cloud backups
- Maintains the ability to restore from any point in time

## Database Backup Features

BackupSync supports backing up MySQL/MariaDB, PostgreSQL, and Microsoft SQL Server databases:

### MySQL/MariaDB
- Full database dumps with stored procedures, triggers, and events
- Option to backup specific databases or all databases
- Integration with encryption and compression features

### PostgreSQL
- Custom format backups for efficient storage
- Option to backup specific databases or all databases
- Integration with encryption and verification features

### Microsoft SQL Server
- Support for SQL and Windows authentication methods
- Support for different backup types (Full, Differential, Log)
- Option to specify a named instance or default instance
- Backup to BAK files with compression support
- Integration with encryption and verification features

## Advanced Backup Features

### File Exclusion
Specify files and directories to exclude from backup using patterns:
```bash
FILE_EXCLUSION_PATTERNS="*.tmp,*.log,*~,.git/,.svn/"
```

### Deduplication
Save storage space by eliminating duplicate files across backups:
```bash
ENABLE_DEDUPLICATION=true
```

### Disk Space Monitoring
Automatically checks for sufficient disk space before starting the backup:
```bash
MIN_DISK_SPACE_MB=1024  # Minimum free space in MB
```

## Security Features

### Encryption
Protect your backups with AES-256 encryption:
```bash
ENABLE_ENCRYPTION=true
ENCRYPTION_PASSWORD="your-secure-password"
```

### Backup Verification
Ensure backup integrity with automatic verification:
```bash
ENABLE_BACKUP_VERIFICATION=true
```

## Logging

Logs are stored in the `logs/` directory with timestamped filenames. Each backup operation generates a detailed log file.

## Cloud Backup Options

BackupSync supports multiple cloud and remote storage options:

### AWS S3
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="aws_s3"
AWS_S3_BUCKET="your-bucket-name"
```

### FTP Server
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="ftp"
FTP_SERVER="ftp.example.com"
FTP_USER="username"
FTP_PASSWORD="password"
```

### Remote Server (SSH/rsync)
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="rsync_ssh"
REMOTE_SERVER="server.example.com"
REMOTE_USER="username"
REMOTE_PATH="/path/on/remote/server"
SSH_KEY_PATH="/path/to/private/key"  # Optional
```

## Notification Setup

### Email Notifications
```bash
ENABLE_EMAIL_NOTIFICATION=true
EMAIL_RECIPIENT="your-email@example.com"
```

Emails include:
- Backup status (success/failure)
- Detailed error information if backup failed
- Disk space information
- Backup details (type, location, etc.)

### Telegram Notifications
```bash
ENABLE_TELEGRAM_NOTIFICATION=true
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

Telegram messages include:
- Backup status with visual indicator (✅/❌)
- Disk space metrics
- Backup details
- Error information if backup failed

## License

MIT License

## Author

Mursal Aliyev

---

Feel free to contribute to this project by submitting issues or pull requests!