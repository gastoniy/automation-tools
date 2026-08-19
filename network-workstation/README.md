This utility script manages redundant Ethernet bring-up for a workstation by interacting with NetworkManager (`nmcli`). It automatically detects whether the machine is plugged into a specific Home-Lab environment (expecting tagged VLAN 10 and 20 traffic) or a standard untagged switch port, and applies the correct connection profiles accordingly.

- **Usage:** `sudo ./setup_ethernet.sh [auto|home|other|help]`. 
- **Modes:**
    
    - `auto` (Default): Attempts to activate Home-Lab profiles and waits for a DHCP lease on the VLAN 10 interface. If no lease is acquired within the timeout period, it automatically falls back to plain untagged DHCP.  
    - `home`: Forces the Home-Lab configuration, activating a sequence of profiles including VLAN 10, VLAN 20, and a bridge.  
    - `other`: Forces a plain, untagged DHCP connection on the physical interface.
    - `help`: Prints useful info about the script
- **Requirements:** Must be run as root (`sudo`) to allow network interface manipulation.
- **Customization:** The script allows overriding default variables via the environment, such as the physical interface (`PHYS_IF`), the VLAN interface to probe (`VLAN10_IF`), and the DHCP timeout in seconds (`DHCP_WAIT`).