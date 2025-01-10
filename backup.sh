#!/usr/bin/bash

# ------------------------------------------------------------------
# --- Function Definitions ---
# ------------------------------------------------------------------

# Function: Check if Directory Exists and Create if Needed
check_dir() {
    if [ ! -d "$1" ]; then
        echo "Creating directory $1"
        mkdir -p "$1" || {
            echo "Error: Could not create directory $1"
            return 1
        }
    fi
    return 0
}

# Function: Perform Backup
do_backup() {
    local source="$1"
    local dest="$2"
    local name="$3"
    shift 3
    local rsync_options="$@"

    echo "Starting backup of $name..."
    
    check_dir "$dest"
    
    rsync -avc $rsync_options "$source/" "$dest/" || {
        echo "Error: rsync failed for $name"
        return 1
    }
}

# ------------------------------------------------------------------
# --- Backup Definitions ---
# ------------------------------------------------------------------

FILEN_DIR="/home/florian/Filen"

# Create backup-specific directories
FEDORA_BACKUP_DIR="$FILEN_DIR/Fedora_Setup_Backup"
OBSIDIAN_BACKUP_DIR="$FILEN_DIR/Obsidian_Backup"

# Backup: Fedora Setup
FEDORA_SETUP_DIR="/home/florian/Fedora_Setup"
check_dir "$FEDORA_BACKUP_DIR" || exit 1
do_backup "$FEDORA_SETUP_DIR" "$FEDORA_BACKUP_DIR" "Fedora Setup" --exclude '.*'

# Backup: Obsidian
OBSIDIAN_DIR="/home/florian/Dokumente/Obsidian"
check_dir "$OBSIDIAN_BACKUP_DIR" || exit 1
do_backup "$OBSIDIAN_DIR" "$OBSIDIAN_BACKUP_DIR" "Obsidian"

# Backup: Filen to External SSD
# Backup: Filen to External SSD
#EXTERNAL_BACKUP_DIR="/run/media/florian/FloriansSSD/Dokumente/Filen_Backup"
#check_dir "$EXTERNAL_BACKUP_DIR" || exit 1
#do_backup "$FILEN_DIR" "$EXTERNAL_BACKUP_DIR" "Filen to External SSD"


#------------------------
#!/bin/bash

FILEN_DIR="/home/florian/Filen"
EXTERNAL_BACKUP_DIR="/run/media/florian/FloriansSSD/Dokumente/Filen_Backup"

echo "Starting synchronization..."

# Use rsync with --append-verify, exclude hidden files/directories, and enable verbose output
echo "Building incremental file list..."
rsync -avvi --append-verify --delete --exclude='.*/' --exclude='.*' "$FILEN_DIR/" "$EXTERNAL_BACKUP_DIR/"

# Check the exit code of rsync
if [ $? -eq 0 ]; then
    echo "Synchronization complete!"
else
    echo "Synchronization completed with errors. Check the rsync output above."
fi
