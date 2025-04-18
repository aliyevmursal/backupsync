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
#   - Database backup support (MySQL, PostgreSQL, MSSQL)
#   - Advanced backup features
#   - Security enhancements
#   - Disk space monitoring
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

# Database backup settings
ENABLE_DATABASE_BACKUP="${ENABLE_DATABASE_BACKUP:-false}"
DATABASE_TYPE="${DATABASE_TYPE:-mysql}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAMES="${DB_NAMES:-}"

# MSSQL specific settings
MSSQL_AUTH_TYPE="${MSSQL_AUTH_TYPE:-sql}"
MSSQL_INSTANCE="${MSSQL_INSTANCE:-}"
MSSQL_BACKUP_TYPE="${MSSQL_BACKUP_TYPE:-full}"

# Advanced backup settings
FILE_EXCLUSION_PATTERNS="${FILE_EXCLUSION_PATTERNS:-}"
ENABLE_DEDUPLICATION="${ENABLE_DEDUPLICATION:-false}"

# Security settings
ENABLE_ENCRYPTION="${ENABLE_ENCRYPTION:-false}"
ENCRYPTION_PASSWORD="${ENCRYPTION_PASSWORD:-}"
ENABLE_BACKUP_VERIFICATION="${ENABLE_BACKUP_VERIFICATION:-true}"

# Disk space settings
MIN_DISK_SPACE_MB="${MIN_DISK_SPACE_MB:-1024}" # Minimum free space in MB

# Create log directory
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"
ERROR_LOG_FILE="${LOG_DIR}/backup_error_${TIMESTAMP}.log"

# Backup status
BACKUP_STATUS="success"
ERROR_MESSAGE=""

# Function to log messages
log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Function to log errors
log_error() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    BACKUP_STATUS="failed"
    ERROR_MESSAGE="${ERROR_MESSAGE}${message}\n"
    echo "[$timestamp] ERROR: $message" | tee -a "$LOG_FILE" | tee -a "$ERROR_LOG_FILE"
}

# Function to check disk space
check_disk_space() {
    local dir="$1"
    local min_space_mb="$2"
    
    log "Checking disk space for directory: $dir"
    
    # Get available space in KB
    local available_kb=$(df -k "$dir" | awk 'NR==2 {print $4}')
    local available_mb=$((available_kb / 1024))
    local total_kb=$(df -k "$dir" | awk 'NR==2 {print $2}')
    local total_mb=$((total_kb / 1024))
    local used_kb=$(df -k "$dir" | awk 'NR==2 {print $3}')
    local used_mb=$((used_kb / 1024))
    local used_percent=$(df -k "$dir" | awk 'NR==2 {print $5}')
    
    # Store disk space info globally for notifications
    DISK_SPACE_INFO="Total: ${total_mb} MB | Used: ${used_mb} MB (${used_percent}) | Available: ${available_mb} MB"
    
    log "Disk space: $DISK_SPACE_INFO"
    
    if [ "$available_mb" -lt "$min_space_mb" ]; then
        log_error "Insufficient disk space on $dir. Available: $available_mb MB, Required: $min_space_mb MB"
        return 1
    fi
    
    log "Sufficient disk space available."
    return 0
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
    
    # Database backup requirements
    if [ "$ENABLE_DATABASE_BACKUP" = true ]; then
        case "$DATABASE_TYPE" in
            mysql)
                required_commands+=("mysqldump" "mysql")
                ;;
            postgresql)
                required_commands+=("pg_dump" "psql")
                ;;
            mssql)
                required_commands+=("sqlcmd")
                ;;
        esac
    fi
    
    # Security requirements
    if [ "$ENABLE_ENCRYPTION" = true ]; then
        required_commands+=("openssl")
    fi
    
    if [ "$ENABLE_BACKUP_VERIFICATION" = true ]; then
        required_commands+=("sha256sum")
    fi
    
    if [ "$ENABLE_DEDUPLICATION" = true ]; then
        required_commands+=("sha256sum" "ln")
    fi
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command '$cmd' not found. Please install it and try again."
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
        log_error "Failed to create backup directory at $BACKUP_DIR"
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

