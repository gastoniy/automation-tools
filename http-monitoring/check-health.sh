#!/bin/bash

URL_FILE="$1"
LOG_FILE="http_health_logs_$( date +%Y-%m-%d_%H-%M-%S ).csv"

log_error() { echo "ERROR: $1"; }
log_info() { echo "INFO: $1"; }

# Ensure the URL file exists
if [[ ! -f "${URL_FILE}" ]]; then
    log_error "File ${URL_FILE} not found!"
    exit 1
fi

echo "URL,Status_Code,Status" > "${LOG_FILE}"

# Function to get http status codes and check if they are valid
check_url() {
    local url="$1"
    local status_code=""

    log_info "Checking URL: ${url}"
    status_code=$(curl -o /dev/null -s -w "%{http_code}" -m 10 "${url}")

    local status="DOWN"

    if [[ "${status_code}" =~ ^[23][0-9]{2}$ ]]; then  # Reg expression for 2XX and 3XX codes
        status="UP"
    fi

    if [[ "${status_code}" = "000" ]]; then
        status_code="ERROR"
    fi

    echo "${url},${status_code},${status}" | tee -a "${LOG_FILE}"
}

while IFS= read -r url || [[ -n "${url}" ]]; do
    if [[ -z "${url}" ]]; then
        continue
    fi

    check_url "${url}" &

done < "${URL_FILE}"

wait