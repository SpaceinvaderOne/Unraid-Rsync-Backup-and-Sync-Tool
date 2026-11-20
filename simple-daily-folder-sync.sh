#!/bin/bash
# A very simple rsync demo for 2 folders
# Replace the placeholders, including the angle brackets.
source_dir="/mnt/user/<SOURCE_SHARE>/"
destination="root@<BACKUP_SERVER_IP>:/mnt/user/<BACKUP_SHARE>/<DEDICATED_FOLDER>/"

# Mirror the contents. Files deleted from the source are removed on the next run.
rsync -av --delete -e 'ssh -o BatchMode=yes' -- "${source_dir%/}/" "$destination"
