# ADR-0005: configuration-file-approach

**Status:** Accepted
**Date:** 2026-08-26

## Context
The script must support diverse operational environments, ranging from interactive terminal execution to automated cron jobs, which requires flexible parameter injection.
## Decision
Support loading variables via a configuration file (`source "$CONFIG_FILE"`), but strictly enforce mutual exclusivity against CLI flags.
## Consequences
- Leveraging native Bash evaluation keeps the script lightweight and avoids the need for a custom configuration parser
- Provide importance of keeping the config file secure since it executes as code 