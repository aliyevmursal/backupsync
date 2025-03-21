#!/bin/bash
################################################################################
#
# BackupSync - Advanced Backup System for Linux
# 
# Author: Mursal Aliyev
# Date: March 21, 2025
# Description: A comprehensive backup solution with:
#   - Timestamped backups
#   - Configurable source/destination
#   - Compression options
#   - Notification system
#   - Auto cleanup
#   - Cloud/Network backup
#   - Cron scheduling support
#
################################################################################

# Exit on error
set -e

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
CONFIG_FILE="${SCRIPT_DIR}/backup_config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please create the configuration file. See backup_config.example.conf for reference."
    exit 1
fi

source "$CONFIG_FILE"

# Set default values if not defined in config
SOURCE_DIR="${SOURCE_DIR:-/home/user/data}"
DESTINATION_DIR="${DESTINATION_DIR:-/backup}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
ENABLE_COMPRESSION="${ENABLE_COMPRESSION:-true}"
ENABLE_EMAIL_NOTIFICATION="${ENABLE_EMAIL_NOTIFICATION:-false}"
EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-admin@example.com}"
ENABLE_TELEGRAM_NOTIFICATION="${ENABLE_TELEGRAM_NOTIFICATION:-false}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
ENABLE_CLOUD_BACKUP="${ENABLE_CLOUD_BACKUP:-false}"
CLOUD_PROVIDER="${CLOUD_PROVIDER:-none}" # Options: aws_s3, ftp, rsync_ssh
AWS_S3_BUCKET="${AWS_S3_BUCKET:-}"
FTP_SERVER="${FTP_SERVER:-}"
FTP_USER="${FTP_USER:-}"
FTP_PASSWORD="${FTP_PASSWORD:-}"
REMOTE_SERVER="${REMOTE_SERVER:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_PATH="${REMOTE_PATH:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"

# Create log directory
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# Function to log messages
log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Function to check if required commands exist
check_requirements() {
    log "Checking requirements..."
    
    local required_commands=("tar" "rsync")
    
    if [ "$ENABLE_EMAIL_NOTIFICATION" = true ]; then
        required_commands+=("mail")
    fi
    
    if [ "$ENABLE_CLOUD_BACKUP" = true ]; then
        case "$CLOUD_PROVIDER" in
            aws_s3)
                required_commands+=("aws")
                ;;
            ftp)
                required_commands+=("curl")
                ;;
            rsync_ssh)
                required_commands+=("rsync" "ssh")
                ;;
        esac
    fi
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "Error: Required command '$cmd' not found. Please install it and try again."
            exit 1
        fi
    done
    
    log "All requirements satisfied."
}

# Function to create backup directory
create_backup_dir() {
    log "Creating backup directory..."
    
    BACKUP_DIR="${DESTINATION_DIR}/backup_${TIMESTAMP}"
    mkdir -p "$BACKUP_DIR"
    
    if [ $? -ne 0 ]; then
        log "Error: Failed to create backup directory at $BACKUP_DIR"
        exit 1
    fi
    
    log "Created backup directory: $BACKUP_DIR"
}

# Function to perform backup
perform_backup() {
    log "Starting backup process..."
    
    if [ ! -d "$SOURCE_DIR" ]; then
        log "Error: Source directory '$SOURCE_DIR' does not exist."
        exit 1
    fi
    
    if [ "$ENABLE_COMPRESSION" = true ]; then
        log "Creating compressed backup..."
        BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.tar.gz"
        
        tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2>> "$LOG_FILE"
        
        if [ $? -ne 0 ]; then
            log "Error: Compression failed."
            exit 1
        fi
        
        log "Compression completed: $BACKUP_FILE"
    else
        log "Creating uncompressed backup..."
        
        rsync -aAXv --delete "$SOURCE_DIR/" "$BACKUP_DIR/" >> "$LOG_FILE" 2>&1
        
        if [ $? -ne 0 ]; then
            log "Error: Rsync backup failed."
            exit 1
        fi
        
        log "Rsync backup completed to: $BACKUP_DIR"
    fi
    
    # Create a completion flag file
    touch "${BACKUP_DIR}/.backup_complete"
    
    log "Backup process completed successfully."
}