# Function to apply file exclusion patterns
apply_exclusion_patterns() {
    local source_dir="$1"
    local exclusion_options=""
    
    if [ -z "$FILE_EXCLUSION_PATTERNS" ]; then
        echo "$exclusion_options"
        return 0
    fi
    
    # Split comma-separated patterns
    IFS=',' read -ra PATTERNS <<< "$FILE_EXCLUSION_PATTERNS"
    
    for pattern in "${PATTERNS[@]}"; do
        # Add rsync compatible exclusion option
        exclusion_options="$exclusion_options --exclude='$pattern'"
    done
    
    echo "$exclusion_options"
}

# Function to setup deduplication
setup_deduplication() {
    if [ "$ENABLE_DEDUPLICATION" != true ]; then
        return 0
    fi
    
    log "Setting up deduplication..."
    
    # Deduplication directory
    DEDUP_DIR="${DESTINATION_DIR}/.deduplication"
    mkdir -p "$DEDUP_DIR/objects"
    
    # Hash database file path
    DEDUP_DB="${DEDUP_DIR}/hashes.db"
    
    # Create database if it doesn't exist
    if [ ! -f "$DEDUP_DB" ]; then
        touch "$DEDUP_DB"
    fi
    
    log "Deduplication setup completed: $DEDUP_DIR"
    return 0
}

# Function for file deduplication
deduplicate_file() {
    if [ "$ENABLE_DEDUPLICATION" != true ]; then
        return 0
    fi
    
    local file_path="$1"
    local rel_path="${file_path#$SOURCE_DIR/}"
    
    # Calculate file hash
    local file_hash=$(sha256sum "$file_path" | awk '{print $1}')
    
    # Object file path
    local obj_path="${DEDUP_DIR}/objects/${file_hash}"
    
    # Check hash database
    if grep -q "^${file_hash}:" "$DEDUP_DB"; then
        # Hash already exists, create hardlink
        ln -f "$obj_path" "${BACKUP_DIR}/data/${rel_path}" 2>> "$LOG_FILE"
        return 0
    else
        # New hash, create object and add to database
        cp -a "$file_path" "$obj_path" 2>> "$LOG_FILE"
        ln -f "$obj_path" "${BACKUP_DIR}/data/${rel_path}" 2>> "$LOG_FILE"
        echo "${file_hash}:${rel_path}" >> "$DEDUP_DB"
        return 0
    fi
}

# File encryption function
encrypt_file() {
    if [ "$ENABLE_ENCRYPTION" != true ]; then
        return 0
    fi
    
    local file_path="$1"
    log "Encrypting file: $file_path"
    
    # Generate salt for encryption
    local salt=$(openssl rand -hex 8)
    
    # Encryption
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 \
        -in "$file_path" \
        -out "${file_path}.enc" \
        -pass pass:"$ENCRYPTION_PASSWORD" \
        -S "$salt" 2>> "$LOG_FILE"
    
    if [ $? -ne 0 ]; then
        log_error "Encryption failed: $file_path"
        return 1
    fi
    
    # Remove original file and rename encrypted file
    rm "$file_path"
    mv "${file_path}.enc" "$file_path"
    
    # Add salt to file header
    echo "$salt" > "${file_path}.salt"
    
    log "File encryption completed: $file_path"
    return 0
}

# File decryption function (for restore)
decrypt_file() {
    if [ "$ENABLE_ENCRYPTION" != true ]; then
        return 0
    fi
    
    local file_path="$1"
    local output_path="$2"
    log "Decrypting file: $file_path"
    
    # Read salt file
    if [ ! -f "${file_path}.salt" ]; then
        log_error "Salt file not found: ${file_path}.salt"
        return 1
    fi
    
    local salt=$(cat "${file_path}.salt")
    
    # Decryption
    openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 10000 \
        -in "$file_path" \
        -out "$output_path" \
        -pass pass:"$ENCRYPTION_PASSWORD" \
        -S "$salt" 2>> "$LOG_FILE"
    
    if [ $? -ne 0 ]; then
        log_error "Decryption failed: $file_path"
        return 1
    fi
    
    log "File decryption completed: $file_path"
    return 0
}

