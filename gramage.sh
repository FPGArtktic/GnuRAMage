#!/bin/bash
# GnuRAMage: Advanced RAM Disk Synchronization Tool
# Version: 1.0.0
#
# Copyright (C) 2025 Mateusz Okulanis
# Email: FPGArtktic@outlook.com
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Default values
CONFIG_FILE="GnuRAMage.ini"
DRY_RUN=false
VERBOSE=false
LOGS_FILE=""
ERRORS_LOG_FILE=""
SCRIPT_GEN_ONLY=false
ONE_TIME_MODE=false
SYNC_INTERVAL=180  # Default sync interval in seconds (3 minutes)
LOG_LEVEL="INFO"   # Default log level: ERROR, WARN, INFO, DEBUG
VERIFY_CHECKSUMS=false
DEFAULT_SOURCE_DIR=""
DEFAULT_RAMDISK_DIR=""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# File paths for generated scripts
RSYNC_SCRIPT="${SCRIPT_DIR}/gramage_sync_to_disk.sh"
CP_SCRIPT="${SCRIPT_DIR}/gramage_copy_to_ram.sh"

# Statistics for report
TOTAL_FILES_COPIED=0
TOTAL_FILES_SYNCED=0
START_TIME=$(date +%s)

# Variables for cleanup
CLEANUP_NEEDED=false
TRAP_REGISTERED=false

# Print usage information
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "GnuRAMage: Advanced RAM Disk Synchronization Tool"
    echo ""
    echo "Options:"
    echo "  --config <file>     Path to the configuration file (default: GnuRAMage.ini)"
    echo "  --dry-run           Simulate operations without actually copying/syncing files"
    echo "  --verbose, -v       Display more detailed information about operations"
    echo "  --logs <file>       Write logs to the specified file (TXT or JSON)"
    echo "  --errors-log <file> Write error logs to the specified file (TXT or JSON)"
    echo "  --script-gen-only   Generate scripts only, don't start synchronization"
    echo "  --one-time          Run only one synchronization cycle (no loop)"
    echo "  --help              Display this help message and exit"
    echo ""
}

# Log levels
LOG_LEVEL_ERROR=0
LOG_LEVEL_WARN=1
LOG_LEVEL_INFO=2
LOG_LEVEL_DEBUG=3

# Function to convert log level string to numeric value
get_log_level_value() {
    case "$1" in
        "ERROR") echo $LOG_LEVEL_ERROR ;;
        "WARN")  echo $LOG_LEVEL_WARN ;;
        "INFO")  echo $LOG_LEVEL_INFO ;;
        "DEBUG") echo $LOG_LEVEL_DEBUG ;;
        *)       echo $LOG_LEVEL_INFO ;;  # Default to INFO
    esac
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --logs)
                LOGS_FILE="$2"
                shift 2
                ;;
            --errors-log)
                ERRORS_LOG_FILE="$2"
                shift 2
                ;;
            --script-gen-only)
                SCRIPT_GEN_ONLY=true
                shift
                ;;
            --one-time)
                ONE_TIME_MODE=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log function with levels
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)
    local numeric_level=$(get_log_level_value "$level")
    local current_level=$(get_log_level_value "$LOG_LEVEL")
    
    # Only log if the message level is less than or equal to the current log level
    if [ $numeric_level -le $current_level ]; then
        local log_message="[$timestamp] [$level] $message"
        
        # If not in dry-run mode or if it's an error, show on console
        if ! $DRY_RUN || [ "$level" = "ERROR" ]; then
            echo "$log_message"
        fi
        
        # Log to file if specified
        if [ -n "$LOGS_FILE" ]; then
            echo "$log_message" >> "$LOGS_FILE"
        fi
        
        # Log errors to error log file if specified
        if [ "$level" = "ERROR" ] && [ -n "$ERRORS_LOG_FILE" ]; then
            echo "$log_message" >> "$ERRORS_LOG_FILE"
        elif [ "$level" = "WARN" ] && [ -n "$ERRORS_LOG_FILE" ]; then
            echo "$log_message" >> "$ERRORS_LOG_FILE"
        fi
    fi
}

