#!/bin/bash
clear

# Check if Gum is installed
if ! command -v gum &> /dev/null; then
    echo "Gum is not installed. Installing Gum..."
    sudo dnf install -y gum || { echo "Failed to install Gum."; exit 1; }
fi

# Menu structure with nested options
declare -A MENUS
MENUS=(
    ["main"]="System Configuration|Backup Files and Scripts|Update System|Sync to GitHub|Exit"
    ["System Configuration"]="Install Applications|Post-Install Configuration|Update Rofi Colors|Back"
)

declare -A COMMANDS
COMMANDS=(
    ["Backup Files and Scripts"]="./backup.sh"
    ["Update System"]="./update_system.sh"
    ["Sync to GitHub"]="./sync_to_github.sh"
    ["Install Applications"]="./install_apps.sh"
    ["Post-Install Configuration"]="./ml4w_post_install.sh"
    ["Update Rofi Colors"]="./update_rofi_color.sh"
)

# Header
HEADER=$(gum style --foreground 212 --background 0 --bold --margin "1" --padding "1 1" --align left "
 _____                _____     _           
|  |  |_ _ ___ ___   |   __|___| |_ _ _ ___ 
|     | | | . |  _|  |__   | -_|  _| | | . |
|__|__|_  |  _|_|    |_____|___|_| |___|  _|
      |___|_|                          |_|  ")

current_menu="main"
while true; do
    echo "$HEADER"
    choice=$(echo ${MENUS[$current_menu]} | tr '|' '\n' | gum choose --header="Select an option:")
    
    [ "$choice" = "Exit" ] && exit 0
    [ "$choice" = "Back" ] && { current_menu="main"; continue; }
    
    if [[ ${MENUS[$choice]} ]]; then
        current_menu="$choice"
        continue
    fi

    if [[ ${COMMANDS[$choice]} ]]; then
        gum confirm "Run '$choice'?" && {
            bash -c "${COMMANDS[$choice]}" || echo "Error executing '$choice'"
            gum style --foreground 212 --bold "'$choice' completed."
        }
    fi
done
