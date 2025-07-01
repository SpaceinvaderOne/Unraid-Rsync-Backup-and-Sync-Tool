#!/bin/bash
# set -x # Uncomment for debugging only

# === START OF USER CONFIGURATION ===
# --- Fill in your details below ---

# --- General Settings ---

ENABLE_NOTIFICATIONS="yes"      # 'yes' or 'no'. Send a notification to Unraid on success or failure.
                                # Requires notification agents to be set up in Unraid's GUI (Settings -> Notification Settings).

CUSTOM_SERVER_NAME=""           # Optional. Leave blank to use this server's real hostname (e.g., "Tower").
                                # Set a custom name here to change the top-level folder name for your archives, e.g., "MyMediaServer".

# --- Primary Backup Strategy ---

MODE="archive"                  # 'archive' or 'sync'. This is the most important setting.
                                # 'archive': Creates a new, timestamped, versioned backup every time. Good for historical data.
                                # 'sync':    Mirrors a source to a destination, making them identical. Good for a simple 1-to-1 copy.

# --- Sync Mode Settings (These only apply if MODE = 'sync') ---

STRICT_SYNC="no"                # This controls what happens to files that are deleted from your source folder.
                                # 'no' (Safer): When a file is deleted from the source, it is MOVED to a 'deleted_from_sync' folder
                                #               on the destination. You won't lose it by accident.
                                # 'yes' (Riskier): When a file is deleted from the source, it is PERMANENTLY DELETED from the destination.

# --- Archive Mode Settings (These only apply if MODE = 'archive') ---

USE_HARDLINKS="yes"             # 'yes' or 'no'.
                                # 'yes' (Recommended): Saves a huge amount of disk space. Unchanged files are "linked" to the previous backup
                                # instead of being copied again. The backup still looks like a full copy.
                                # 'no': Creates a full, complete copy of all files every time. Uses much more disk space.

# --- Destination Settings ---

DEST_TYPE="local"               # 'local', 'remote', or 'both'. Defines where the backup will be sent.
                                # 'local':  Backs up to a folder on this same Unraid server.
                                # 'remote': Backs up to another server using SSH.
                                # 'both':   (Archive mode only) Backs up to both a local AND a remote destination.

# --- Remote Server Details (Ignored if DEST_TYPE = 'local') ---

DEST_SERVER_IP="192.168.1.100"  # The IP address or hostname of the remote server.
SSH_PORT=22                     # The SSH port of the remote server. 22 is standard.

# --- Path Definitions ---

# The folder(s) you want to back up.
# Add more paths inside the parentheses, each on a new line and in quotes.
# NOTE: Paths with spaces are fine. The script handles trailing slashes automatically.
SOURCE_PATHS=(
  "/mnt/user/source_test/source 1"
  "/mnt/user/source_test/source 2/"
)

# The destination folder for LOCAL archive backups (if DEST_TYPE is 'local' or 'both').
ARCHIVE_DEST_LOCAL="/mnt/user/archive_backups"

# The destination folder for REMOTE archive backups (if DEST_TYPE is 'remote' or 'both').
ARCHIVE_DEST_REMOTE="/mnt/user/backups/archives"

# The destination folder(s) for 'sync' mode.
# IMPORTANT: The first source in SOURCE_PATHS syncs to the first destination here, the second to the second, and so on.
DEST_PATHS=(
  "/mnt/user/sync_destination/dest 1"
  "/mnt/user/sync_destination/dest 2"
)


# --- Advanced Settings ---

ALLOW_DEST_CREATION="no"        # 'no' or 'yes'.
                                # 'no' (Safer Default): The script will stop with an error if a destination folder is missing.
                                #                       This is recommended because it forces you to create the destination share yourself,
                                #                       ensuring it has the correct Unraid settings (e.g., correct pool, cache settings, etc.).
                                # 'yes': If a destination folder doesn't exist, the script will create it. BE CAREFUL: If the parent share
                                #        doesn't exist, Unraid may create it with default settings, which might not be what you want.

DRY_RUN="no"                    # 'yes' or 'no'.
                                # 'yes': Simulates the backup and shows what files WOULD be copied/deleted, but makes NO actual changes.
                                #        Perfect for testing your settings safely!
                                # 'no': Performs the real backup.

# === END OF USER CONFIGURATION ===


# === SCRIPT LOGIC (No need to edit below) ===

