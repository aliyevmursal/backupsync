# BackupSync

A comprehensive backup solution for Linux system administrators with advanced features.

## Features

- **Timestamped Backups**: Creates a unique timestamped folder for each backup operation
- **Configurable Source/Destination**: Easily specify what to backup and where
- **Optional Compression**: Choose whether to compress backups using tar.gz format
- **Notification System**: Get email or Telegram alerts when backups complete
- **Automatic Cleanup**: Automatically remove backups older than specified days
- **Cloud/Network Support**: Upload backups to AWS S3, FTP servers, or remote servers via SSH
- **Scheduling Support**: Designed to work seamlessly with cron jobs

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

3. Copy and customize the configuration:
   ```bash
   cp backup_config.conf.example backup_config.conf
   nano backup_config.conf
   ```

## Configuration

Edit `backup_config.conf` to customize your backup settings:

```bash
# Basic settings
SOURCE_DIR="/path/to/source"  # Directory to backup
DESTINATION_DIR="/path/to/backups"  # Where to store backups
BACKUP_RETENTION_DAYS=30  # How long to keep old backups (0 for unlimited)

# Enable/disable features
ENABLE_COMPRESSION=true
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

## License

MIT License

## Author

Mursal Aliyev

---

Feel free to contribute to this project by submitting issues or pull requests!
