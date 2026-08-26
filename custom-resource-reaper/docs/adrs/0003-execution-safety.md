# ADR-0003: execution-safety

**Status:** Accepted
**Date:** 2026-08-26

## Context
Automated infrastructure scripts operate with high privileges and pose a significant risk of accidental resource destruction if executed blindly in unverified environments.
## Decision
Default the script to a dry-run mode where `APPLY=false` upon initialization. Matching violators will only be logged unless an explicit `--apply` or `-a` flag is passed.
## Consequences
- Сomplete safety when testing the tool in new environments
- Prevention of accidental data loss
- Additional logic to implement
- Additional option to append in every execution