# File verification function
verify_file() {
    if [ "$ENABLE_BACKUP_VERIFICATION" != true ]; then
        return 0
    fi
    
    local file_path="$1"
    log "Verifying file: $file_path"
    
    # Calculate SHA256 hash
    local file_hash=$(sha256sum "$file_path" | awk '{print $1}')
    
    # Write hash to file
    echo "$file_hash" > "${file_path}.sha256"
    
    log "File verification completed: $file_path"
    return 0
}

# Backup verification check
verify_backup_integrity() {
    if [ "$ENABLE_BACKUP_VERIFICATION" != true ]; then
        return 0
    fi
    
    log "Starting backup integrity check..."
    
    local failed_count=0
    
    # Find all hash files and verify
    find "$BACKUP_DIR" -name "*.sha256" | while read hash_file; do
        original_file="${hash_file%.sha256}"
        expected_hash=$(cat "$hash_file")
        
        # Check if original file exists
        if [ ! -f "$original_file" ]; then
            log_error "File to verify not found: $original_file"
            failed_count=$((failed_count + 1))
            continue
        fi
        
        # Calculate and compare hash
        actual_hash=$(sha256sum "$original_file" | awk '{print $1}')
        
        if [ "$expected_hash" != "$actual_hash" ]; then
            log_error "File integrity error: $original_file"
            log_error "  Expected: $expected_hash"
            log_error "  Actual: $actual_hash"
            failed_count=$((failed_count + 1))
        fi
    done
    
    if [ $failed_count -eq 0 ]; then
        log "Backup integrity check completed successfully."
    else
        log_error "Backup integrity check completed with $failed_count errors."
    fi
    
    return $failed_count
}

# MySQL/MariaDB Backup Function
backup_mysql() {
    if [ "$ENABLE_DATABASE_BACKUP" != true ] || [ "$DATABASE_TYPE" != "mysql" ]; then
        return 0
    fi
    
    log "Starting MySQL/MariaDB database backup..."
    
    # Create database directory
    DB_BACKUP_DIR="${BACKUP_DIR}/databases/mysql"
    mkdir -p "$DB_BACKUP_DIR"
    
    # Backup options
    MYSQLDUMP_OPTIONS="--single-transaction --routines --triggers --events"
    
    # Determine databases to backup
    if [ -z "$DB_NAMES" ]; then
        # Get all databases (exclude system dbs)
        DBS=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys")
    else
        # Get specified databases
        DBS=$(echo "$DB_NAMES" | tr ',' ' ')
    fi
    
    # Backup each database separately
    for db in $DBS; do
        log "Backing up MySQL database: $db"
        
        DB_FILE="${DB_BACKUP_DIR}/${db}_${TIMESTAMP}.sql"
        
        # Create database backup
        mysqldump $MYSQLDUMP_OPTIONS -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$db" > "$DB_FILE" 2>> "$LOG_FILE"
        
        if [ $? -ne 0 ]; then
            log_error "Failed to backup database $db."
            continue
        fi
        
        # Compress backup
        if [ "$ENABLE_COMPRESSION" = true ]; then
            log "Compressing database backup: $db"
            gzip -f "$DB_FILE"
            DB_FILE="${DB_FILE}.gz"
        fi
        
        # Encryption
        if [ "$ENABLE_ENCRYPTION" = true ]; then
            encrypt_file "$DB_FILE"
        fi
        
        # Verification
        if [ "$ENABLE_BACKUP_VERIFICATION" = true ]; then
            verify_file "$DB_FILE"
        fi
        
        log "Database backup completed: $db"
    done
    
    log "MySQL/MariaDB database backup completed."
    return 0
}

