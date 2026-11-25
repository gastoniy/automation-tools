# Secure Auto Back Up
A robust, multithreaded bash script for secure and automated directory backups. 
Designed for reliability, it includes mount-point verification, archive integrity checks, and automated retention policies.
Firstly was created to backup Obsidian vault, but enhanced and modernized to archive different directories.

## Key Features
* **Multithreaded Compression:** Utilizes `zstd -T0` for lightning-fast, multi-core compression, saving both time and disk space.
* **Mount-Point Awareness:** Compares device IDs (`stat -c "%d"`) to prevent backing up data onto the same physical disk, avoiding infinite loops or disk exhaustion.
* **Data Integrity Verification:** Automatically verifies the `.tar.zst` archive immediately after creation.
* **Smart Error Handling:** Differentiates between fatal `tar` errors and expected warnings (e.g., when files are modified during the backup process).
* **Automated Cleanup:** Built-in rotation policy to find and remove backups older than a specified number of days.
* **Flexible Execution:** Can be driven via direct CLI arguments or a central configuration file.

## Installation
Clone the repository and make the script executable:

```bash
git clone [https://github.com/gastoniy/SecureAutoBackUp.git](https://github.com/gastoniy/SecureAutoBackUp.git)
cd SecureAutoBackUp
chmod +x AutoBackUp.sh
```

## Usage
You can run the script using direct command-line arguments or by pointing it to a configuration file.

### Option A: Using CLI Arguments
```
./AutoBackUp.sh -d "/var/www/html /etc/nginx" -t "/mnt/backup_drive" -c 14 -s
```
Flags:

* `-d`, `--back-up-dirs` : Source directories to back up (space-separated, enclosed in quotes).
* `-t`, `--target-directory` : Destination directory for the archives.
* `-c`, `--clean-up` : Number of days to keep old backups (default is 7 days if not specified).
* `-s`, `--secure-disk` : Fail strictly if the source and destination are on the same mount point.
* `-h`, `--help` : Show help message.

### Option B: Using a Configuration File (Recommended for Automation)

Copy the example configuration file:
```
cp autobackup.conf.example autobackup.conf
```
Edit autobackup.conf with your preferred text editor.

Run the script pointing to the config file:
```
./AutoBackUp.sh -f /path/to/autobackup.conf
```