#!/bin/bash

set -u

# Usage:
#   sudo ./setup_ethernet.sh [auto|home|other|help]
#     auto  (default) - try Home-Lab, confirm or fall back to plain untagged DHCP
#     home            - force Home-Lab
#     other           - force plain untagged DHCP on enp4s0
#     help            - print this usage info

# Configuration (overridable via environment)
PHYS_IF=${PHYS_IF:-"enp4s0"}
VLAN10_IF=${VLAN10_IF:-"vlan10"}          # probed for a lease to confirm Home-Lab
PLAIN_PROFILE=${PLAIN_PROFILE:-"Plain-Ethernet"}
DHCP_WAIT=${DHCP_WAIT:-15}                # seconds to wait for a lease
HOME_PROFILES=("Auto Ethernet" "Home-VLAN10" "Lab-VLAN20" "Bridge-Lab")

MODE=${1:-"auto"}

# Loggers
log_info() { echo "INFO: ${1}"; }
log_error() { echo "ERROR: ${1}"; }
log_warn() { echo "WARNING: ${1}"; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (sudo)"
    exit 1
fi

# Helpers

profile_exists() {
    nmcli -t -f NAME con show 2>/dev/null | grep -qx "${1}"
}

up_profile() {
    local name="$1"
    if ! profile_exists "${name}"; then
        log_warn "Profile '${name}' does not exist. Skipping."
        return 0
    fi
    if nmcli con up "${name}" &> /dev/null; then
        log_info "Activated profile: ${name}"
    else
        log_warn "Could not activate profile: ${name}"
    fi
}

down_profile() {
    local name="$1"
    if ! profile_exists "${name}"; then
        return 0
    fi
    if nmcli con down "${name}" &> /dev/null; then
        log_info "Deactivated profile: ${name}"
    fi
}

# Succeeds if the given interface currently holds an IPv4 address
has_lease() {
    nmcli -g IP4.ADDRESS device show "${1}" 2>/dev/null | grep -q .
}

# Poll has_lease once per second, up to $2 seconds
wait_for_lease() {
    local iface="$1"
    local timeout="$2"
    local elapsed=0

    log_info "Waiting up to ${timeout}s for an IPv4 lease on ${iface}..."
    while [[ ${elapsed} -lt ${timeout} ]]; do
        if has_lease "${iface}"; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

ensure_plain_profile() {
    if profile_exists "${PLAIN_PROFILE}"; then
        log_info "Profile '${PLAIN_PROFILE}' already exists."
        return 0
    fi
    log_info "Creating profile '${PLAIN_PROFILE}' (untagged DHCP on ${PHYS_IF})..."
    nmcli con add type ethernet ifname "${PHYS_IF}" con-name "${PLAIN_PROFILE}" \
        ipv4.method auto ipv6.method auto connection.autoconnect no
}

activate_home() {
    log_info "Activating Home-Lab configuration..."
    down_profile "${PLAIN_PROFILE}"
    # "Auto Ethernet" first: it reclaims enp4s0 and keeps the link up for the tags
    for name in "${HOME_PROFILES[@]}"; do
        up_profile "${name}"
    done
}

activate_other() {
    log_info "Activating plain untagged DHCP on ${PHYS_IF}..."
    for name in "${HOME_PROFILES[@]}"; do
        down_profile "${name}"
    done
    up_profile "${PLAIN_PROFILE}"
}

report_state() {
    log_info "Current ethernet state:"
    nmcli -t -f DEVICE,STATE,CONNECTION device status 2>/dev/null \
        | grep -E "${PHYS_IF}|vlan|br_lab" || true
}

# Main
if [[ "$1" != "help" && "$1" =~ ^(auto|home|other)$ ]]; then
    ensure_plain_profile
fi

case "${MODE}" in
    home)
        activate_home
        ;;
    other)
        activate_other
        ;;
    auto)
        activate_home
        if wait_for_lease "${VLAN10_IF}" "${DHCP_WAIT}"; then
            log_info "Home-Lab detected (lease on ${VLAN10_IF})."
        else
            log_warn "No VLAN lease on ${VLAN10_IF} - falling back to plain ethernet."
            activate_other
            if wait_for_lease "${PHYS_IF}" "${DHCP_WAIT}"; then
                log_info "Plain ethernet is up (lease on ${PHYS_IF})."
            else
                log_error "No lease on ${PHYS_IF} either. Check the cable/switch port."
                report_state
                exit 1
            fi
        fi
        ;;
    help)
        sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
        exit 0
    ;;
    *)
        log_error "Unknown mode: '${MODE}'. Use '$0 help' for usage info"
        exit 1
        ;;
esac

report_state
log_info "Ethernet setup complete (mode: ${MODE})."
