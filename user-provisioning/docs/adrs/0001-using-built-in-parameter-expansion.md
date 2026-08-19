# ADR-NNNN: 0001-using-built-in-parameter-expansion

**Status:** Accepted
**Date:** 2026-08-14

## Context
Minimalistic base images (like Alpine Linux or distroless containers) often lack GNU Coreutils, meaning standard tools like `awk` or `sed` are not guaranteed.
## Decision
Use only Bash's built-in parameter expansion rather than calling external tools. Example below shows how it works in trim() function

```bash
trim() {
    local s="$1"
    s="${s%$'\r'}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"

    printf '%s' "$s"
}
```
## Consequences
- Script can be run on all the machine with Bash installed with no errors like: `awk` is not installed
- Function which uses parameter expansion can be less readable and need more time to understand its structure
## Alternative Considered
Using external tools like `awk`, `sed`, `tr`. Example below shows function versions which use external tools:

```bash
trim_tr_sed() {
    printf '%s' "$1" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

trim_awk() {
    printf '%s' "$1" | awk '{gsub(/^[ \t\r]+|[ \t\r]+$/, ""); print}'
}
```