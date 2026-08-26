# Custom Orphaned Resource Reaper (via Unix Sockets)

A single bash script that reaps long-running Docker containers based on business
logic the stock CLI can't express. `docker container prune` only ever touches
containers that are already stopped — it has no notion of "this thing has been
*running* too long" and no way to spare containers by an arbitrary label.
`orphan-reaper.sh` does exactly that: it stops any **running** container older
than *N* hours **unless** it carries a protected `environment=X` label.

It never shells out to the `docker` binary. Instead it talks straight to the
Docker Engine API over the daemon's Unix socket with `curl --unix-socket`, parses
the JSON with `jq`, and issues a graceful shutdown through the API itself.

## Key Features
* **Direct Daemon API:** Speaks HTTP to `/var/run/docker.sock` via `curl` + `jq` — no `docker` CLI dependency at all.
* **Custom Reaping Rule:** Stops containers whose uptime exceeds a threshold, *unless* they are labelled `environment=X` (a protected environment you choose).
* **Dual Age Basis:** Measure age from `started` (true uptime via `State.StartedAt`) or `created` (cheaper, since creation) — pick per run.
* **Safe by Default:** Runs as a **dry-run** that only reports what it would stop. Nothing is killed until you pass `--apply`.
* **Graceful Shutdown:** Uses `POST /containers/{id}/stop` (SIGTERM, then SIGKILL after a configurable grace period) — never a hard kill.
* **Flexible Execution:** Driven by direct CLI arguments or a central configuration file.
* **Audit Trail:** Writes a timestamped `container_reaper_*.csv` log of every decision on every run.

## Requirements
* `bash`, `curl`, `jq`, plus GNU `date`/`awk` (standard on Linux).
* Read/write access to the Docker socket — run as a user in the `docker` group (or as root).

## Usage
You can run the script using direct command-line arguments or by pointing it to a configuration file.

### Option A: Using CLI Arguments
Preview (dry-run) every container running longer than 12 hours, sparing production:

```bash
./orphan-reaper.sh --hours 12 --protect-env production
```

Then actually stop them, giving each 30 seconds to shut down gracefully:

```bash
./orphan-reaper.sh --hours 12 --protect-env production --apply --stop-timeout 30
```

Flags:

* `-H`, `--hours` : Uptime threshold in hours. Fractional values allowed (default `24`).
* `-e`, `--protect-env` : Exempt containers labelled `environment=<value>` (default `production`).
* `-b`, `--age-basis` : `started` for true uptime, or `created` for time since creation (default `started`).
* `-a`, `--apply` : Actually stop violators. Without it the script only reports (dry-run).
* `-t`, `--stop-timeout` : Graceful stop grace period in seconds before SIGKILL (default `10`).
* `-s`, `--socket` : Path to the Docker socket (default `/var/run/docker.sock`).
* `-f`, `--file` : Load all settings from a config file (not combinable with the flags above).
* `-h`, `--help` : Show the help message.

### Option B: Using a Configuration File (Recommended for Automation)

Copy the example configuration file:

```bash
cp reaper.conf.example reaper.conf
```

Edit `reaper.conf` with your preferred text editor, then run the script pointing to it:

```bash
./orphan-reaper.sh -f reaper.conf
```

Because `-f` supplies everything, it can't be combined with the value flags — the script will exit with an error if you try.

## How It Decides
For every **running** container the script computes an age and applies one rule:

> **Reap** when `age > N hours` **AND** the `environment` label is **not** the protected value.

* A container labelled `environment=<protected>` is always **exempt**, however old it is.
* A container with **no** `environment` label is **not** exempt — it doesn't match the protected value, so the age rule alone decides its fate.
* Containers younger than the threshold are left alone (`within-threshold`).

In dry-run mode each violator is reported as `[DRY-RUN] would stop <name>`; with `--apply` it is gracefully stopped and the result recorded.

## Testing
The script stops **real** containers, so exercise it against throwaway fixtures. Create three containers — one protected, one labelled otherwise, one unlabelled — then use `--hours 0` so any uptime qualifies:

```bash
docker run -d --name reap-dev     --label environment=dev        alpine sleep 100000
docker run -d --name reap-prod    --label environment=production alpine sleep 100000
docker run -d --name reap-nolabel                                alpine sleep 100000

./orphan-reaper.sh --hours 0             # dry-run: reap-dev + reap-nolabel flagged, reap-prod exempt
docker ps                                # all three still running — nothing was stopped
./orphan-reaper.sh --hours 0 --apply     # stops reap-dev + reap-nolabel, keeps reap-prod
docker ps                                # only reap-prod remains
```

Clean up afterwards:

```bash
docker rm -f reap-dev reap-prod reap-nolabel
```

## Exit Codes

| Code | Meaning                                                        |
|------|---------------------------------------------------------------|
| `0`  | Success — scan (and any stops) completed cleanly.             |
| `1`  | Runtime/API error, or one or more graceful stops failed.      |
| `2`  | Usage error — bad flag value (e.g. an invalid `--age-basis`). |