# Function to upload backup to cloud storage
upload_to_cloud() {
    if [ "$ENABLE_CLOUD_BACKUP" != true ]; then
        return 0
    fi
    
    log "Starting cloud backup to $CLOUD_PROVIDER..."
    
    case "$CLOUD_PROVIDER" in
        aws_s3)
            if [ -z "$AWS_S3_BUCKET" ]; then
                log "Error: AWS S3 bucket not specified."
                return 1
            fi
            
            log "Uploading to AWS S3 bucket: $AWS_S3_BUCKET"
            
            if [ "$ENABLE_COMPRESSION" = true ]; then
                aws s3 cp "$BACKUP_FILE" "s3://${AWS_S3_BUCKET}/backup_${TIMESTAMP}.tar.gz" >> "$LOG_FILE" 2>&1
            else
                aws s3 sync "$BACKUP_DIR" "s3://${AWS_S3_BUCKET}/backup_${TIMESTAMP}" >> "$LOG_FILE" 2>&1
            fi
            
            if [ $? -ne 0 ]; then
                log "Error: AWS S3 upload failed."
                return 1
            fi
            ;;
            
        ftp)
            if [ -z "$FTP_SERVER" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASSWORD" ]; then
                log "Error: FTP credentials not specified."
                return 1
            fi
            
            log "Uploading to FTP server: $FTP_SERVER"
            
            if [ "$ENABLE_COMPRESSION" = true ]; then
                curl -T "$BACKUP_FILE" "ftp://${FTP_SERVER}/backup_${TIMESTAMP}.tar.gz" --user "${FTP_USER}:${FTP_PASSWORD}" >> "$LOG_FILE" 2>&1
            else
                # For directory upload, this is simplified and may need more sophistication
                # Consider using lftp for directory upload in a real environment
                find "$BACKUP_DIR" -type f | while read file; do
                    rel_path="${file#$BACKUP_DIR/}"
                    curl -T "$file" "ftp://${FTP_SERVER}/backup_${TIMESTAMP}/${rel_path}" --user "${FTP_USER}:${FTP_PASSWORD}" --create-dirs >> "$LOG_FILE" 2>&1
                done
            fi
            
            if [ $? -ne 0 ]; then
                log "Error: FTP upload failed."
                return 1
            fi
            ;;
            
        rsync_ssh)
            if [ -z "$REMOTE_SERVER" ] || [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_PATH" ]; then
                log "Error: Remote server details not specified."
                return 1
            fi
            
            log "Uploading to remote server: $REMOTE_SERVER"
            
            SSH_OPTS=""
            if [ -n "$SSH_KEY_PATH" ]; then
                SSH_OPTS="-e 'ssh -i $SSH_KEY_PATH'"
            fi
            
            if [ "$ENABLE_COMPRESSION" = true ]; then
                rsync -avz $SSH_OPTS "$BACKUP_FILE" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}/backup_${TIMESTAMP}.tar.gz" >> "$LOG_FILE" 2>&1
            else
                rsync -avz $SSH_OPTS "$BACKUP_DIR/" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}/backup_${TIMESTAMP}/" >> "$LOG_FILE" 2>&1
            fi
            
            if [ $? -ne 0 ]; then
                log "Error: Remote server upload failed."
                return 1
            fi
            ;;
            
        none)
            log "No cloud provider selected. Skipping cloud backup."
            ;;
            
        *)
            log "Error: Unknown cloud provider '$CLOUD_PROVIDER'."
            return 1
            ;;
    esac
    
    log "Cloud backup completed successfully."
    return 0
}

# Function to clean up old backups
cleanup_old_backups() {
    if [ "$BACKUP_RETENTION_DAYS" -le 0 ]; then
        log "Backup retention set to unlimited. Skipping cleanup."
        return 0
    fi
    
    log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
    
    find "${DESTINATION_DIR}" -type d -name "backup_*" -mtime +${BACKUP_RETENTION_DAYS} | while read old_backup; do
        log "Removing old backup: $old_backup"
        rm -rf "$old_backup" >> "$LOG_FILE" 2>&1
    done
    
    log "Cleanup completed."
}

# Function to send email notification
send_email_notification() {
    if [ "$ENABLE_EMAIL_NOTIFICATION" != true ]; then
        return 0
    fi
    
    if [ -z "$EMAIL_RECIPIENT" ]; then
        log "Error: Email recipient not specified."
        return 1
    fi
    
    log "Sending email notification to $EMAIL_RECIPIENT..."
    
    local subject="Backup Completed - $(hostname) - ${TIMESTAMP}"
    local message="Backup of ${SOURCE_DIR} completed successfully on $(date).\n\n"
    message+="Backup location: ${BACKUP_DIR}\n"
    message+="Log file: ${LOG_FILE}\n\n"
    message+="BackupSync by Mursal Aliyev"
    
    echo -e "$message" | mail -s "$subject" "$EMAIL_RECIPIENT"
    
    if [ $? -ne 0 ]; then
        log "Error: Failed to send email notification."
        return 1
    fi
    
    log "Email notification sent successfully."
    return 0
}

# Function to send Telegram notification
send_telegram_notification() {
    if [ "$ENABLE_TELEGRAM_NOTIFICATION" != true ]; then
        return 0
    fi
    
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        log "Error: Telegram credentials not specified."
        return 1
    fi
    
    log "Sending Telegram notification..."
    
    local message="Backup Completed ✅%0A"
    message+="Host: $(hostname)%0A"
    message+="Time: $(date)%0A"
    message+="Source: ${SOURCE_DIR}%0A"
    message+="Destination: ${BACKUP_DIR}"
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "Error: Failed to send Telegram notification."
        return 1
    fi
    
    log "Telegram notification sent successfully."
    return 0
}

# Main execution
main() {
    log "BackupSync started"
    
    check_requirements
    create_backup_dir
    perform_backup
    upload_to_cloud
    cleanup_old_backups
    send_email_notification
    send_telegram_notification
    
    log "BackupSync completed successfully"
}

# Run the script
main
