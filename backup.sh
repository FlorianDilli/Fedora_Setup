#!/usr/bin/bash

# Define the directories
set filen_dir /home/florian/Filen
set filen_backup_dir /home/florian/Dokumente/Filen_Backup
set obsidian_dir /home/florian/Dokumente/Obsidian
set obsidian_backup_dir /home/florian/Dokumente/Obsidian_Backup
set scripts_dir /usr/local/bin
set scripts_backup_dir /home/florian/Filen/Ubuntu/Skripte

# Define colors
set purple '\033[35m'
set reset '\033[0m'

# Function to check if directory exists
function check_dir
    if not test -d $argv[1]
        echo -e "$purple""Error: Directory $argv[1] does not exist!""$reset"
        return 1
    end
    return 0
end

# Function to perform backup
function do_backup
    set source $argv[1]
    set dest $argv[2]
    set name $argv[3]
    
    echo -e "\n$purple╭─────────────────────────────────────────╮$reset"
    echo -e "$purple│        Starting backup of $name        │$reset"
    echo -e "$purple╰─────────────────────────────────────────╯$reset\n"

    # Perform rsync with file list output
    rsync -ahv --delete $source/ $dest/ | \
    while read -l line
        # Skip lines that contain progress information
        if not string match -q "*%" "$line"
            echo -e "$purple$line$reset"
        end
    end

    echo -e "\n$purple✓ Finished backing up $name successfully!$reset\n"
end

# Check if all directories exist (except scripts_backup_dir which will be created if needed)
for dir in $filen_dir $filen_backup_dir $obsidian_dir $obsidian_backup_dir $scripts_dir
    check_dir $dir; or exit 1
end

# Check if Filen directory is not empty
if test (count (ls -A $filen_dir)) -gt 0
    # Backup Filen
    do_backup $filen_dir $filen_backup_dir "Filen"
    
    # Create scripts backup directory if it doesn't exist
    mkdir -p $scripts_backup_dir

    # Backup scripts
    do_backup $scripts_dir $scripts_backup_dir "Scripts"
else
    echo -e "\n$purple""Filen directory is empty! Skipping Filen and Scripts backup...""$reset\n"
end

# Backup Obsidian
do_backup $obsidian_dir $obsidian_backup_dir "Obsidian"
