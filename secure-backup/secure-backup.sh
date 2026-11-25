#!/bin/bash

# Tracking Vars
USE_CONFIG=false
CONFIG_FILE=""
USE_CLI_OPTIONS=false

# Script Vars
BACKUP_DIR=""
TARGET_DIR=""
TARGET_DEV=""
SOURCE_DEV=""
CLEANUP_DAYS=""
DISK_SECURE=""
CURRENT_DATE=$(date +%F-%H:%M)

log_info() { echo "INFO: $1"; logger -t "$0" "INFO: $1"; }
log_error() { echo "ERROR: $1"; logger -t "$0" "ERROR: $1"; }
log_warn() { echo "WARNING: $1"; logger -t "$0" "WARNING: $1"; }

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            USE_CONFIG=true
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--back-up-dirs)
            USE_CLI_OPTIONS=true
            BACKUP_DIR="$2"
            shift 2
            ;;
        -t|--target-directory)
            USE_CLI_OPTIONS=true
            TARGET_DIR="$2"
            shift 2
            ;;
        -c|--clean-up)
            USE_CLI_OPTIONS=true
            CLEANUP_DAYS="$2"
            shift 2
            ;;
        -s|--secure-disk)
            USE_CLI_OPTIONS=true
            DISK_SECURE=true
            shift 1
            ;;
        -h|--help)
            if [[ "$USE_CLI_OPTIONS" == "false" ]]; then
                echo "Usage: $0 [-f config_file] OR [-d "source dir" -t "destination dir"]"
                exit 0
            else
                echo "Help can't be used with other options!"
                exit 1
            fi
            ;;
        *)
            echo "Error unknown option $1"
            exit 1
            ;;
    esac
done

# Enforce mutuality
if [[ "$USE_CONFIG" == "true" && "$USE_CLI_OPTIONS" == "true"  ]]; then
    log_error "-f option can't be combined with other CLI arguments"
    exit 1
fi

# Apply options based oņ user choice
if [[ "$USE_CONFIG" == "true" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found at $CONFIG_FILE"
        exit 1
    fi
    log_info "Loading configuration file from $CONFIG_FILE"
    source "$CONFIG_FILE"

elif [[ "$USE_CLI_OPTIONS" == "true" ]]; then
    # Validate Required Values
    if [[ -z "$BACKUP_DIR" || -z "$TARGET_DIR" ]]; then
        log_error "Specify backup directory [-d] AND destination directory [-t]"
        exit 1
    fi
else
    log_error "No arguments provided. Run '$0 -h' for help."
    exit 1
fi

# Apply Default Values
CLEANUP_DAYS="${CLEANUP_DAYS:-7}"
DISK_SECURE="${DISK_SECURE:-false}"

# Check source and destination directories
if [[ ! -d "$TARGET_DIR" ]]; then
    log_error "Destination does not exist"
    exit 1
fi

TARGET_DEV=$( stat -c "%d" "$TARGET_DIR")

for SOURCE in "${BACKUP_DIR[@]}"; do
    log_info "Processing $SOURCE"
    if [[ ! -d "$SOURCE" ]]; then
        log_error "Specified source [$SOURCE] does not exist or is not a directory. Skipping..."
        continue
    fi

    SOURCE_DEV=$( stat -c "%d" "$SOURCE")

    if [[ "$SOURCE_DEV" == "$TARGET_DEV" ]]; then

        log_warn "Backing Up to the same mount point (device)"
        if [[ "$DISK_SECURE" == "true" ]]; then
            log_error "Secure Option is Specified. Quitting..."
            exit 1
        else
            log_info "Disk Secure is not specified - processing anyway"
        fi
    fi
    # Archive Source Dirs
    # Define paths
    BASE_NAME=$(basename "$SOURCE")
    DIR_NAME=$(dirname "$SOURCE")
    ARCHIVE_PATH="$TARGET_DIR/${BASE_NAME}-${CURRENT_DATE}.tar.zst"

    log_info "Backing up $SOURCE to $ARCHIVE_PATH"

    tar -I "zstd -T0" -cp \
    --numeric-owner \
    -f "$ARCHIVE_PATH" \
    -C "$DIR_NAME" "$BASE_NAME"

    # Check tar exit status
    TAR_EXIT=$?

    if [[ "$TAR_EXIT" -eq 2 ]]; then
        log_error "tar encountered a fatal error backing up $SOURCE."
        rm -f "$ARCHIVE_PATH"
        continue
    elif [[ "$TAR_EXIT" -eq 1 ]]; then
        log_warn "tar completed, but some files were modified during the backup. Path: $ARCHIVE_PATH"
    else
        log_info "tar archive created. Path: $ARCHIVE_PATH"
    fi

    # Verify the archive
    if tar -I "zstd -T0" -tf "$ARCHIVE_PATH" > /dev/null; then
        log_info "Archive Verified"

        # Perform Clean Up if verification passed
        log_info "Running cleanup for $BASE_NAME backups older than $CLEANUP_DAYS days"
        DELETED_FILES=$(find "$TARGET_DIR" -name "$BASE_NAME-*.tar.zst" -type f -mtime +"$CLEANUP_DAYS" -print -delete)

        if [[ -n "${DELETED_FILES}" ]]; then
            log_info "Successfully cleaned up the following old backups:"
            log_info "${DELETED_FILES}"
        else
            log_info "No backups older than $CLEANUP_DAYS days found. Nothing to clean up"
        fi

    else
        log_error "Archive corrupted"
        exit 1
    fi
done