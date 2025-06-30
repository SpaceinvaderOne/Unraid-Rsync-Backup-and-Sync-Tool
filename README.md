# Unraid-Rsync-Backup-and-Sync-Tool

This is a modular, configurable `rsync` backup script designed to run on Unraid via the **User Scripts plugin**. It supports backing up folders locally or to a remote server, and can operate in either **archive** mode or **sync** mode.

---

##  Features

-  Supports multiple source folders
-  Archive mode with **versioned backups** using hardlinks
-  Sync mode with optional deletion tracking
-  Works with **local**, **remote**, or **both** destination types
-  SSH support (assumes keys are pre-shared)
-  Moves deleted files to timestamped folders instead of erasing them
-  Optional Unraid system notifications
-  Dry run mode for testing

---

##  How to Use

### 1. Install the User Scripts Plugin
- In the Unraid GUI, go to **Apps** and install **User Scripts**.

### 2. Create a New Script
- Open **User Scripts**.
- Click **Add New Script**.
- Name it something like `Rsync Backup`.
- Paste in the contents of `backup.sh` (from this repo).
- Click **Save Changes**.

### 3. Configure Variables

Edit the top section of the script inside the plugin UI. All user input is handled by hardcoded variables.

Here’s an overview of the key options:

###  Basic Settings

| Variable | Description |
|---------|-------------|
| `ENABLE_NOTIFICATIONS` | Show Unraid GUI notifications after the script runs (`yes` or `no`) |
| `CUSTOM_SERVER_NAME` | Optional label to appear in archive destination (defaults to hostname) |

###  Backup Mode

| Variable | Description |
|----------|-------------|
| `MODE` | Choose `archive` or `sync` |
| `STRICT_SYNC` | For sync mode only: `yes` to mirror (delete), `no` to move deleted files to a backup folder |
| `USE_HARDLINKS` | For archive mode only: `yes` to use hardlinks and enable versioned backups |

###  Destination Type

| Variable | Description |
|----------|-------------|
| `DEST_TYPE` | `local`, `remote`, or `both` (note: `both` is only valid in archive mode) |
| `DEST_SERVER_IP` | IP address of the remote server (SSH keys must already be exchanged) |
| `SSH_PORT` | SSH port on the remote server (default: 22) |

###  Source and Destination Folders

| Variable | Description |
|----------|-------------|
| `SOURCE_PATHS` | Array of full paths to source folders |
| `ARCHIVE_DEST` | Base folder for archive backups |
| `DEST_PATHS` | Array of full paths for each sync destination (must match number of sources) |
| `ALLOW_DEST_CREATION` | If `yes`, destination folders will be created if they don't exist |
| `DRY_RUN` | Set to `yes` to test without copying or deleting anything |

---

##  Mode Details

###  Archive Mode

- Copies all source folders into a single destination path.
- Adds a timestamped folder per run:  
  `/mnt/user/backups/YourServerName/2025-06-30_1730/`
- Creates or updates a `latest/` symlink to the newest backup.
- When `USE_HARDLINKS=yes`, unchanged files between runs are **hardlinked**, saving space.

###  Sync Mode

- Each source folder maps directly to a destination path.
- When `STRICT_SYNC=yes`, the script uses `rsync --delete` to mirror exactly.
- When `STRICT_SYNC=no`, deleted files are moved to:  
  `/destination/deleted_from_sync/YYYY-MM-DD_HHMM/`

---