# Shorthand logging functions
log_error() {
    log "ERROR" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_info() {
    log "INFO" "$1"
}

log_debug() {
    log "DEBUG" "$1"
}

# Check if rsync is installed
check_rsync() {
    if ! command -v rsync &> /dev/null; then
        log_error "rsync is not installed. Please install it and try again."
        exit 1
    else
        log_debug "rsync is installed."
    fi
}

# Read and parse INI file
parse_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        # Check if config file exists in script directory
        if [ -f "$SCRIPT_DIR/$CONFIG_FILE" ]; then
            CONFIG_FILE="$SCRIPT_DIR/$CONFIG_FILE"
            log_debug "Using configuration file from script directory: $CONFIG_FILE"
        else
            log_error "Configuration file '$CONFIG_FILE' not found."
            exit 1
        fi
    fi
    
    log_info "Reading configuration from: $CONFIG_FILE"
    
    # Read general settings
    if grep -q "^\[SETTINGS\]" "$CONFIG_FILE"; then
        # Read sync interval
        if grep -q "^sync_interval" "$CONFIG_FILE"; then
            SYNC_INTERVAL=$(grep "^sync_interval" "$CONFIG_FILE" | cut -d= -f2 | tr -d ' ')
            log_debug "Set sync interval to $SYNC_INTERVAL seconds"
        fi
        
        # Read log level
        if grep -q "^log_level" "$CONFIG_FILE"; then
            LOG_LEVEL=$(grep "^log_level" "$CONFIG_FILE" | cut -d= -f2 | tr -d ' ' | tr '[:lower:]' '[:upper:]')
            log_debug "Set log level to $LOG_LEVEL"
        fi
        
        # Read verify checksums setting
        if grep -q "^verify_checksums" "$CONFIG_FILE"; then
            verify_checksums_val=$(grep "^verify_checksums" "$CONFIG_FILE" | cut -d= -f2 | tr -d ' ' | tr '[:upper:]' '[:lower:]')
            if [ "$verify_checksums_val" = "true" ] || [ "$verify_checksums_val" = "1" ] || [ "$verify_checksums_val" = "yes" ]; then
                VERIFY_CHECKSUMS=true
                log_debug "Checksum verification enabled"
            fi
        fi
    fi
    
    # Read source and destination directories
    if grep -q "^\[DIRECTORIES\]" "$CONFIG_FILE"; then
        # Read source directory
        if grep -q "^source_dir" "$CONFIG_FILE"; then
            DEFAULT_SOURCE_DIR=$(grep "^source_dir" "$CONFIG_FILE" | cut -d= -f2 | tr -d ' ')
            log_debug "Source directory: $DEFAULT_SOURCE_DIR"
        else
            log_error "Source directory not specified in config file"
            exit 1
        fi
        
        # Read ramdisk directory
        if grep -q "^ramdisk_dir" "$CONFIG_FILE"; then
            DEFAULT_RAMDISK_DIR=$(grep "^ramdisk_dir" "$CONFIG_FILE" | cut -d= -f2 | tr -d ' ')
            log_debug "RAM disk directory: $DEFAULT_RAMDISK_DIR"
        else
            log_error "RAM disk directory not specified in config file"
            exit 1
        fi
    else
        log_error "DIRECTORIES section not found in config file"
        exit 1
    fi
}

