#!/bin/bash

# Reaps RUNNING containers whose uptime exceeds N hours UNLESS they carry an
# environment=X label (a protected environment)

# Tracking Vars
USE_CONFIG=false
USE_CLI_OPTIONS=false
CONFIG_FILE=""

# Script Vars (empty here, defaults applied after parsing / config load)
HOURS=""
PROTECT_ENV=""
AGE_BASIS=""
APPLY=""
STOP_TIMEOUT=""
SOCKET=""

log_info() { echo "INFO: $1"; logger -t "$0" "INFO: $1"; }
log_error() { echo "ERROR: $1"; logger -t "$0" "ERROR: $1"; }
log_warn() { echo "WARNING: $1"; logger -t "$0" "WARNING: $1"; }

usage() {
    cat <<EOF
Usage: $0 [options]
  -H, --hours N            Uptime threshold in hours (default 24, fractional allowed)
  -e, --protect-env X      Exempt containers labeled environment=X (default production)
  -b, --age-basis MODE     'started' = true uptime, 'created' = since creation (default started)
  -a, --apply              Actually stop violators (default: dry-run, nothing is stopped)
  -t, --stop-timeout SEC   Graceful stop grace period in seconds (default 10)
  -s, --socket PATH        Docker socket path (default /var/run/docker.sock)
  -f, --file CONF          Load settings from a sourced config file (not combinable with the above)
  -h, --help               Show this help

Reaps RUNNING containers older than N hours unless labeled environment=X.
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -H|--hours)
            USE_CLI_OPTIONS=true
            HOURS="$2"
            shift 2
            ;;
        -e|--protect-env)
            USE_CLI_OPTIONS=true
            PROTECT_ENV="$2"
            shift 2
            ;;
        -b|--age-basis)
            USE_CLI_OPTIONS=true
            AGE_BASIS="$2"
            shift 2
            ;;
        -a|--apply)
            USE_CLI_OPTIONS=true
            APPLY=true
            shift 1
            ;;
        -t|--stop-timeout)
            USE_CLI_OPTIONS=true
            STOP_TIMEOUT="$2"
            shift 2
            ;;
        -s|--socket)
            USE_CLI_OPTIONS=true
            SOCKET="$2"
            shift 2
            ;;
        -f|--file)
            USE_CONFIG=true
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error unknown option $1"
            exit 1
            ;;
    esac
done

# Enforce mutuality (-f loads everything from a file, so it stands alone)
if [[ "$USE_CONFIG" == "true" && "$USE_CLI_OPTIONS" == "true" ]]; then
    log_error "-f/--file can't be combined with other CLI arguments"
    exit 1
fi

