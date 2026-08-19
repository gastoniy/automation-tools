An idempotent network configuration utility designed to provision a network bridge and a TAP interface (defaulting to `tap0_gns3`) for virtualization environments.

- **Usage:** `sudo ./setup-bridge.sh [BRIDGE_IF] [TAP_IF] [PHYS_IF]`.
- **Functionality:** Creates the specified bridge and TAP interfaces, attaches them to the physical interface, and automatically appends `iptables` rules to allow traffic forwarding on the bridge.
- **Requirements:** Must be executed with root privileges due to the underlying `ip link`, `ip tuntap`, and `iptables` system modifications.