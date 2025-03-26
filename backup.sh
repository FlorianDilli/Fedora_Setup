#!/usr/bin/env bash

# ------------------------------------------------------------------
# --- Configuration ---
# ------------------------------------------------------------------

# Base directory for backups within Filen
FILEN_DIR="/home/florian/Filen"
# External SSD mount point base
EXTERNAL_DRIVE_BASE="/run/media/florian/FloriansSSD"
# Specific backup path on the SSD
EXTERNAL_BACKUP_DIR="$EXTERNAL_DRIVE_BASE/Dokumente/Filen_Backup"

# Source Directories
FEDORA_SETUP_DIR="/home/florian/Fedora_Setup"
OBSIDIAN_DIR="/home/florian/Obsidian"

# Destination Directories (derived)
FEDORA_BACKUP_DIR="$FILEN_DIR/Fedora_Setup_Backup"
OBSIDIAN_BACKUP_DIR="$FILEN_DIR/Obsidian_Backup"

# --- End Configuration ---


# ------------------------------------------------------------------
# --- Color Definitions (for visual output) ---
# ------------------------------------------------------------------
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'
COLOR_BOLD='\033[1m'

# ------------------------------------------------------------------
# --- Function Definitions ---
# ------------------------------------------------------------------

# Function: Print a formatted header for a backup task
print_header() {
    local name="$1"
    echo -e "\n${COLOR_BLUE}============================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}=== ${COLOR_BOLD}Starting Backup Task: ${COLOR_YELLOW}${name}${COLOR_RESET}${COLOR_BLUE} ===${COLOR_RESET}"
    echo -e "${COLOR_BLUE}============================================================${COLOR_RESET}"
}

# Function: Print a formatted footer/status for a backup task
print_footer() {
    local name="$1"
    local status_code="$2" # 0 for success, non-zero for failure

    echo # Add a newline before the status line
    if [ "$status_code" -eq 0 ]; then
        echo -e "${COLOR_GREEN}--- ${COLOR_BOLD}Backup Task SUCCEEDED: ${COLOR_YELLOW}${name}${COLOR_RESET}${COLOR_GREEN} ---${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}!!! ${COLOR_BOLD}Backup Task FAILED: ${COLOR_YELLOW}${name}${COLOR_RESET}${COLOR_RED} (Exit Code: ${status_code}) !!!${COLOR_RESET}" >&2 # Send errors to stderr
    fi
     echo -e "${COLOR_BLUE}============================================================${COLOR_RESET}\n"
}

# Function: Print info messages
print_info() {
    echo -e "${COLOR_CYAN}INFO:${COLOR_RESET} $1"
}

# Function: Print error messages
print_error() {
    echo -e "${COLOR_RED}ERROR:${COLOR_RESET} $1" >&2 # Send errors to stderr
}

# Function: Check if Directory Exists and Create if Needed
# Returns 0 on success, 1 on failure
check_dir() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        print_info "Destination directory does not exist. Creating: ${COLOR_YELLOW}${dir_path}${COLOR_RESET}"
        mkdir -p "$dir_path"
        if [ $? -ne 0 ]; then
            print_error "Could not create directory ${COLOR_YELLOW}${dir_path}${COLOR_RESET}"
            return 1 # Signal failure
        fi
    fi
    return 0 # Signal success
}

