# ADR-NNNN: 0002-fallback-to-regex-check-of-ssh-key

**Status:** Accepted
**Date:** 2026-08-14

## Context
Not all the machines have ssh-keygen installed
## Decision
Use fallback method which uses REGEX to check if key has proper structure
## Consequences
- Script can be run on every machine
- Understanding used REGEX can be problematic
- Not all the key types (especially old ones) can be properly checked
## Alternative Considered
Failing the script entirely and exiting with an error if the `ssh-keygen` utility is not found. This was rejected because it would force users to install additional packages (like `openssh-client`) on minimalistic systems or containers just to run the provisioning script.