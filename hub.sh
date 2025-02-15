#!/bin/bash
clear

# Source Pywal colors
if [ -f "$HOME/.cache/wal/colors.sh" ]; then
    . "$HOME/.cache/wal/colors.sh"
else
    echo "Pywal colors not found. Please run 'wal' to generate a color scheme."
    exit 1
fi

# Check if Gum is installed
if ! command -v gum &> /dev/null; then
    echo "Gum is not installed. Installing Gum..."
    sudo dnf install -y gum || { echo "Failed to install Gum."; exit 1; }
fi

# Menu structure with nested options
declare -A MENUS
MENUS=(
    ["main"]="System update|Backup|Sync Fedora_Setup to GitHub|Switch Color-Scheme|Show Pywal Colors|Other Scripts|Exit"
    ["Other Scripts"]="Post-Update Configuration|Post-Install Configuration|Install my Apps|Back"
)

declare -A COMMANDS
COMMANDS=(
    ["Backup"]="./backup.sh"
    ["System update"]="./update_system.sh"
    ["Sync Fedora_Setup to GitHub"]="./sync_to_github.sh"
    ["Install my Apps"]="./install_apps.sh"
    ["Post-Install Configuration"]="./ml4w_post_install.sh"
    ["Post-Update Configuration"]="./ml4w_post_update.sh"
    ["Switch Color-Scheme"]="./light-dark-mode.sh"
    ["Show Pywal Colors"]="./show-colors.sh"
)

# Header
HEADER=$(gum style --foreground "$color5" --bold --margin "1" --padding "1 1" --align left "
 _____                _____     _           
|  |  |_ _ ___ ___   |   __|___| |_ _ _ ___ 
|     | | | . |  _|  |__   | -_|  _| | | . |
|__|__|_  |  _|_|    |_____|___|_| |___|  _|
      |___|_|                          |_|  ")

current_menu="main"
while true; do
    clear
    echo "$HEADER"

    # Style the "Select an option:" text
    SELECT_TEXT=$(gum style --foreground "$color5" --bold "Select an option:")

    # Display the menu and highlight the selected item with Pywal colors, including the arrow
    choice=$(echo ${MENUS[$current_menu]} | tr '|' '\n' | gum choose --header="$SELECT_TEXT" \
        --selected.foreground="$color0" --selected.background="$color5"\
        --cursor.foreground="$color5")

    [ "$choice" = "Exit" ] && exit 0
    [ "$choice" = "Back" ] && { current_menu="main"; continue; }

    if [[ ${MENUS[$choice]} ]]; then
        current_menu="$choice"
        continue
    fi

    if [[ ${COMMANDS[$choice]} ]]; then
        if gum confirm "Run '$choice'?"; then
            clear
            echo "$HEADER"
            gum style --foreground "$color4" --bold "Running '$choice'..."
            bash "${COMMANDS[$choice]}"
            EXIT_STATUS=$?

            if [ $EXIT_STATUS -ne 0 ]; then
                gum style --foreground "$color1" --bold "Error executing '$choice'. Please check the script."
                read -p "Press Enter to continue..."
            else
                echo
                gum style --foreground "$color4" --bold "'$choice' completed successfully."
                read -p "Press Enter to continue..."
            fi
        fi
    fi
done

