#!/bin/bash
################################################################################
#
# BackupSync - Advanced Backup System for Linux
# 
# Author: Mursal Aliyev
# Date: March 21, 2025
# Description: A comprehensive backup solution with:
#   - Timestamped backups
#   - Incremental backups
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
ENABLE_INCREMENTAL="${ENABLE_INCREMENTAL:-false}"
INCREMENTAL_MAX_FULL="${INCREMENTAL_MAX_FULL:-7}"
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

# Function to find the most recent full backup
find_latest_full_backup() {
    find "${DESTINATION_DIR}" -type f -name ".full_backup" | sort -r | head -n 1 | xargs dirname 2>/dev/null || echo ""
}

# Function to find the most recent incremental backup
find_latest_incremental_backup() {
    local full_backup_dir="$1"
    
    # Look for incremental backups associated with this full backup
    find "${DESTINATION_DIR}" -type f -name ".incremental_backup" | 
        xargs grep -l "$(basename "$full_backup_dir")" 2>/dev/null | 
        sort -r | 
        head -n 1 | 
        xargs dirname 2>/dev/null || echo ""
}

# Function to perform backup
perform_backup() {
    log "Starting backup process..."
    
    if [ ! -d "$SOURCE_DIR" ]; then
        log "Error: Source directory '$SOURCE_DIR' does not exist."
        exit 1
    fi
    
    # Determine backup type (full or incremental)
    BACKUP_TYPE="full"
    FULL_BACKUP_REF=""
    LAST_BACKUP_REF=""
    
    if [ "$ENABLE_INCREMENTAL" = true ]; then
        # Find the latest full backup
        LATEST_FULL=$(find_latest_full_backup)
        
        if [ -n "$LATEST_FULL" ]; then
            # Check if it's time for a new full backup
            # Get days since last full backup
            DAYS_SINCE_FULL=$(( ($(date +%s) - $(stat -c %Y "${LATEST_FULL}/.full_backup")) / 86400 ))
            
            if [ "$DAYS_SINCE_FULL" -lt "$INCREMENTAL_MAX_FULL" ]; then
                BACKUP_TYPE="incremental"
                FULL_BACKUP_REF="$LATEST_FULL"
                
                # Find the latest incremental backup
                LATEST_INCREMENTAL=$(find_latest_incremental_backup "$LATEST_FULL")
                
                if [ -n "$LATEST_INCREMENTAL" ]; then
                    LAST_BACKUP_REF="$LATEST_INCREMENTAL"
                else
                    LAST_BACKUP_REF="$LATEST_FULL"
                fi
                
                log "Performing incremental backup based on: $(basename "$LAST_BACKUP_REF")"
            else
                log "Last full backup is older than $INCREMENTAL_MAX_FULL days. Performing full backup."
            fi
        else
            log "No previous full backup found. Performing full backup."
        fi
    fi
    
    if [ "$ENABLE_COMPRESSION" = true ]; then
        log "Creating compressed $BACKUP_TYPE backup..."
        
        if [ "$BACKUP_TYPE" = "full" ]; then
            BACKUP_FILE="${BACKUP_DIR}/backup_full_${TIMESTAMP}.tar.gz"
            
            tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2>> "$LOG_FILE"
            
            if [ $? -ne 0 ]; then
                log "Error: Compression failed."
                exit 1
            fi
            
            # Mark as full backup
            touch "${BACKUP_DIR}/.full_backup"
            
            log "Full backup compression completed: $BACKUP_FILE"
        else
            BACKUP_FILE="${BACKUP_DIR}/backup_inc_${TIMESTAMP}.tar.gz"
            
            # Create a snapshot of current file state
            find "$SOURCE_DIR" -type f -print0 | xargs -0 stat -c "%n %Y %s" | sort > "${BACKUP_DIR}/current_snapshot.txt"
            
            # Find changed files since last backup
            find "$SOURCE_DIR" -type f -newer "$LAST_BACKUP_REF/.backup_complete" -print > "${BACKUP_DIR}/changed_files.txt"
            
            # If there are changed files, create the incremental backup
            if [ -s "${BACKUP_DIR}/changed_files.txt" ]; then
                tar -czf "$BACKUP_FILE" -T "${BACKUP_DIR}/changed_files.txt" 2>> "$LOG_FILE"
                
                if [ $? -ne 0 ]; then
                    log "Error: Incremental compression failed."
                    exit 1
                fi
                
                # Store reference to full backup
                echo "$(basename "$FULL_BACKUP_REF")" > "${BACKUP_DIR}/.incremental_backup"
                
                log "Incremental backup compression completed: $BACKUP_FILE"
                log "$(wc -l < "${BACKUP_DIR}/changed_files.txt") files included in incremental backup"
            else
                log "No changes detected since last backup. Creating empty marker file."
                touch "$BACKUP_FILE"
                echo "$(basename "$FULL_BACKUP_REF")" > "${BACKUP_DIR}/.incremental_backup"
            fi
        fi
    else
        log "Creating uncompressed $BACKUP_TYPE backup..."
        
        if [ "$BACKUP_TYPE" = "full" ]; then
            rsync -aAXv --delete "$SOURCE_DIR/" "$BACKUP_DIR/data/" >> "$LOG_FILE" 2>&1
            
            if [ $? -ne 0 ]; then
                log "Error: Rsync backup failed."
                exit 1
            fi
            
            # Mark as full backup
            touch "${BACKUP_DIR}/.full_backup"
            
            log "Full rsync backup completed to: $BACKUP_DIR"
        else
            # For uncompressed incremental, use rsync with link-dest to previous backup
            rsync -aAXv --delete --link-dest="$LAST_BACKUP_REF/data/" "$SOURCE_DIR/" "$BACKUP_DIR/data/" >> "$LOG_FILE" 2>&1
            
            if [ $? -ne 0 ]; then
                log "Error: Incremental rsync backup failed."
                exit 1
            fi
            
            # Store reference to full backup
            echo "$(basename "$FULL_BACKUP_REF")" > "${BACKUP_DIR}/.incremental_backup"
            
            log "Incremental rsync backup completed to: $BACKUP_DIR"
        fi
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
                aws s3 cp "$BACKUP_FILE" "s3://${AWS_S3_BUCKET}/$(basename "$BACKUP_FILE")" >> "$LOG_FILE" 2>&1
                
                # Also upload metadata files for incremental backups
                if [ -f "${BACKUP_DIR}/.incremental_backup" ]; then
                    aws s3 cp "${BACKUP_DIR}/.incremental_backup" "s3://${AWS_S3_BUCKET}/backup_${TIMESTAMP}/.incremental_backup" >> "$LOG_FILE" 2>&1
                fi
                if [ -f "${BACKUP_DIR}/.full_backup" ]; then
                    aws s3 cp "${BACKUP_DIR}/.full_backup" "s3://${AWS_S3_BUCKET}/backup_${TIMESTAMP}/.full_backup" >> "$LOG_FILE" 2>&1
                fi
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
                curl -T "$BACKUP_FILE" "ftp://${FTP_SERVER}/$(basename "$BACKUP_FILE")" --user "${FTP_USER}:${FTP_PASSWORD}" >> "$LOG_FILE" 2>&1
                
                # Also upload metadata files for incremental backups
                if [ -f "${BACKUP_DIR}/.incremental_backup" ]; then
                    curl -T "${BACKUP_DIR}/.incremental_backup" "ftp://${FTP_SERVER}/backup_${TIMESTAMP}/.incremental_backup" --user "${FTP_USER}:${FTP_PASSWORD}" --create-dirs >> "$LOG_FILE" 2>&1
                fi
                if [ -f "${BACKUP_DIR}/.full_backup" ]; then
                    curl -T "${BACKUP_DIR}/.full_backup" "ftp://${FTP_SERVER}/backup_${TIMESTAMP}/.full_backup" --user "${FTP_USER}:${FTP_PASSWORD}" --create-dirs >> "$LOG_FILE" 2>&1
                fi
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
                rsync -avz $SSH_OPTS "$BACKUP_FILE" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}/$(basename "$BACKUP_FILE")" >> "$LOG_FILE" 2>&1
                
                # Also upload metadata files for incremental backups
                if [ -f "${BACKUP_DIR}/.incremental_backup" ]; then
                    rsync -avz $SSH_OPTS "${BACKUP_DIR}/.incremental_backup" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}/backup_${TIMESTAMP}/.incremental_backup" >> "$LOG_FILE" 2>&1
                fi
                if [ -f "${BACKUP_DIR}/.full_backup" ]; then
                    rsync -avz $SSH_OPTS "${BACKUP_DIR}/.full_backup" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}/backup_${TIMESTAMP}/.full_backup" >> "$LOG_FILE" 2>&1
                fi
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
    
    # Special handling for incremental backups
    if [ "$ENABLE_INCREMENTAL" = true ]; then
        # First, identify full backups to delete
        find "${DESTINATION_DIR}" -type f -name ".full_backup" -mtime +${BACKUP_RETENTION_DAYS} | while read full_backup_marker; do
            FULL_DIR=$(dirname "$full_backup_marker")
            FULL_BASENAME=$(basename "$FULL_DIR")
            
            log "Found old full backup: $FULL_DIR"
            
            # Find all incremental backups associated with this full backup
            find "${DESTINATION_DIR}" -type f -name ".incremental_backup" | xargs grep -l "$FULL_BASENAME" 2>/dev/null | while read inc_backup_ref; do
                INC_DIR=$(dirname "$inc_backup_ref")
                log "Removing incremental backup dependent on old full backup: $INC_DIR"
                rm -rf "$INC_DIR" >> "$LOG_FILE" 2>&1
            done
            
            # Now remove the full backup itself
            log "Removing old full backup: $FULL_DIR"
            rm -rf "$FULL_DIR" >> "$LOG_FILE" 2>&1
        done
        
        # Now handle orphaned incremental backups (whose full backup no longer exists)
        find "${DESTINATION_DIR}" -type f -name ".incremental_backup" | while read inc_backup_ref; do
            FULL_BASENAME=$(cat "$inc_backup_ref")
            if [ ! -d "${DESTINATION_DIR}/${FULL_BASENAME}" ]; then
                INC_DIR=$(dirname "$inc_backup_ref")
                log "Removing orphaned incremental backup: $INC_DIR"
                rm -rf "$INC_DIR" >> "$LOG_FILE" 2>&1
            fi
        done
        
        # Finally, remove any incremental backups older than retention period
        find "${DESTINATION_DIR}" -type f -name ".incremental_backup" -mtime +${BACKUP_RETENTION_DAYS} | while read inc_backup_marker; do
            INC_DIR=$(dirname "$inc_backup_marker")
            log "Removing old incremental backup: $INC_DIR"
            rm -rf "$INC_DIR" >> "$LOG_FILE" 2>&1
        done
    else
        # Traditional cleanup for regular backups
        find "${DESTINATION_DIR}" -type d -name "backup_*" -mtime +${BACKUP_RETENTION_DAYS} | while read old_backup; do
            log "Removing old backup: $old_backup"
            rm -rf "$old_backup" >> "$LOG_FILE" 2>&1
        done
    fi
    
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
    
    # Add incremental backup info if applicable
    if [ "$ENABLE_INCREMENTAL" = true ]; then
        if [ -f "${BACKUP_DIR}/.full_backup" ]; then
            message+="Backup type: FULL\n"
        elif [ -f "${BACKUP_DIR}/.incremental_backup" ]; then
            message+="Backup type: INCREMENTAL\n"
            message+="Reference full backup: $(cat ${BACKUP_DIR}/.incremental_backup)\n"
            
            if [ -f "${BACKUP_DIR}/changed_files.txt" ]; then
                message+="Changed files: $(wc -l < ${BACKUP_DIR}/changed_files.txt)\n"
            fi
        fi
    fi
    
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
    
    # Add incremental backup info if applicable
    if [ "$ENABLE_INCREMENTAL" = true ]; then
        if [ -f "${BACKUP_DIR}/.full_backup" ]; then
            message+="Type: FULL%0A"
        elif [ -f "${BACKUP_DIR}/.incremental_backup" ]; then
            message+="Type: INCREMENTAL%0A"
            
            if [ -f "${BACKUP_DIR}/changed_files.txt" ]; then
                message+="Changes: $(wc -l < ${BACKUP_DIR}/changed_files.txt) files%0A"
            fi
        fi
    fi
    
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

