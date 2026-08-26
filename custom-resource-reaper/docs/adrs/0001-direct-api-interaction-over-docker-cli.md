# ADR-0001: direct-api-interaction-over-docker-cli

**Status:** accepted
**Date:** 2026-08-26

## Context
Running automated tasks in constrained or minimal environments (such as Alpine-based CI/CD runners) often means the full Docker client binary is unavailable or unnecessary. Additionally Docker CLI sometimes luck "business" logic approaches - can be to general.
## Decision
Interact with the Docker daemon directly by sending HTTP requests to `/var/run/docker.sock` using `curl` and parsing the JSON responses with `jq`.
## Consequences
- Script becomes not depended on Docker CLI binary
- Granular logic based on raw HTTP status codes (204, 304, 404) can implemented
- Increased code complexity: requiring manual HTTP timeout configuration and error management
- API version risk