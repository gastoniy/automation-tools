This bash script performs concurrent HTTP status checks against a list of target URLs using `curl`. It evaluates the responses, marking endpoints that return `2XX` or `3XX` status codes as operational.

- **Usage:** `./check_health.sh http-health-config.example`.  
- **Input Configuration:** Requires a plain text file containing one target URL per line.
- **Output:** Generates a timestamped CSV log file (e.g., `http_health_logs_YYYY-MM-DD_HH-MM-SS.csv`) that records the URL, the specific HTTP status code received, and an overall `UP`, `DOWN`, or `ERROR` status.