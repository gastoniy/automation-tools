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
    echo "Error: -f option can't be combined with other CLI arguments"
    exit 1
fi

# Apply options based oņ user choice
if [[ "$USE_CONFIG" == "true" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Config file not found at $CONFIG_FILE"
        exit 1
    fi
    echo "Loading configuration file from $CONFIG_FILE"
    source "$CONFIG_FILE"

elif [[ "$USE_CLI_OPTIONS" == "true" ]]; then
    # Validate Required Values
    if [[ -z "$BACKUP_DIR" || -z "$TARGET_DIR" ]]; then
        echo "Error: Specify backup directory [-d] AND destination directory [-t]"
        exit 1
    fi
else
    echo "Error: No arguments provided. Run '$0 -h' for help."
    exit 1
fi

# Apply Default Values
CLEANUP_DAYS="${CLEANUP_DAYS:-7}"
DISK_SECURE="${DISK_SECURE:-false}" 