# Function to restore from backup
restore_from_backup() {
    if [ -z "$1" ]; then
        log "Error: No backup specified for restore."
        return 1
    fi
    
    local restore_dir="$1"
    local target_dir="${2:-$SOURCE_DIR}"
    
    if [ ! -d "$restore_dir" ]; then
        log "Error: Backup directory '$restore_dir' does not exist."
        return 1
    fi
    
    log "Starting restore from: $restore_dir to: $target_dir"
    
    # Check if this is an incremental backup
    if [ -f "${restore_dir}/.incremental_backup" ]; then
        log "This is an incremental backup. Need to restore full backup first."
        
        local full_backup_name=$(cat "${restore_dir}/.incremental_backup")
        local full_backup_dir="${DESTINATION_DIR}/${full_backup_name}"
        
        if [ ! -d "$full_backup_dir" ]; then
            log "Error: Referenced full backup '$full_backup_dir' not found. Cannot restore."
            return 1
        fi
        
        # First restore the full backup
        log "Restoring base full backup: $full_backup_dir"
        restore_from_backup "$full_backup_dir" "$target_dir"
        
        # Find all incremental backups between the full backup and the target one
        # Sort them by creation time to apply in the correct order
        local incremental_chain=()
        local found_target=false
        
        find "${DESTINATION_DIR}" -type f -name ".incremental_backup" | 
            xargs grep -l "$full_backup_name" 2>/dev/null | 
            while read inc_file; do
                inc_dir=$(dirname "$inc_file")
                # Skip if it's the target backup (we'll apply it later)
                if [ "$inc_dir" = "$restore_dir" ]; then
                    found_target=true
                    continue
                fi
                
                # Add to array if creation time is earlier than target
                if [ "$(stat -c %Y "$inc_dir")" -lt "$(stat -c %Y "$restore_dir")" ]; then
                    incremental_chain+=("$inc_dir")
                fi
            done
        
        # Sort the incremental backups by timestamp
        IFS=$'\n' incremental_chain=($(sort -k1 <<<"${incremental_chain[*]}"))
        unset IFS
        
        # Apply each incremental backup in order
        for inc_backup in "${incremental_chain[@]}"; do
            log "Applying intermediate incremental backup: $inc_backup"
            
            if [ "$ENABLE_COMPRESSION" = true ]; then
                # Find the compressed backup file
                inc_file=$(find "$inc_backup" -name "*.tar.gz" -type f)
                
                if [ -n "$inc_file" ] && [ -s "$inc_file" ]; then
                    log "Extracting: $inc_file"
                    tar -xzf "$inc_file" -C "$target_dir" >> "$LOG_FILE" 2>&1
                else
                    log "Skipping empty incremental backup: $inc_backup"
                fi
            else
                # Rsync from the incremental backup
                if [ -d "${inc_backup}/data" ]; then
                    log "Rsync from: ${inc_backup}/data/"
                    rsync -aAX --delete "${inc_backup}/data/" "$target_dir/" >> "$LOG_FILE" 2>&1
                fi
            fi
        done
    fi
    
    # Now apply the target backup itself
    if [ "$ENABLE_COMPRESSION" = true ]; then
        # Find the compressed backup file
        backup_file=$(find "$restore_dir" -name "*.tar.gz" -type f)
        
        if [ -n "$backup_file" ]; then
            log "Extracting: $backup_file"
            
            # For full backups, we might need to handle the path differently
            if [ -f "${restore_dir}/.full_backup" ]; then
                # Full backups usually contain the parent path, so restore to parent of target
                target_parent=$(dirname "$target_dir")
                tar -xzf "$backup_file" -C "$target_parent" >> "$LOG_FILE" 2>&1
            else
                # Incremental backups usually contain just the files, restore directly
                tar -xzf "$backup_file" -C "$target_dir" >> "$LOG_FILE" 2>&1
            fi
        else
            log "No backup file found in: $restore_dir"
            if [ ! -f "${restore_dir}/.incremental_backup" ]; then
                return 1
            fi
        fi
    else
        if [ -d "${restore_dir}/data" ]; then
            log "Rsync from: ${restore_dir}/data/"
            rsync -aAX --delete "${restore_dir}/data/" "$target_dir/" >> "$LOG_FILE" 2>&1
        else
            log "No data directory found in: $restore_dir"
            return 1
        fi
    fi
    
    log "Restore completed successfully."
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

# Check for restore mode
if [ "$1" = "restore" ]; then
    if [ -z "$2" ]; then
        echo "Error: Backup directory to restore from must be specified."
        echo "Usage: $0 restore <backup_directory> [target_directory]"
        exit 1
    fi
    
    restore_from_backup "$2" "$3"
    exit $?
fi

# Run the script
main