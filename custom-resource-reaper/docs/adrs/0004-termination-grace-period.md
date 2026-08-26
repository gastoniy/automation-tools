# ADR-0004: termination-grace-period

**Status:** Accepted
**Date:** 2026-08-26

## Context
Abruptly killing running containers (`SIGKILL`) can lead to data corruption, severed database connections, or dropped active web requests.
## Decision
Implement a 10-second default graceful stop period via the `--stop-timeout` argument, which is passed directly to the Docker API endpoint.
## Consequences
- Adequate time to gracefully shut down
- Improvement in overall system stability
- Extension of total execution time of the script, especially if a large volume of containers must be stopped sequentially