# Check and create target directories if they don't exist
check_directories() {
    log_info "Checking target directories"
    
    if [ ! -d "$DEFAULT_SOURCE_DIR" ]; then
        log_error "Source directory '$DEFAULT_SOURCE_DIR' does not exist"
        exit 1
    fi
    
    if [ ! -d "$DEFAULT_RAMDISK_DIR" ]; then
        log_info "Creating RAM disk directory: $DEFAULT_RAMDISK_DIR"
        if ! $DRY_RUN; then
            mkdir -p "$DEFAULT_RAMDISK_DIR"
            if [ $? -ne 0 ]; then
                log_error "Failed to create RAM disk directory: $DEFAULT_RAMDISK_DIR"
                exit 1
            fi
        fi
    fi
}

# Generate the rsync script (from RAM disk to hard disk)
generate_rsync_script() {
    log_info "Generating rsync script: $RSYNC_SCRIPT"
    
    if ! $DRY_RUN; then
        cat > "$RSYNC_SCRIPT" << EOF
#!/bin/bash
# Auto-generated rsync script for RAM disk synchronization
# Created by GnuRAMage: Advanced RAM Disk Synchronization Tool on $(date)

# Options explanation:
# -a: archive mode (recursive, preserves permissions, timestamps, etc.)
# -v: verbose (if --verbose is specified)
# --delete: remove files in destination that don't exist in source
# --exclude: exclude patterns from config
# Check if required variables are set and directories exist
if [ -z "$DEFAULT_RAMDISK_DIR" ]; then
    echo "[ERROR] Source or RAM disk directory variable is empty! Aborting."
    exit 3
fi
if [ ! -d "$DEFAULT_RAMDISK_DIR" ]; then
    echo "[ERROR] Source or RAM disk directory does not exist! Aborting."
    exit 4
fi
if [ ! "\$(ls -A "$DEFAULT_RAMDISK_DIR" 2>/dev/null)" ]; then
    echo "[WARNING] RAM disk directory is empty!"
fi

# Create directories if they don't exist
mkdir -p "$DEFAULT_SOURCE_DIR"

# Build rsync command as array
RSYNC_CMD=(rsync -a)

# Add options based on settings
if [ "$1" = "--verbose" ]; then
    RSYNC_CMD+=( -v )
fi

if [ "$1" = "--dry-run" ]; then
    RSYNC_CMD+=( --dry-run )
fi

EOF
        # Add exclude patterns from INI if they exist, all in one line
        if grep -q "^\[EXCLUDE\]" "$CONFIG_FILE"; then
            exclude_patterns=$(sed -n '/^\[EXCLUDE\]/,/^\[/p' "$CONFIG_FILE" | grep -v "^\[" | grep -v "^;" | grep -v "^$" | grep -v '^#' | grep -v -i 'pattern' | grep -v -i 'exclude' | grep -v -i 'synchronization' | grep -v -i 'line' | grep -v -i 'format')
            for pattern in $exclude_patterns; do
                echo "RSYNC_CMD+=( --exclude='$pattern' )" >> "$RSYNC_SCRIPT"
            done
        fi
        echo "RSYNC_CMD+=( --delete \"$DEFAULT_RAMDISK_DIR/\" \"$DEFAULT_SOURCE_DIR/\" )" >> "$RSYNC_SCRIPT"
        echo '' >> "$RSYNC_SCRIPT"
        echo '#echo "[INFO] Rsync command: ${RSYNC_CMD[*]}"' >> "$RSYNC_SCRIPT"
        echo '# Execute rsync command' >> "$RSYNC_SCRIPT"
        echo '"${RSYNC_CMD[@]}"' >> "$RSYNC_SCRIPT"
        
        # Make the script executable
        chmod +x "$RSYNC_SCRIPT"
    fi
    
    log_debug "Rsync script generated successfully"
}

