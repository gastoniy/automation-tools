# UserLandingScript

Idempotent Linux user provisioning from a simple CSV. `user-landing.sh` reads a
list of `username, group(s), ssh_pub_key` records and reconciles the machine to
match it: it creates any missing users, ensures their groups exist and that each
user belongs to them, and installs each SSH public key into the user's
`~/.ssh/authorized_keys`.

Running it repeatedly is safe — it never fails on or duplicates work already
done, and a bad row (e.g. a malformed SSH key) is logged and skipped without
stopping the rest of the run.

## Usage

```bash
sudo ./user-landing.sh users.csv
```

It must run as **root** because it calls `useradd`, `groupadd`, and `usermod`.

## Config format

One record per line, comma separated:

```csv
username, group(s), ssh_pub_key
```

| Field         | Notes                                                                       |
|---------------|-----------------------------------------------------------------------------|
| `username`    | Must match `[a-z_][a-z0-9_-]*`.                                              |
| `group(s)`    | A single group, or several separated by `;` (e.g. `sudo;docker`). Added as **supplementary** groups. Leave empty for none. |
| `ssh_pub_key` | The full public key line (type + base64 body + optional comment).           |

- Lines starting with `#` and blank lines are ignored.
- Whitespace around each field is trimmed; CRLF files are handled.
- A header line whose key column is literally `ssh_pub_key` is skipped.

See [`users.csv.example`](users.csv.example) for a sample.

## What it does per row

1. Validates the username, and validates the SSH key **before** any changes —
   with `ssh-keygen -l` when available (a regex fallback otherwise). A malformed
   or missing key skips that user entirely.
2. Creates the user with a home directory and `/bin/bash` shell if they don't
   already exist (`useradd -m`).
3. Ensures each named group exists (`groupadd` if missing) and adds the user to
   it (`usermod -aG`, additive).
4. Appends the SSH key to `~/.ssh/authorized_keys` only if it isn't already
   there, then fixes ownership and permissions (`.ssh` = 700, `authorized_keys`
   = 600).

At the end it prints a summary and exits non-zero if any row errored.

## Idempotency

| Operation          | Guard                                             |
|--------------------|---------------------------------------------------|
| `useradd`          | `getent passwd` existence check                   |
| `groupadd`         | `getent group` existence check                    |
| group membership   | `usermod -aG` is inherently additive / a no-op    |
| SSH key append     | `grep -qxF` exact-line match before appending     |
| permissions/owner  | re-applied deterministically on every run         |

## Testing

This creates **real** system users, so test in a throwaway container or VM, not
on a machine you care about:

```bash
docker run --rm -it -v "$PWD":/w -w /w ubuntu bash
# inside the container:
apt-get update && apt-get install -y openssh-client   # for ssh-keygen
./user_landing.sh users.csv        # first run
./user_landing.sh users.csv        # second run: no dupes, no errors
```

Then verify: `getent passwd <user>`, `id <user>` (group membership),
`ls -la /home/<user>/.ssh` (700 / 600), and that `authorized_keys` has no
duplicate lines after the second run.
