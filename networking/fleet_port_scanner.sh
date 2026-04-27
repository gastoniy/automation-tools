#!/bin/bash

CONFIG_FILE="${1:-""}"

log_error() { echo "ERROR: $1"; }

if [[ -z "${CONFIG_FILE}" ]]; then
    log_error "Specify config file in \$1 of script"
    exit 2
fi

if [[ ! -f ${CONFIG_FILE} ]]; then
    log_error "Specified config file does not exist"
    exit 1
fi

while IFS=: read -r host port protocol || [[ -n "${host}" ]]; do
    if [[ -z "$host" || "$host" == \#* ]]; then # Skip empty and comment '#' lines 
        continue
    fi

    protocol=${protocol:-tcp}   # Default value is TCP, UDP only specified in 3rd column
    protocol=$(echo "${protocol}" | tr '[:upper:]' '[:lower:]')

    status="FAILED"
    target="${host}:${port}"

    if [[ "${protocol}" = "udp" ]]; then
        if timeout 3 nc -z -u -w 2 "${host}" "${port}" 2>/dev/null; then
            status="OK"
        fi
    else
        if timeout 3 nc -z -w 2 "${host}" "${port}" 2>/dev/null; then
            status="OK"
        fi
    fi

    echo "${target}:${status}; used protocol: ${protocol}"

done < "${CONFIG_FILE}"