# PostgreSQL Backup Function
backup_postgresql() {
    if [ "$ENABLE_DATABASE_BACKUP" != true ] || [ "$DATABASE_TYPE" != "postgresql" ]; then
        return 0
    fi
    
    log "Starting PostgreSQL database backup..."
    
    # Create database directory
    DB_BACKUP_DIR="${BACKUP_DIR}/databases/postgresql"
    mkdir -p "$DB_BACKUP_DIR"
    
    # Set environment variables
    export PGHOST="$DB_HOST"
    export PGPORT="$DB_PORT"
    export PGUSER="$DB_USER"
    export PGPASSWORD="$DB_PASSWORD"
    
    # Determine databases to backup
    if [ -z "$DB_NAMES" ]; then
        # Get all databases (exclude template and postgres)
        DBS=$(psql -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres')" postgres)
    else
        # Get specified databases
        DBS=$(echo "$DB_NAMES" | tr ',' ' ')
    fi
    
    # Backup each database separately
    for db in $DBS; do
        db=$(echo "$db" | tr -d ' ')
        if [ -z "$db" ]; then
            continue
        fi
        
        log "Backing up PostgreSQL database: $db"
        
        DB_FILE="${DB_BACKUP_DIR}/${db}_${TIMESTAMP}.sql"
        
        # Create database backup (custom format)
        pg_dump -Fc "$db" > "$DB_FILE" 2>> "$LOG_FILE"
        
        if [ $? -ne 0 ]; then
            log_error "Failed to backup database $db."
            continue
        fi
        
        # No need for compression as pg_dump -Fc custom format is already compressed
        
        # Encryption
        if [ "$ENABLE_ENCRYPTION" = true ]; then
            encrypt_file "$DB_FILE"
        fi
        
        # Verification
        if [ "$ENABLE_BACKUP_VERIFICATION" = true ]; then
            verify_file "$DB_FILE"
        fi
        
        log "Database backup completed: $db"
    done
    
    # Clean environment variables
    unset PGHOST PGPORT PGUSER PGPASSWORD
    
    log "PostgreSQL database backup completed."
    return 0
}

# Microsoft SQL Server Backup Function
backup_mssql() {
    if [ "$ENABLE_DATABASE_BACKUP" != true ] || [ "$DATABASE_TYPE" != "mssql" ]; then
        return 0
    fi
    
    log "Starting Microsoft SQL Server database backup..."
    
    # Create database directory
    DB_BACKUP_DIR="${BACKUP_DIR}/databases/mssql"
    mkdir -p "$DB_BACKUP_DIR"
    
    # Build the server instance string
    if [ -n "$MSSQL_INSTANCE" ]; then
        # Use named instance
        SERVER_INSTANCE="$DB_HOST\\$MSSQL_INSTANCE"
    else
        # Use default instance with port
        SERVER_INSTANCE="$DB_HOST,$DB_PORT"
    fi
    
    # Build the authentication arguments
    if [ "$MSSQL_AUTH_TYPE" = "windows" ]; then
        # Windows authentication
        AUTH_ARGS="-E"
    else
        # SQL Server authentication
        AUTH_ARGS="-U $DB_USER -P $DB_PASSWORD"
    fi
    
    # Determine databases to backup
    if [ -z "$DB_NAMES" ]; then
        # Get all user databases (exclude system dbs)
        DBS=$(sqlcmd -S "$SERVER_INSTANCE" $AUTH_ARGS -h-1 -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE database_id > 4;" | grep -v "[-]")
    else
        # Get specified databases
        DBS=$(echo "$DB_NAMES" | tr ',' ' ')
    fi
    
    # Backup each database separately
    for db in $DBS; do
        db=$(echo "$db" | tr -d ' ')
        if [ -z "$db" ]; then
            continue
        fi
        
        log "Backing up MSSQL database: $db"
        
        # Define backup file path
        DB_BAK_FILE="${DB_BACKUP_DIR}/${db}_${TIMESTAMP}.bak"
        
        # Determine backup type (FULL, DIFFERENTIAL, LOG)
        case "$MSSQL_BACKUP_TYPE" in
            full)
                BACKUP_TYPE="FULL"
                ;;
            differential)
                BACKUP_TYPE="DIFFERENTIAL"
                ;;
            log)
                BACKUP_TYPE="LOG"
                ;;
            *)
                log_error "Unknown MSSQL backup type: $MSSQL_BACKUP_TYPE. Using FULL."
                BACKUP_TYPE="FULL"
                ;;
        esac
        
        # Build and execute the backup command
        BACKUP_QUERY="BACKUP DATABASE [$db] TO DISK='$DB_BAK_FILE' WITH $BACKUP_TYPE, INIT, STATS=10"
        if [ "$BACKUP_TYPE" = "LOG" ]; then
            BACKUP_QUERY="BACKUP LOG [$db] TO DISK='$DB_BAK_FILE' WITH INIT, STATS=10"
        fi
        
        log "Executing SQL Server backup: $BACKUP_QUERY"
        sqlcmd -S "$SERVER_INSTANCE" $AUTH_ARGS -Q "$BACKUP_QUERY" >> "$LOG_FILE" 2>&1
        
        if [ $? -ne 0 ]; then
            log_error "Failed to backup SQL Server database $db."
            continue
        fi
        
        # Compress backup (BAK files are binary but can still be compressed)
        if [ "$ENABLE_COMPRESSION" = true ]; then
            log "Compressing database backup: $db"
            gzip -f "$DB_BAK_FILE"
            DB_BAK_FILE="${DB_BAK_FILE}.gz"
        fi
        
        # Encryption
        if [ "$ENABLE_ENCRYPTION" = true ]; then
            encrypt_file "$DB_BAK_FILE"
        fi
        
        # Verification
        if [ "$ENABLE_BACKUP_VERIFICATION" = true ]; then
            verify_file "$DB_BAK_FILE"
        fi
        
        log "SQL Server database backup completed: $db"
    done
    
    log "Microsoft SQL Server database backup completed."
    return 0
}

