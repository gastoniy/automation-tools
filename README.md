# automation-tools

A collection of original scripts to facilitate everyday DevOps/Admin tasks. 

This repository consolidates various bash utilities for network configuration, infrastructure monitoring, and system administration into a single, organized project. 

## Tool Index

| Directory | Primary Script | Description |
| :--- | :--- | :--- |
| **`user-provisioning/`** | `user-landing.sh` | Idempotent Linux user provisioning from a simple CSV configuration. |
| **`http-monitoring/`** | `check-health.sh` | Performs concurrent HTTP status checks against a list of target URLs using `curl`. |
| **`network-virtualization/`** | `setup-bridge.sh` | An idempotent utility to provision a network bridge and a TAP interface for virtualization environments. |
| **`network-workstation/`** | `setup-ethernet.sh` | Manages redundant Ethernet bring-up for a workstation by interacting with NetworkManager. |
| **`fleet-scanning/`** | `fleet-port-scanner.sh` | A lightweight, timeout-based port scanner utilizing `nc` (netcat) to rapidly verify service availability. |
| **`custom-resource-reaper/`** | `orphan-reaper.sh` | A utility to safely reap stale running Docker containers based on uptime thresholds by directly interacting with the Docker socket using `curl` and `jq`. |

> **Documentation Note:** Each directory contains its own dedicated `README.md` and configuration example files (e.g., `users.csv.example`, `http-health-config.example`, `fleet-config.example`) detailing specific usage instructions, required permissions, and idempotency guarantees.

## License

This project is licensed under the MIT License - Copyright (c) 2026 Ihor Fisak.
