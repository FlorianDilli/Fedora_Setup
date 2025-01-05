#!/usr/bin/bash

# --- Define Directories ---
FILEN_DIR="/home/florian/Filen"
FILEN_BACKUP_DIR="/home/florian/Dokumente/Filen_Backup"
OBSIDIAN_DIR="/home/florian/Dokumente/Obsidian"
OBSIDIAN_BACKUP_DIR="/home/florian/Dokumente/Obsidian_Backup"
SCRIPTS_DIR="/usr/local/bin"
SCRIPTS_BACKUP_DIR="/home/florian/Filen/Ubuntu/Skripte"

# --- Define Colors ---
PURPLE='\033[35m'
RESET='\033[0m'

# --- Function: Check if Directory Exists ---
check_dir() {
    if [ ! -d "$1" ]; then
        echo -e "${PURPLE}Error: Directory $1 does not exist!${RESET}"
        return 1
    fi
    return 0
}

# --- Function: Perform Backup ---
do_backup() {
    local source="$1"
    local dest="$2"
    local name="$3"
    
    echo -e "\n${PURPLE}╭─────────────────────────────────────────╮${RESET}"
    echo -e "${PURPLE}│        Starting backup of $name        │${RESET}"
    echo -e "${PURPLE}╰─────────────────────────────────────────╯${RESET}\n"

    # Perform rsync with file list output
    rsync -ahv --delete "$source/" "$dest/" | while read -r line; do
        # Skip lines that contain progress information
        if [[ ! "$line" =~ "% " ]]; then
            echo -e "${PURPLE}$line${RESET}"
        fi
    done

    echo -e "\n${PURPLE}✓ Finished backing up $name successfully!${RESET}\n"
}

# --- Check Directories ---
for dir in "$FILEN_DIR" "$FILEN_BACKUP_DIR" "$OBSIDIAN_DIR" "$OBSIDIAN_BACKUP_DIR" "$SCRIPTS_DIR"; do
    check_dir "$dir" || exit 1
done

# --- Backup Filen and Scripts ---
if [ "$(ls -A "$FILEN_DIR")" ]; then
    # Backup Filen
    do_backup "$FILEN_DIR" "$FILEN_BACKUP_DIR" "Filen"
    
    # Create scripts backup directory if it doesn't exist
    mkdir -p "$SCRIPTS_BACKUP_DIR"

    # Backup scripts
    do_backup "$SCRIPTS_DIR" "$SCRIPTS_BACKUP_DIR" "Scripts"
else
    echo -e "\n${PURPLE}Filen directory is empty! Skipping Filen and Scripts backup...${RESET}\n"
fi

# --- Backup Obsidian ---
do_backup "$OBSIDIAN_DIR" "$OBSIDIAN_BACKUP_DIR" "Obsidian"