# Generate the cp script (from hard disk to RAM disk)
generate_cp_script() {
    log_info "Generating cp script: $CP_SCRIPT"
    
    if ! $DRY_RUN; then
        cat > "$CP_SCRIPT" << EOF
#!/bin/bash
# Auto-generated cp script for RAM disk synchronization
# Created by GnuRAMage: Advanced RAM Disk Synchronization Tool on $(date)

# Create directories if they don't exist
mkdir -p "$DEFAULT_RAMDISK_DIR"

# If verbose flag is set, add -v option to cp
CP_CMD="cp -a"
if [ "\$1" = "--verbose" ]; then
    CP_CMD="cp -av"
fi

# If dry-run flag is set, just echo what would be done
if [ "\$1" = "--dry-run" ]; then
    echo "Would copy files from $DEFAULT_SOURCE_DIR to $DEFAULT_RAMDISK_DIR"
    exit 0
fi

# Copy files from source to RAM disk
\$CP_CMD "$DEFAULT_SOURCE_DIR"* "$DEFAULT_RAMDISK_DIR" 2>/dev/null

# Handle case where source directory is empty or no files match
if [ \$? -ne 0 ]; then
    # Check if source directory exists and is not empty
    if [ -d "$DEFAULT_SOURCE_DIR" ] && [ "\$(ls -A "$DEFAULT_SOURCE_DIR" 2>/dev/null)" ]; then
        echo "Error: Failed to copy files to RAM disk"
        exit 1
    else
        # Create an empty file to mark successful execution even if no files were copied
        touch "$DEFAULT_RAMDISK_DIR/.rsyncignore"
    fi
fi

exit 0
EOF

        # Make the script executable
        chmod +x "$CP_SCRIPT"
    fi
    
    log_debug "Copy script generated successfully"
}

# Execute cp script to copy from hard disk to RAM disk
execute_cp_script() {
    log_info "Executing copy to RAM disk script"
    
    local verbose_flag=""
    if $VERBOSE; then
        verbose_flag="--verbose"
    fi
    
    local dry_run_flag=""
    if $DRY_RUN; then
        dry_run_flag="--dry-run"
    fi
    
    if ! $DRY_RUN; then
        if $VERBOSE; then
            "$CP_SCRIPT" "$verbose_flag"
        else
            "$CP_SCRIPT" > /dev/null
        fi
        
        if [ $? -ne 0 ]; then
            log_error "Failed to copy files to RAM disk"
            return 1
        else
            log_info "Files copied to RAM disk successfully"
            TOTAL_FILES_COPIED=$(find "$DEFAULT_RAMDISK_DIR" -type f | wc -l)
            log_debug "Total files copied: $TOTAL_FILES_COPIED"
        fi
    else
        log_info "Dry run: Would execute copy script"
    fi
    
    return 0
}

# Execute rsync script to sync from RAM disk to hard disk
execute_rsync_script() {
    log_info "Executing rsync to hard disk script"
    
    local verbose_flag=""
    if $VERBOSE; then
        verbose_flag="--verbose"
    fi
    
    local dry_run_flag=""
    if $DRY_RUN; then
        dry_run_flag="--dry-run"
    fi
    
    if ! $DRY_RUN; then
        if $VERBOSE; then
            "$RSYNC_SCRIPT" "$verbose_flag" 2> /tmp/rsync_error.log
        else
            "$RSYNC_SCRIPT" > /dev/null 2> /tmp/rsync_error.log
        fi
        
        local rsync_status=$?
        if [ $rsync_status -ne 0 ]; then
            local error_msg=$(cat /tmp/rsync_error.log)
            log_error "Failed to sync files to hard disk: Error code $rsync_status"
            log_error "Rsync error: $error_msg"
            # Add rsync errors to the error log as well
            if [ -n "$ERRORS_LOG_FILE" ]; then
                echo "[$(get_timestamp)] [ERROR] Rsync error: $error_msg" >> "$ERRORS_LOG_FILE"
            fi
            rm -f /tmp/rsync_error.log
            return 1
        else
            log_info "Files synced to hard disk successfully"
            TOTAL_FILES_SYNCED=$((TOTAL_FILES_SYNCED + 1))
            log_debug "Total sync operations: $TOTAL_FILES_SYNCED"
            rm -f /tmp/rsync_error.log
        fi
    else
        log_info "Dry run: Would execute rsync script"
    fi
    
    return 0
}

