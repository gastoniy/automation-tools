#!/bin/bash

# Tracking Vars
USE_CONFIG=false
CONFIG_FILE=""
USE_CLI_OPTIONS=false

# Script Vars
BACKUP_DIR=""
TARGET_DIR=""
CLEANUP_DAYS=""
DISK_SECURE=""

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
        -t|--target)
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
                echo "Usage: $0 [-f config_file] OR [-d directories -t target]"
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

# Apply Default Values
CLEANUP_DAYS="${CLEANUP_DAYS:-7}"
DISK_SECURE="${DISK_SECURE:-false}" 

# Validate Required Values
if [[ -z "$BACKUP_DIR" || -z "$TARGET_DIR" ]]; then
    echo "Specify backup directory [-d] AND target tar file [-t]"
    exit 2
fi
