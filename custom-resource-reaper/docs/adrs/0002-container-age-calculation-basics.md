# ADR-0002: container-age-calculation-basics

**Status:** Accepted
**Date:** 2026-08-26

## Context
Container lifecycles are nuanced. A container can be created long before it is actually started, which can severely skew age-based reaping logic if only creation time is considered.
## Decision
Provide a configurable `--age-basis` flag that defaults to evaluating the `started` time, while maintaining a safe fallback to `created` if the container never actually started.
## Consequences
- Increased script's accuracy
- Additional complexity: `jq` must parse more difficult `json` structures like nested arrays from API response 