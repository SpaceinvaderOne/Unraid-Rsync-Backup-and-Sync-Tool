# Unraid Rsync Backup and Sync Tool

This script is a powerful and flexible backup tool for your Unraid server. It works with the **User Scripts** plugin to back up folders on your server. It supports versioned archives with hard linking, direct synchronization, and both local and remote destinations via SSH.

---

## Requirements

- **Unraid server**  
- **User Scripts plugin** (available in the Community Applications)  
- For remote backups:
  - SSH access between servers. This can be over local network or over Tailscale for offsite backups.
  - SSH keys exchanged [(Click this link for a script to do this for you)](https://github.com/SpaceinvaderOne/Easy_Unraid_SSHKey_Exchange)

---

## Installation

1. **Install the User Scripts plugin** if you haven’t already.  
   Open the Unraid web UI and go to **Apps** → search for **User Scripts**, then install it.

2. **Create a new script** inside the User Scripts plugin.  
   Give it a name like `my_backup`.

3. **Paste the script** contents into the script editor.

4. **Edit the USER CONFIGURATION section** of the script to match your needs.  
   This includes setting paths, mode, server type, etc.

5. **Set a schedule** inside the User Scripts plugin for when this backup should run — daily, weekly, or however often you want.

---

## How It Works

The script has two main modes:

### 1. Archive Mode (`MODE="archive"`)

This mode creates a **timestamped backup** of your source folders. It stores each run as a new snapshot and can save disk space using **hardlinks** (if enabled).

Each backup looks like a full copy of your files, but unchanged files are hardlinked from the previous run to save space.

You can back up:
- **Locally**, to a folder on the same Unraid server
- **Remotely**, to another Unraid server via SSH
- Or **both**, for redundancy

Example archive destination structure:

```
/mnt/user/archive backups/MyServer/
  ├── latest → 2025-07-01_1200
  ├── 2025-06-30_1200/
  ├── 2025-07-01_1200/
```

### 2. Sync Mode (`MODE="sync"`)

This mode mirrors a folder from the source to the destination, making them identical.

- If `STRICT_SYNC="yes"`, deleted files are removed from the destination.
- If `STRICT_SYNC="no"` (recommended), deleted files are moved to a `deleted_from_sync` folder with a timestamp for safety.

Example sync destination structure:

```
/mnt/user/sync_destination/dest 1/
  ├── your files...
  └── deleted_from_sync/
        └── 2025-07-01_1200/
```

---

## Configuration Guide

Open the script and edit the **USER CONFIGURATION** section at the top.

Here are the most important settings:

### General Settings

```bash
ENABLE_NOTIFICATIONS="yes"     # Show Unraid notifications on completion
CUSTOM_SERVER_NAME=""          # Optional name override (default: hostname)
```

### Backup Mode

```bash
MODE="archive"                 # Options: 'archive' or 'sync'
```

### Sync Mode Only

```bash
STRICT_SYNC="no"               # Options: 'no' (safe) or 'yes' (more risky will delete files that are not in the source)
```

### Archive Mode Only

```bash
USE_HARDLINKS="yes"            # Saves space by linking unchanged files
```

### Destination Settings

```bash
DEST_TYPE="local"              # Options: 'local', 'remote', or 'both'  (both only works in archive mode)
DEST_SERVER_IP="10.10.20.194"  # Remote server IP or hostname
SSH_PORT=22                    # SSH port (usually 22)
```

### Source and Destination Paths

```bash
SOURCE_PATHS=(
  "/mnt/user/source_test/source 1"
  "/mnt/user/source_test/source 2"
)

ARCHIVE_DEST_LOCAL="/mnt/user/archive backups"
ARCHIVE_DEST_REMOTE="/mnt/user/backups/archives"

DEST_PATHS=(
  "/mnt/user/sync_destination/dest 1"
  "/mnt/user/sync_destination/dest 2"
)
```

#### How to Use These

Each path must be listed inside parentheses, one per line, and enclosed in double quotes.  
This applies to both `SOURCE_PATHS` and `DEST_PATHS`.

For example:
- Two source folders = two quoted lines inside `SOURCE_PATHS`
- Two destination folders = two quoted lines inside `DEST_PATHS`

#### When Using Sync Mode

If `MODE="sync"`, then `DEST_PATHS` is **required**.

The script will sync each source folder to the destination at the **same position** in the list:
- The first source goes to the first destination
- The second source goes to the second destination
- And so on

If the number of destinations doesn't match the number of sources, the script will stop with an error.

#### When Using Archive Mode

`DEST_PATHS` is ignored in archive mode.

Instead, you configure:
- `ARCHIVE_DEST_LOCAL` — for local archive backups on the same Unraid server
- `ARCHIVE_DEST_REMOTE` — for archive backups sent over SSH to a remote server

If `DEST_TYPE="both"`, then both local and remote destinations will be used.  
This provides redundancy by keeping versioned archives on both servers.

The script will create a folder structure under each archive destination using the server name and a timestamp.  
It also creates a `latest` symlink pointing to the most recent backup.


### Advanced Settings

```bash
ALLOW_DEST_CREATION="no"      # Set to 'yes' to auto-create missing folders
DRY_RUN="no"                  # Set to 'yes' to simulate the backup only
```

#### `ALLOW_DEST_CREATION`

When set to `yes`, the script will automatically create any destination folders that are missing. This can be convenient, but use with caution:

- **Recommended setting: `no`**  
  It's best to manually create your destination folders ahead of time using the Unraid web interface. This ensures that:
  - The destination lives on the correct storage pool or the main array.
  - You can configure share-level settings like cache usage, SMB/NFS export, or security.
- If you let the script create a **top-level share** that doesn't already exist, Unraid may create it using default settings—which may not match your intended configuration.
- It's generally safe to use `ALLOW_DEST_CREATION="yes"` for subfolders **within an existing share**, but not for creating new top-level shares.

#### `DRY_RUN`

When set to `yes`, the script runs in **simulation mode**. No data will be copied, deleted, or modified. Instead, the script shows what actions *would* be taken. This is ideal for testing your configuration before allowing the script to perform real backups.

---

## Scheduling the Script

Once your script is configured:

1. Go to **User Scripts** in the Unraid GUI.
2. Find your script and click **Schedule**.
3. Choose when and how often it should run (e.g., every day).

---

## Notes and Best Practices

- Always test with `DRY_RUN="yes"` before running live for the first time.
- For **remote backups**, make sure SSH keys are set up or it will not work.
- Use `USE_HARDLINKS="yes"` to save space in archive mode (recommended).
- Monitor `/mnt/user/deleted_from_sync` if you use `sync` mode with `STRICT_SYNC="no"` — this is where deleted files go for safekeeping.

---

## Troubleshooting

If the script fails:

- Check Unraid notifications (if enabled)
- Uncommnet `# set -x` for detailed output to debug
 

---

## License

This script is free to use and modify. No warranty is provided.