# Wait for key press with timeout
wait_for_key() {
    local interval=$1
    log_info "Syncing every $interval seconds. Press any key to stop..."
    
    # Use read with timeout
    if read -t "$interval" -n 1 key; then
        log_info "Key pressed. Stopping synchronization..."
        return 1  # Key was pressed
    else
        return 0  # Timeout occurred
    fi
}

# Initialize log files
initialize_log_files() {
    # Create log file if specified and doesn't exist
    if [ -n "$LOGS_FILE" ]; then
        touch "$LOGS_FILE"
        log_info "Log file initialized: $LOGS_FILE"
    fi
    
    # Create error log file if specified and doesn't exist
    if [ -n "$ERRORS_LOG_FILE" ]; then
        touch "$ERRORS_LOG_FILE"
        # Add a header to the error log file
        echo "[$(get_timestamp)] [INFO] Error log file initialized" > "$ERRORS_LOG_FILE"
    fi
}

# Clean up function for proper termination
cleanup() {
    # Skip if cleanup has already been done
    if $CLEANUP_NEEDED; then
        log_info "Starting cleanup process..."
        
        # Final sync before exiting
        log_info "Performing final sync to disk..."
        execute_rsync_script
        
        # Run sync command to ensure data is written to disk
        if ! $DRY_RUN; then
            log_info "Running sync command..."
            sync
            sync
        else
            log_info "Dry run: Would run sync command"
        fi
        
        # Generate report
        generate_report
        
        # Reset cleanup flag
        CLEANUP_NEEDED=false
        
        log_info "Cleanup completed. Exiting."
    fi
}

# Generate report
generate_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    
    log_info "===== RAM Disk Sync Report ====="
    log_info "Start time: $(date -d @$START_TIME)"
    log_info "End time: $(date -d @$end_time)"
    log_info "Duration: ${hours}h ${minutes}m ${seconds}s"
    log_info "Files copied to RAM disk: $TOTAL_FILES_COPIED"
    log_info "Sync operations performed: $TOTAL_FILES_SYNCED"
    log_info "============================"
}

# Main synchronization loop
run_sync_loop() {
    # Register trap for cleanup
    if ! $TRAP_REGISTERED; then
        trap cleanup EXIT INT TERM
        TRAP_REGISTERED=true
        CLEANUP_NEEDED=true
    fi
    
    # Start report timer
    START_TIME=$(date +%s)
    
    # Execute copy script once at start
    execute_cp_script
    if [ $? -ne 0 ]; then
        log_error "Initial copy failed. Exiting."
        exit 1
    fi
    
    # If one-time mode, run rsync once and exit
    if $ONE_TIME_MODE; then
        log_info "Running in one-time mode"
        execute_rsync_script
        exit 0
    fi
    
    # Main sync loop
    log_info "Starting synchronization loop"
    while true; do
        # Wait for key press or timeout
        if ! wait_for_key "$SYNC_INTERVAL"; then
            break
        fi
        
        # Execute rsync script
        execute_rsync_script
    done
    execute_rsync_script
    log_info "Synchronization loop ended"
    sync
    sync
    log_info "Final sync command executed"
}

# Main function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check if rsync is installed
    check_rsync
    
    # Parse configuration file
    parse_config_file
    
    # Check and create directories
    check_directories
    
    # Generate scripts
    generate_rsync_script
    generate_cp_script
    
    # Initialize log files
    initialize_log_files
    
    # Exit if only script generation is requested
    if $SCRIPT_GEN_ONLY; then
        log_info "Scripts generated. Exiting as requested."
        exit 0
    fi
    
    # Run synchronization loop
    run_sync_loop
}

# Start the program
main "$@"