# --- Normalisation and Setup ---
NOW=$(date "+%Y-%m-%d_%H%M")
# Sanitize custom server name to prevent path manipulation, then set the final server name
sanitized_custom_name=$(echo "$CUSTOM_SERVER_NAME" | sed 's|/||g')
SOURCE_SERVER_NAME="${sanitized_custom_name:-$(hostname)}"
LATEST_SYMLINK="latest"
DELETED_FOLDER_BASE="deleted_from_sync"

# --- Core Functions ---
log() { echo -e "[INFO] $1"; }
error_exit() { echo -e "\n[ERROR] $1" >&2; notify_unraid "Backup Failed" "$1" "alert"; exit 1; }

notify_unraid() {
  # NOTE: For notifications to work, you must have agents configured and working
  # in your Unraid GUI under Settings -> Notification Settings.
  # Test them there first!
  [[ "${ENABLE_NOTIFICATIONS,,}" == "yes" ]] || return
  /usr/local/emhttp/webGui/scripts/notify -e "Backup Script" -s "$1" -d "$2" -i "$3"
}

check_ssh_connection() {
  if [[ "${DEST_TYPE,,}" == "remote" || "${DEST_TYPE,,}" == "both" ]]; then
    log "Checking SSH connection to $DEST_SERVER_IP..."
    ssh -p "$SSH_PORT" "$DEST_SERVER_IP" 'echo connected' 2>/dev/null || error_exit "SSH connection failed. Ensure SSH keys are exchanged and the server is reachable."
  fi
}