# Function: Perform Backup using rsync
# Returns rsync's exit code
do_backup() {
    local source="$1"
    local dest="$2"
    local name="$3"
    shift 3
    local rsync_options=("$@") # Store remaining args as an array for robust handling

    print_header "$name"
    print_info "Source:      ${COLOR_YELLOW}${source}${COLOR_RESET}"
    print_info "Destination: ${COLOR_YELLOW}${dest}${COLOR_RESET}"
    if [ ${#rsync_options[@]} -gt 0 ]; then
        print_info "rsync opts:  ${COLOR_YELLOW}${rsync_options[*]}${COLOR_RESET}"
    fi
    echo # Add a newline before potential mkdir output

    # Check/create destination directory
    if ! check_dir "$dest"; then
        # Error already printed by check_dir
        print_footer "$name" 1 # Print failure footer
        return 1 # Indicate failure
    fi

    echo # Add a newline before rsync output
    print_info "Running rsync..."

    # Execute rsync
    # Options explained:
    # -a : archive mode (recursive, preserves symlinks, permissions, times, group, owner, devices)
    # -h : human-readable numbers
    # --info=progress2 : Shows overall progress percentage and stats, less verbose than -v per file
    # "${rsync_options[@]}" : Pass any extra options provided (like --delete, --exclude)
    # "$source/" : Trailing slash copies contents *into* dest
    # "$dest/" : Destination directory
    rsync -ah --info=progress2 "${rsync_options[@]}" "$source/" "$dest/"
    local rsync_exit_code=$?

    # Print footer based on rsync status
    print_footer "$name" "$rsync_exit_code"
    return $rsync_exit_code
}

# ------------------------------------------------------------------
# --- Main Backup Execution ---
# ------------------------------------------------------------------

echo -e "${COLOR_BOLD}${COLOR_YELLOW}Starting Backup Script Execution...${COLOR_RESET}"
overall_status=0 # 0 = success, 1 = failure encountered

# --- Task 1: Fedora Setup Backup ---
# We exclude hidden files/directories (.*) for this specific backup
if ! do_backup "$FEDORA_SETUP_DIR" "$FEDORA_BACKUP_DIR" "Fedora Setup" --exclude='.*'; then
    overall_status=1 # Mark failure if this task fails
fi

# --- Task 2: Obsidian Backup ---
# We include all files, including hidden ones (like .obsidian), by default
if ! do_backup "$OBSIDIAN_DIR" "$OBSIDIAN_BACKUP_DIR" "Obsidian"; then
    overall_status=1 # Mark failure if this task fails
fi

# --- Task 3: Filen to External SSD ---
# Check if the external drive appears mounted before attempting backup
if [ -d "$EXTERNAL_DRIVE_BASE" ]; then
    print_info "External drive detected at ${COLOR_YELLOW}${EXTERNAL_DRIVE_BASE}${COLOR_RESET}."
    # Using options similar to your separate rsync block:
    # --delete : delete files on the destination that don't exist on the source
    # --append-verify : resume interrupted transfers, verify checksum after append (can be slower)
    # --exclude='.*' : exclude hidden files/directories at the top level
    # Note: --exclude='.*/' is usually covered by --exclude='.*' when applied recursively
    if ! do_backup "$FILEN_DIR" "$EXTERNAL_BACKUP_DIR" "Filen to External SSD" --delete --append-verify --exclude='.*'; then
        overall_status=1 # Mark failure if this task fails
    fi
else
    # External drive not found, print a warning and mark as overall failure
    print_header "Filen to External SSD"
    print_error "External drive mount point ${COLOR_YELLOW}${EXTERNAL_DRIVE_BASE}${COLOR_RESET} not found."
    print_info "Skipping this backup task."
    print_footer "Filen to External SSD" 1 # Explicitly mark task as failed/skipped
    overall_status=1
fi


# ------------------------------------------------------------------
# --- Final Summary ---
# ------------------------------------------------------------------

echo -e "${COLOR_BOLD}${COLOR_YELLOW}Backup Script Execution Finished.${COLOR_RESET}"
if [ $overall_status -eq 0 ]; then
    echo -e "${COLOR_GREEN}${COLOR_BOLD}All backup tasks completed successfully.${COLOR_RESET}"
    exit 0
else
    echo -e "${COLOR_RED}${COLOR_BOLD}One or more backup tasks failed or were skipped. Please review the output above.${COLOR_RESET}" >&2
    exit 1
fi
