# BackupSync

A comprehensive backup solution for Linux system administrators with advanced features.

## Features

- **Timestamped Backups**: Creates a unique timestamped folder for each backup operation
- **Incremental Backups**: Save space and time by only backing up changes since the last full backup
- **Configurable Source/Destination**: Easily specify what to backup and where
- **Optional Compression**: Choose whether to compress backups using tar.gz format
- **Notification System**: Get email or Telegram alerts when backups complete
- **Automatic Cleanup**: Automatically remove backups older than specified days
- **Cloud/Network Support**: Upload backups to AWS S3, FTP servers, or remote servers via SSH
- **Scheduling Support**: Designed to work seamlessly with cron jobs
- **Restore Functionality**: Easily restore from any full or incremental backup

## Requirements

- Bash shell
- Standard Linux utilities (tar, rsync)
- For notifications: mail command (for email) or curl (for Telegram)
- For cloud backup: aws CLI (for S3), curl (for FTP), or rsync/ssh (for remote servers)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/aliyevmursal/backup-sync.git
   cd backup-sync
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

### Telegram Notifications
```bash
ENABLE_TELEGRAM_NOTIFICATION=true
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

## How Incremental Backups Work

### Technical Implementation
- Full backups are marked with `.full_backup` files
- Incremental backups contain `.incremental_backup` files that reference the parent full backup
- For compressed backups:
  - Uses `find` to identify changed files since last backup
  - Creates a list of changed files in `changed_files.txt`
  - Uses `tar` with the `-T` option to only include changed files
- For uncompressed backups:
  - Uses rsync's `--link-dest` feature to create efficient hard links
  - Only new or modified files consume additional disk space
  - Unchanged files are hard-linked to save space while maintaining a complete backup snapshot

### Restoration Process
When restoring from an incremental backup:
1. The script identifies the parent full backup
2. It restores the full backup first
3. It identifies and orders all intermediate incremental backups
4. It applies each incremental backup in chronological order
5. Finally, it applies the target incremental backup

This ensures that the restored data represents exactly what existed at the time of the target backup.

## Command-Line Options

```bash
# Perform backup (according to configuration)
./backup_sync.sh

# Restore from backup
./backup_sync.sh restore <backup_directory> [target_directory]
```

## Troubleshooting

### Common Issues

- **Permission Denied**: Ensure the script has proper permissions to read the source directory and write to the destination directory
- **Incremental Backup Failed**: Check if the referenced full backup exists and hasn't been deleted
- **Cloud Upload Failed**: Verify your network connection and cloud service credentials
- **Notification Failed**: Check your email/Telegram configuration settings

### Log File Analysis

Examine the log files in the `logs/` directory for detailed information:

```bash
cat logs/backup_20250326_120101.log
```

Look for warnings or errors that might indicate what went wrong.

## License

MIT License

## Author

Mursal Aliyev

---

Feel free to contribute to this project by submitting issues or pull requests!