# Function to perform backup
perform_backup() {
    log "Starting backup process..."
    
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Source directory '$SOURCE_DIR' does not exist."
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
    
    # Setup file exclusion patterns
    if [ -n "$FILE_EXCLUSION_PATTERNS" ]; then
        log "Applying file exclusion patterns: $FILE_EXCLUSION_PATTERNS"
        EXCLUSION_OPTIONS=$(apply_exclusion_patterns "$SOURCE_DIR")
    else
        EXCLUSION_OPTIONS=""
    fi
    
    # Setup deduplication if enabled
    if [ "$ENABLE_DEDUPLICATION" = true ]; then
        setup_deduplication
    fi
    
    if [ "$ENABLE_COMPRESSION" = true ]; then
        log "Creating compressed $BACKUP_TYPE backup..."
        
        if [ "$BACKUP_TYPE" = "full" ]; then
            BACKUP_FILE="${BACKUP_DIR}/backup_full_${TIMESTAMP}.tar.gz"
            
            # Apply exclusion patterns if any
            BACKUP_CMD="tar -czf \"$BACKUP_FILE\" -C \"$(dirname \"$SOURCE_DIR\")\" \"$(basename \"$SOURCE_DIR\")\""
            if [ -n "$EXCLUSION_OPTIONS" ]; then
                BACKUP_CMD="tar -czf \"$BACKUP_FILE\" $EXCLUSION_OPTIONS -C \"$(dirname \"$SOURCE_DIR\")\" \"$(basename \"$SOURCE_DIR\")\""
            fi
            
            eval $BACKUP_CMD 2>> "$LOG_FILE"
            
            if [ $? -ne 0 ]; then
                log_error "Compression failed."
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
            
            # Apply exclusion patterns if any
            if [ -n "$EXCLUSION_OPTIONS" ]; then
                # Filter out excluded files
                TEMP_FILE="${BACKUP_DIR}/temp_changed_files.txt"
                cat "${BACKUP_DIR}/changed_files.txt" | grep -v -f "$EXCLUSION_OPTIONS" > "$TEMP_FILE"
                mv "$TEMP_FILE" "${BACKUP_DIR}/changed_files.txt"
            fi
            
            # If there are changed files, create the incremental backup
            if [ -s "${BACKUP_DIR}/changed_files.txt" ]; then
                tar -czf "$BACKUP_FILE" -T "${BACKUP_DIR}/changed_files.txt" 2>> "$LOG_FILE"
                
                if [ $? -ne 0 ]; then
                    log_error "Incremental compression failed."
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
            # Apply exclusion patterns if any
            RSYNC_CMD="rsync -aAXv --delete $EXCLUSION_OPTIONS \"$SOURCE_DIR/\" \"$BACKUP_DIR/data/\""
            
            eval $RSYNC_CMD >> "$LOG_FILE" 2>&1
            
            if [ $? -ne 0 ]; then
                log_error "Rsync backup failed."
                exit 1
            fi
            
            # Apply deduplication if enabled
            if [ "$ENABLE_DEDUPLICATION" = true ]; then
                log "Applying deduplication..."
                find "$BACKUP_DIR/data" -type f | while read file; do
                    deduplicate_file "$file"
                done
                log "Deduplication completed."
            fi
            
            # Mark as full backup
            touch "${BACKUP_DIR}/.full_backup"
            
            log "Full rsync backup completed to: $BACKUP_DIR"
        else
            # For uncompressed incremental, use rsync with link-dest to previous backup
            RSYNC_CMD="rsync -aAXv --delete $EXCLUSION_OPTIONS --link-dest=\"$LAST_BACKUP_REF/data/\" \"$SOURCE_DIR/\" \"$BACKUP_DIR/data/\""
            
            eval $RSYNC_CMD >> "$LOG_FILE" 2>&1
            
            if [ $? -ne 0 ]; then
                log_error "Incremental rsync backup failed."
                exit 1
            fi
            
            # Store reference to full backup
            echo "$(basename "$FULL_BACKUP_REF")" > "${BACKUP_DIR}/.incremental_backup"
            
            log "Incremental rsync backup completed to: $BACKUP_DIR"
        fi
    fi
    
    # Process database backups if enabled
    if [ "$ENABLE_DATABASE_BACKUP" = true ]; then
        case "$DATABASE_TYPE" in
            mysql)
                backup_mysql
                ;;
            postgresql)
                backup_postgresql
                ;;
            mssql)
                backup_mssql
                ;;
            *)
                log_error "Unsupported database type: $DATABASE_TYPE"
                ;;
        esac
    fi
    
    # Backup verification if enabled
    if [ "$ENABLE_BACKUP_VERIFICATION" = true ]; then
        verify_backup_integrity
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
                log_error "AWS S3 bucket not specified."
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
                log_error "AWS S3 upload failed."
                return 1
            fi
            ;;
            
        ftp)
            if [ -z "$FTP_SERVER" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASSWORD" ]; then
                log_error "FTP credentials not specified."
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
                log_error "FTP upload failed."
                return 1
            fi
            ;;
            
        rsync_ssh)
            if [ -z "$REMOTE_SERVER" ] || [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_PATH" ]; then
                log_error "Remote server details not specified."
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
                log_error "Remote server upload failed."
                return 1
            fi
            ;;
            
        none)
            log "No cloud provider selected. Skipping cloud backup."
            ;;
            
        *)
            log_error "Unknown cloud provider '$CLOUD_PROVIDER'."
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
        log_error "Email recipient not specified."
        return 1
    fi
    
    log "Sending email notification to $EMAIL_RECIPIENT..."
    
    local subject="Backup ${BACKUP_STATUS^^} - $(hostname) - ${TIMESTAMP}"
    local message="Backup of ${SOURCE_DIR} ${BACKUP_STATUS} on $(date).\n\n"
    
    # Add disk space information
    if [ -n "$DISK_SPACE_INFO" ]; then
        message+="Disk Space Information:\n${DISK_SPACE_INFO}\n\n"
    fi
    
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
    
    # Add error information if backup failed
    if [ "$BACKUP_STATUS" = "failed" ]; then
        message+="ERROR DETAILS:\n${ERROR_MESSAGE}\n\n"
    fi
    
    message+="BackupSync by Mursal Aliyev"
    
    echo -e "$message" | mail -s "$subject" "$EMAIL_RECIPIENT"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to send email notification."
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
        log_error "Telegram credentials not specified."
        return 1
    fi
    
    log "Sending Telegram notification..."
    
    local status_emoji="✅"
    if [ "$BACKUP_STATUS" = "failed" ]; then
        status_emoji="❌"
    fi
    
    local message="Backup ${BACKUP_STATUS^^} ${status_emoji}%0A"
    message+="Host: $(hostname)%0A"
    message+="Time: $(date)%0A"
    
    # Add disk space information
    if [ -n "$DISK_SPACE_INFO" ]; then
        message+="Disk Space: ${DISK_SPACE_INFO}%0A%0A"
    fi
    
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
    
    # Add error information if backup failed
    if [ "$BACKUP_STATUS" = "failed" ]; then
        message+="%0A%0AERROR DETAILS:%0A${ERROR_MESSAGE}"
    fi
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log_error "Failed to send Telegram notification."
        return 1
    fi
    
    log "Telegram notification sent successfully."
    return 0
}

