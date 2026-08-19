A lightweight, timeout-based port scanner utilizing `nc` (netcat) to rapidly verify service availability across multiple hosts in an infrastructure fleet.

- **Usage:** `./fleet_port_scanner.sh fleet-config.example`. 
- **Input Configuration:** Requires a colon-separated configuration file formatted as `host:port:protocol`. The script safely ignores empty lines and comments, and automatically defaults to TCP if the protocol is omitted.
- **Execution:** Applies a strict 3-second timeout per connection attempt, printing an `OK` or `FAILED` status directly to the console alongside the tested protocol.