validate_paths() {
  log "Validating paths and settings..."
  if [[ "${MODE,,}" == "sync" && "${#SOURCE_PATHS[@]}" -ne "${#DEST_PATHS[@]}" ]]; then
    error_exit "Source and destination arrays must be the same length in sync mode."
  fi
  if [[ "${MODE,,}" == "sync" && "${DEST_TYPE,,}" == "both" ]]; then
    error_exit "Cannot use DEST_TYPE=both with sync mode. Only allowed for archive mode."
  fi

  if [ ${#SOURCE_PATHS[@]} -eq 0 ]; then
    error_exit "No source paths defined. Nothing to back up."
  fi

  for src in "${SOURCE_PATHS[@]}"; do
    if [[ ! -d "$src" ]]; then
      error_exit "Source path does not exist: $src"
    fi
  done

  if [[ "${MODE,,}" == "archive" && ( "${DEST_TYPE,,}" == "local" || "${DEST_TYPE,,}" == "both" ) ]]; then
    local clean_archive_dest_local="${ARCHIVE_DEST_LOCAL%/}"
    if [[ ! -d "$clean_archive_dest_local" ]]; then
      if [[ "${ALLOW_DEST_CREATION,,}" == "yes" ]]; then
        mkdir -p "$clean_archive_dest_local" || error_exit "Failed to create local archive destination: $clean_archive_dest_local"
      else
        error_exit "Local archive destination '$clean_archive_dest_local' missing. Set ALLOW_DEST_CREATION=yes to auto-create."
      fi
    fi
  fi
  log "All paths and settings are valid."
}

make_safe_name() {
  echo "${1#/}" | sed 's|/|-|g'
}

run_archive_mode() {
  # --- Remote Operations ---
  if [[ "${DEST_TYPE,,}" == "remote" || "${DEST_TYPE,,}" == "both" ]]; then
    log "Processing remote archive..."
    local clean_archive_dest="${ARCHIVE_DEST_REMOTE%/}"
    # CRITICAL FIX: Corrected typo from `clean_archive__dest` to `clean_archive_dest`
    local base_path="$clean_archive_dest/$SOURCE_SERVER_NAME"
    local destination_path="$base_path/$NOW"
    local latest_path="$base_path/$LATEST_SYMLINK"

    ssh -p "$SSH_PORT" "$DEST_SERVER_IP" "mkdir -p '$destination_path'" || error_exit "Remote mkdir failed for '$destination_path'"

    for src in "${SOURCE_PATHS[@]}"; do
      local safe_name=$(make_safe_name "${src%/}")
      local specific_link_dest="$latest_path/$safe_name"
      local rsync_opts=(-a --no-whole-file)
      [[ "${DRY_RUN,,}" == "yes" ]] && rsync_opts+=(--dry-run)
      if [[ "${USE_HARDLINKS,,}" == "yes" ]] && ssh -p "$SSH_PORT" "$DEST_SERVER_IP" "[ -d '$specific_link_dest' ]"; then
          rsync_opts+=(--link-dest="$specific_link_dest")
      fi
      log "Archiving '$src' to remote..."
      rsync "${rsync_opts[@]}" -e "ssh -p '$SSH_PORT'" "${src%/}/" "$DEST_SERVER_IP:$destination_path/$safe_name/" || error_exit "Archive failed for remote source: $src"
    done
    ssh -p "$SSH_PORT" "$DEST_SERVER_IP" "ln -snf '$destination_path' '$latest_path'" || error_exit "Failed to update remote latest symlink"
  fi

  # --- Local Operations ---
  if [[ "${DEST_TYPE,,}" == "local" || "${DEST_TYPE,,}" == "both" ]]; then
    log "Processing local archive..."
    local clean_archive_dest="${ARCHIVE_DEST_LOCAL%/}"
    local base_path="$clean_archive_dest/$SOURCE_SERVER_NAME"
    local destination_path="$base_path/$NOW"
    local latest_path="$base_path/$LATEST_SYMLINK"

    mkdir -p "$destination_path" || error_exit "Failed to create local destination path: '$destination_path'"

    for src in "${SOURCE_PATHS[@]}"; do
      local safe_name=$(make_safe_name "${src%/}")
      local specific_link_dest="$latest_path/$safe_name"
      local rsync_opts=(-a)
      [[ "${DRY_RUN,,}" == "yes" ]] && rsync_opts+=(--dry-run)
      if [[ "${USE_HARDLINKS,,}" == "yes" && -d "$specific_link_dest" ]]; then
          rsync_opts+=(--link-dest="$specific_link_dest")
      fi
      log "Archiving '$src' to local..."
      rsync "${rsync_opts[@]}" "${src%/}/" "$destination_path/$safe_name/" || error_exit "Archive failed for local source: $src"
    done
    ln -snf "$destination_path" "$latest_path" || error_exit "Failed to update local latest symlink"
  fi
}

run_sync_mode() {
  local timestamp_folder="$DELETED_FOLDER_BASE/$NOW"

  for i in "${!SOURCE_PATHS[@]}"; do
    local src="${SOURCE_PATHS[$i]%/}"
    local dst="${DEST_PATHS[$i]%/}"
    local full_backup_dir="$dst/$timestamp_folder"
    local rsync_opts=(-a)
    [[ "${DRY_RUN,,}" == "yes" ]] && rsync_opts+=(--dry-run)

    if [[ "${STRICT_SYNC,,}" == "yes" ]]; then
      rsync_opts+=(--delete)
    else
      rsync_opts+=(--delete --backup --backup-dir="$full_backup_dir" --filter="P $DELETED_FOLDER_BASE/")
    fi

    log "Syncing '$src' to '$dst'..."
    if [[ "${DEST_TYPE,,}" == "remote" ]]; then
      ssh -p "$SSH_PORT" "$DEST_SERVER_IP" "mkdir -p '$dst'" || error_exit "Remote path create failed: $dst"
      rsync "${rsync_opts[@]}" -e "ssh -p '$SSH_PORT'" "$src/" "$DEST_SERVER_IP:$dst/" || error_exit "Sync failed for $src -> $dst"
    else
      if [[ ! -d "$dst" ]]; then
          if [[ "${ALLOW_DEST_CREATION,,}" == "yes" ]]; then
              mkdir -p "$dst" || error_exit "Failed to create local destination: $dst"
          else
              error_exit "Destination path does not exist: $dst"
          fi
      fi
      rsync "${rsync_opts[@]}" "$src/" "$dst/" || error_exit "Sync failed for $src -> $dst"
      if [[ "${STRICT_SYNC,,}" == "no" && -d "$full_backup_dir" && -z "$(ls -A "$full_backup_dir" 2>/dev/null)" ]]; then
        rmdir "$full_backup_dir" && rmdir "$(dirname "$full_backup_dir")" 2>/dev/null || true
      fi
    fi
  done
}

# === Main flow ===
main() {
  echo "================================================="
  log "Backup Script Started: $(date)"
  log "Mode: ${MODE}, Destination: ${DEST_TYPE}"
  echo "-------------------------------------------------"

  check_ssh_connection
  validate_paths

  echo "-------------------------------------------------"
  log "Starting main backup operation..."

  if [[ "${MODE,,}" == "archive" ]]; then
    run_archive_mode
  elif [[ "${MODE,,}" == "sync" ]]; then
    run_sync_mode
  else
    error_exit "Invalid MODE set. Use 'archive' or 'sync'."
  fi

  echo "-------------------------------------------------"
  log "Backup script completed successfully."
  echo "================================================="
  notify_unraid "Backup Complete" "All tasks completed successfully." "normal"
}

# --- Run the script ---
main