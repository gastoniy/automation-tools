#!/bin/bash

set -u

BRIDGE_IF=${1:-"br0"}
TAP_IF=${2:-"tap0_gns3"}
PHYS_IF=${3:-""}    # PHYS is only for readability, so virtual interfaces can be used
TAP_USER=${SUDO_USER:-root}

log_info() { echo "INFO: ${1}"; }
log_error() { echo "ERROR: ${1}"; }
log_warn() { echo "WARNING: ${1}"; }

# Helper function to check without code duplication
add_forward_rule() {
    local rule_args=("$@")
    if ! iptables -C "${rule_args[@]}" &> /dev/null; then
        iptables -A "${rule_args[@]}"
        log_info "Added firewall rule: iptables -A ${rule_args[*]}"
    else
        log_info "Firewall rule already exists: iptables -A ${rule_args[*]}"
    fi
}

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (sudo)"
    exit 1
fi

log_info "Configuration: Bridge=${BRIDGE_IF} | TAP=${TAP_IF} | Physical=${PHYS_IF} | User=${TAP_USER}"

# Bridge setup

if ! ip link show dev "${BRIDGE_IF}" &> /dev/null; then
    log_info "Creating bridge: ${BRIDGE_IF}"
    ip link add name "${BRIDGE_IF}" type bridge
    ip link set dev "${BRIDGE_IF}" up
else
    log_info "Bridge ${BRIDGE_IF} already exists"
fi

# Tap setup
if ! ip link show "${TAP_IF}" &> /dev/null; then
    log_info "Creating TAP interface: ${TAP_IF}..."
    ip tuntap add dev "${TAP_IF}" mode tap user "${TAP_USER}"
    ip link set dev "${TAP_IF}" up
else
    log_info "TAP interface ${TAP_IF} already exists."
fi

# Attach Tap to Bridge
if ! ip link show "${TAP_IF}" | grep -q "master ${BRIDGE_IF}"; then
    log_info "Attaching ${TAP_IF} to ${BRIDGE_IF}..."
    ip link set dev "${TAP_IF}" master "${BRIDGE_IF}"
else
    log_info "${TAP_IF} is already attached to ${BRIDGE_IF}."
fi

# Attach Physical Interface to Bridge
if ip link show "${PHYS_IF}" &> /dev/null; then
    if ! ip link show "${PHYS_IF}" | grep -q "master ${BRIDGE_IF}"; then
        log_info "Attaching ${PHYS_IF} to ${BRIDGE_IF}..."
        ip link set dev "${PHYS_IF}" master "${BRIDGE_IF}"
    else
        log_info "${PHYS_IF} is already attached to ${BRIDGE_IF}."
    fi
else
    log_warn "Physical interface ${PHYS_IF} does not exist. Skipping attachment."
fi

log_info "Configuring firewall rules"

# Allow forwarding IN on the bridge
add_forward_rule FORWARD -i "${BRIDGE_IF}" -j ACCEPT

# Allow forwarding OUT on the bridge
add_forward_rule FORWARD -o "${BRIDGE_IF}" -j ACCEPT

log_info "Network Setup Complete"