#!/bin/bash

# user-landing.sh - Idempotent user provisioning from a CSV config

# Script Vars
CONFIG_FILE=""
HAVE_SSH_KEYGEN=false

# Counters
COUNT_CREATED=0
COUNT_EXISTING=0
COUNT_KEYS_ADDED=0
COUNT_ERRORS=0

# Helpers
log_info()  { echo "INFO: $1";    command -v logger >/dev/null 2>&1 && logger -t "$0" "INFO: $1"; }
log_error() { echo "ERROR: $1";   command -v logger >/dev/null 2>&1 && logger -t "$0" "ERROR: $1"; }
log_warn()  { echo "WARNING: $1"; command -v logger >/dev/null 2>&1 && logger -t "$0" "WARNING: $1"; }

usage() {
    echo "Usage: $0 <config.csv>"
    echo
    echo "  Config format (one record per line, comma separated):"
    echo "    username, group(s), ssh_pub_key"
    echo
    echo "  - group(s): one group, or several separated by ';' (e.g. sudo;docker)"
    echo "  - Lines starting with '#' and blank lines are ignored"
    echo "  - Must be run as root. See users.csv.example for a sample."
}

# Strip a trailing CRLF files plus leading/trailing whitespace
trim() {
    local s="$1"
    s="${s%$'\r'}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Return 0 if the given string is a well-formed SSH public key
is_valid_ssh_key() {
    local key="$1"

    if [[ "$HAVE_SSH_KEYGEN" == "true" ]]; then
        local tmp
        tmp=$(mktemp) || return 1
        printf '%s\n' "$key" > "$tmp"
        if ssh-keygen -l -f "$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            return 0
        fi
        rm -f "$tmp"
        return 1
    fi

    # Fallback format check when ssh-keygen is unavailable
    local re='^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[a-zA-Z0-9-]+|sk-[a-zA-Z0-9@.-]+)[[:space:]]+AAAA[0-9A-Za-z+/]+=*([[:space:]].*)?$'
    [[ "$key" =~ $re ]]
}

# Parse arguments (positional config file, plus -h/--help)
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        log_error "No config file provided. Run '$0 -h' for help."
        exit 1
        ;;
    *)
        CONFIG_FILE="$1"
        ;;
esac

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (needs useradd/groupadd/usermod)."
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" || ! -r "$CONFIG_FILE" ]]; then
    log_error "Config file not found or not readable: $CONFIG_FILE"
    exit 1
fi

if command -v ssh-keygen >/dev/null 2>&1; then
    HAVE_SSH_KEYGEN=true
else
    log_warn "ssh-keygen not found; falling back to a basic regex check for SSH keys."
fi

log_info "Provisioning users from $CONFIG_FILE"

#  Main loop

# Three read vars: field 3 captures the remainder of the line, so SSH key
# bodies/comments (which contain spaces, and occasionally commas) stay intact
while IFS=',' read -r raw_user raw_groups raw_key || [[ -n "$raw_user" ]]; do

    user=$(trim "$raw_user")
    groups=$(trim "$raw_groups")
    key=$(trim "$raw_key")

    # Skip blank lines and comments
    [[ -z "$user" ]] && continue
    [[ "$user" == \#* ]] && continue

    # Skip a header row like: username, group, ssh_pub_key
    [[ "$key" == "ssh_pub_key" ]] && continue

    # Validate username.
    if [[ ! "$user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        log_error "Invalid username '$user'. Skipping row."
        ((COUNT_ERRORS++))
        continue
    fi

    # Validate the SSH key BEFORE touching the system, so a malformed key
    # skips the whole user (per requirement) without a partial account
    if [[ -z "$key" ]]; then
        log_error "No SSH key provided for user '$user'. Skipping user."
        ((COUNT_ERRORS++))
        continue
    fi
    if ! is_valid_ssh_key "$key"; then
        log_error "Malformed SSH key for user '$user'. Skipping user."
        ((COUNT_ERRORS++))
        continue
    fi

    # Ensure the user exists (idempotent)
    if getent passwd "$user" >/dev/null; then
        log_info "User '$user' already exists. Skipping creation."
        ((COUNT_EXISTING++))
    else
        if useradd -m -s /bin/bash "$user"; then
            log_info "Created user '$user'."
            ((COUNT_CREATED++))
        else
            log_error "useradd failed for '$user'. Skipping user."
            ((COUNT_ERRORS++))
            continue
        fi
    fi

    # Ensure groups exist and the user is a supplementary member (idempotent)
    if [[ -n "$groups" ]]; then
        IFS=';' read -ra group_list <<< "$groups"
        for raw_group in "${group_list[@]}"; do
            group=$(trim "$raw_group")
            [[ -z "$group" ]] && continue

            if ! getent group "$group" >/dev/null; then
                if groupadd "$group"; then
                    log_info "Created group '$group'."
                else
                    log_error "groupadd failed for '$group' (user '$user'). Skipping this group."
                    ((COUNT_ERRORS++))
                    continue
                fi
            fi

            # usermod -aG is additive: re-adding an existing member is a no-op
            if usermod -aG "$group" "$user"; then
                log_info "Ensured user '$user' is in group '$group'."
            else
                log_error "Failed to add user '$user' to group '$group'."
                ((COUNT_ERRORS++))
            fi
        done
    fi

    # Install the SSH key into ~/.ssh/authorized_keys (idempotent)
    home=$(getent passwd "$user" | cut -d: -f6)
    [[ -z "$home" ]] && home="/home/$user"
    ssh_dir="$home/.ssh"
    auth_keys="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    touch "$auth_keys"

    if grep -qxF -- "$key" "$auth_keys"; then
        log_info "SSH key already present for '$user'. Nothing to append."
    else
        printf '%s\n' "$key" >> "$auth_keys"
        log_info "Appended SSH key for '$user'."
        ((COUNT_KEYS_ADDED++))
    fi

    # Re-apply correct ownership and permissions every run
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys"
    chown -R "${user}:" "$ssh_dir"

done < "$CONFIG_FILE"

# Summary

log_info "Done. Created: $COUNT_CREATED, already existed: $COUNT_EXISTING, keys added: $COUNT_KEYS_ADDED, errors: $COUNT_ERRORS."

if [[ "$COUNT_ERRORS" -gt 0 ]]; then
    exit 1
fi
exit 0