if [[ "$USE_CONFIG" == "true" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found at $CONFIG_FILE"
        exit 1
    fi
    log_info "Loading configuration file from $CONFIG_FILE"
    source "$CONFIG_FILE"
fi

# Apply Default Values
HOURS="${HOURS:-24}"
PROTECT_ENV="${PROTECT_ENV:-production}"
AGE_BASIS="${AGE_BASIS:-started}"
APPLY="${APPLY:-false}"
STOP_TIMEOUT="${STOP_TIMEOUT:-10}"
SOCKET="${SOCKET:-/var/run/docker.sock}"

# Validate inputs
if [[ "$AGE_BASIS" != "started" && "$AGE_BASIS" != "created" ]]; then
    log_error "--age-basis must be 'started' or 'created' (got '$AGE_BASIS')"
    exit 2
fi
if ! [[ "$HOURS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    log_error "--hours must be a non-negative number (got '$HOURS')"
    exit 2
fi
if ! [[ "$STOP_TIMEOUT" =~ ^[0-9]+$ ]]; then
    log_error "--stop-timeout must be a non-negative integer (got '$STOP_TIMEOUT')"
    exit 2
fi

# Preflight checks
for cmd in curl jq date awk; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found on PATH: $cmd"
        exit 1
    fi
done

if [[ ! -S "$SOCKET" ]]; then
    log_error "Docker socket not found at $SOCKET"
    exit 1
fi

PING=$(curl -s -m 5 --unix-socket "$SOCKET" "http://localhost/_ping" 2>/dev/null)
if [[ "$PING" != "OK" ]]; then
    log_error "Docker daemon did not answer OK on $SOCKET (got '${PING}')"
    exit 1
fi

# Resolve a container's start epoch honouring the chosen age basis
# Only ever echoes a single integer so it is safe inside $( )
get_start_epoch() {
    local id="$1"
    local created="$2"
    local inspect started_at epoch

    if [[ "$AGE_BASIS" == "created" ]]; then
        echo "$created"
        return 0
    fi

    inspect=$(curl -s -m 10 --unix-socket "$SOCKET" "http://localhost/containers/${id}/json")
    if [[ $? -ne 0 || -z "$inspect" ]]; then
        echo "$created"   # fall back to creation time if inspect fails
        return 0
    fi

    started_at=$(printf '%s' "$inspect" | jq -r '.State.StartedAt // empty')
    if [[ -z "$started_at" || "$started_at" == 0001-01-01* ]]; then
        echo "$created"   # never actually started -> use creation time
        return 0
    fi

    epoch=$(date -d "$started_at" +%s 2>/dev/null)
    if [[ -z "$epoch" ]]; then
        echo "$created"
        return 0
    fi

    echo "$epoch"
}

# Announce the run
if [[ "$APPLY" == "true" ]]; then
    log_warn "APPLY mode: matching violators WILL be gracefully stopped"
else
    log_info "DRY-RUN mode: nothing will be stopped (pass --apply to act)"
fi
log_info "threshold=${HOURS}h protected-env=${PROTECT_ENV} age-basis=${AGE_BASIS} stop-timeout=${STOP_TIMEOUT}s socket=${SOCKET}"

# CSV audit log
LOG_FILE="container_reaper_$( date +%Y-%m-%d_%H-%M-%S ).csv"
echo "Name,Id,Image,AgeHours,Environment,Decision,Action" > "$LOG_FILE"

# Fetch running containers (running-only is the API default)
CONTAINERS_JSON=$(curl -s -m 10 --unix-socket "$SOCKET" "http://localhost/containers/json")
CURL_STATUS=$?
if [[ $CURL_STATUS -ne 0 ]]; then
    log_error "Failed to query running containers from the Docker API (curl exit $CURL_STATUS)"
    exit 1
fi

if ! printf '%s' "$CONTAINERS_JSON" | jq -e . >/dev/null 2>&1; then
    log_error "Docker API returned invalid JSON for the container list"
    exit 1
fi

# Reduce to a TSV stream: id, short-name, image, created(epoch), environment label
CONTAINER_ROWS=$(printf '%s' "$CONTAINERS_JSON" \
    | jq -r '.[] | [ .Id, (.Names[0]|ltrimstr("/")), .Image, (.Created|tostring), (.Labels.environment // "") ] | @tsv')

if [[ -z "$CONTAINER_ROWS" ]]; then
    log_info "No running containers found. Nothing to do."
    exit 0
fi

NOW=$(date +%s)
THRESHOLD_SECONDS=$(awk -v h="$HOURS" 'BEGIN { printf "%d", h * 3600 }')

SCANNED=0
VIOLATORS=0
STOPPED=0
FAILED=0

while IFS=$'\t' read -r ID NAME IMAGE CREATED ENV_LABEL; do
    [[ -z "$ID" ]] && continue
    SCANNED=$((SCANNED + 1))

    START_EPOCH=$(get_start_epoch "$ID" "$CREATED")
    AGE_SECONDS=$((NOW - START_EPOCH))
    (( AGE_SECONDS < 0 )) && AGE_SECONDS=0
    AGE_HOURS=$(awk -v a="$AGE_SECONDS" 'BEGIN { printf "%.1f", a / 3600 }')

    # Reaping rule: too old AND not the protected environment
    if (( AGE_SECONDS > THRESHOLD_SECONDS )); then
        if [[ "$ENV_LABEL" == "$PROTECT_ENV" ]]; then
            DECISION="exempt"
        else
            DECISION="VIOLATOR"
        fi
    else
        DECISION="within-threshold"
    fi

    ACTION="none"
    if [[ "$DECISION" == "VIOLATOR" ]]; then
        VIOLATORS=$((VIOLATORS + 1))
        if [[ "$APPLY" == "true" ]]; then
            CODE=$(curl -o /dev/null -s -w "%{http_code}" -m 30 -X POST \
                --unix-socket "$SOCKET" \
                "http://localhost/containers/${ID}/stop?t=${STOP_TIMEOUT}")
            case "$CODE" in
                204)
                    log_info "Stopped ${NAME}"
                    ACTION="stopped"
                    STOPPED=$((STOPPED + 1))
                    ;;
                304)
                    log_warn "${NAME} was already stopped"
                    ACTION="already-stopped"
                    ;;
                404)
                    log_error "${NAME} no longer exists"
                    ACTION="not-found"
                    FAILED=$((FAILED + 1))
                    ;;
                *)
                    log_error "Failed to stop ${NAME} (HTTP ${CODE})"
                    ACTION="error-${CODE}"
                    FAILED=$((FAILED + 1))
                    ;;
            esac
        else
            log_info "[DRY-RUN] would stop ${NAME}"
            ACTION="dry-run"
        fi
    fi

    # echo "${NAME}:${DECISION}; age=${AGE_HOURS}h env=${ENV_LABEL:-<none>}"    # echos additional information to stdout
    echo "${NAME},${ID:0:12},${IMAGE},${AGE_HOURS},${ENV_LABEL},${DECISION},${ACTION}" >> "$LOG_FILE"

done <<< "$CONTAINER_ROWS"

log_info "Summary: scanned=${SCANNED} violators=${VIOLATORS} stopped=${STOPPED} failed=${FAILED}"
log_info "Audit log written to ${LOG_FILE}"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
exit 0