# Function to restore from backup
restore_from_backup() {
    if [ -z "$1" ]; then
        log_error "No backup specified for restore."
        return 1
    fi
    
    local restore_dir="$1"
    local target_dir="${2:-$SOURCE_DIR}"
    
    if [ ! -d "$restore_dir" ]; then
        log_error "Backup directory '$restore_dir' does not exist."
        return 1
    fi
    
    log "Starting restore from: $restore_dir to: $target_dir"
    
    # Check if this is an incremental backup
    if [ -f "${restore_dir}/.incremental_backup" ]; then
        log "This is an incremental backup. Need to restore full backup first."
        
        local full_backup_name=$(cat "${restore_dir}/.incremental_backup")
        local full_backup_dir="${DESTINATION_DIR}/${full_backup_name}"
        
        if [ ! -d "$full_backup_dir" ]; then
            log_error "Referenced full backup '$full_backup_dir' not found. Cannot restore."
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
    
    # Restore from encrypted backups
    if [ "$ENABLE_ENCRYPTION" = true ]; then
        log "Decrypting encrypted files..."
        
        find "$target_dir" -type f -not -path "*/\.*" | while read file; do
            if [ -f "${file}.salt" ]; then
                # This file is encrypted
                log "Encrypted file found: $file"
                local temp_file="${file}.decrypted"
                
                decrypt_file "$file" "$temp_file"
                
                if [ $? -eq 0 ]; then
                    mv "$temp_file" "$file"
                    rm "${file}.salt"
                else
                    log_error "Could not decrypt file: $file"
                fi
            fi
        done
    fi
    
    # Backup integrity check
    if [ "$ENABLE_BACKUP_VERIFICATION" = true ]; then
        log "Verifying integrity of restored files..."
        
        find "$target_dir" -name "*.sha256" | while read hash_file; do
            original_file="${hash_file%.sha256}"
            expected_hash=$(cat "$hash_file")
            
            # Calculate and compare hash
            actual_hash=$(sha256sum "$original_file" | awk '{print $1}')
            
            if [ "$expected_hash" != "$actual_hash" ]; then
                log_error "Restored file integrity error: $original_file"
            else
                # Remove verification file
                rm "$hash_file"
            fi
        done
    fi
    
    log "Restore completed successfully."
    return 0
}

# Main execution
main() {
    log "BackupSync started"
    
    # Check disk space before proceeding
    check_disk_space "$DESTINATION_DIR" "$MIN_DISK_SPACE_MB"
    if [ $? -ne 0 ]; then
        log_error "Insufficient disk space. Backup aborted."
        send_email_notification
        send_telegram_notification
        exit 1
    fi
    
    check_requirements
    create_backup_dir
    perform_backup
    upload_to_cloud
    cleanup_old_backups
    send_email_notification
    send_telegram_notification
    
    if [ "$BACKUP_STATUS" = "success" ]; then
        log "BackupSync completed successfully"
        exit 0
    else
        log "BackupSync completed with errors"
        exit 1
    fi
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