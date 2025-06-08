#!/bin/bash
clear

# Source Pywal/Wallust colors
if [ -f "$HOME/.cache/wallust/shell-colors.sh" ]; then
    . "$HOME/.cache/wallust/shell-colors.sh"
elif [ -f "$HOME/.cache/wal/colors.sh" ]; then # Fallback for original  Pywal
    . "$HOME/.cache/wal/colors.sh"
else
    echo "Pywal/Wallust colors not found. Please run 'wal' or 'wallust' to generate a color scheme."
    exit 1
fi

# Ensure the PATH includes the directory for user-installed binaries like 'rich'.
# This makes it available to all sub-scripts called from this menu.
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Check if Gum is installed
if ! command -v gum &> /dev/null; then
    echo "Gum is not installed. Installing Gum..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y gum || { echo "Failed to install Gum using dnf."; exit 1; }
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y gum || { echo "Failed to install Gum using apt-get."; exit 1; }
    elif command -v pacman &> /dev/null; then
        sudo pacman -Syu --noconfirm gum || { echo "Failed to install Gum using pacman."; exit 1; }
    else
        echo "Could not determine package manager to install Gum. Please install it manually."
        exit 1
    fi
fi

# --- Configuration Section: Easy to Add/Remove/Reorder Scripts --- 
declare -a MENU_DEFINITIONS=(
    "System update|./update_system.sh"
    "Sync with Filen|./backup.sh"
    "Sync Repositories to GitHub|./sync_to_github.sh"
    "Switch to Dark/Light mode|./light-dark-mode.sh"
    "Show Wallust colors|./show-colors.sh"
    "Fedora-Setup post-install config|./ml4w_post_install.sh"
    "Install my Apps|./install_apps.sh"
)
# --- End Configuration Section ---

# Header
HEADER=$(gum style --foreground "$color5" --bold --margin "1" --padding "1 1" --align left "
 _____                _____     _
|  |  |_ _ ___ ___   |   __|___| |_ _ _ ___
|     | | | . |  _|  |__   | -_|  _| | | . |
|__|__|_  |  _|_|    |_____|___|_| |___|  _|
      |___|_|                          |_|  ")

while true; do
    clear
    echo "$HEADER"

    options_for_gum=()
    for item_definition in "${MENU_DEFINITIONS[@]}"; do
        display_name="${item_definition%%|*}"
        options_for_gum+=("$display_name")
    done
    options_for_gum+=("Exit")

    SELECT_TEXT=$(gum style --foreground "$color5" --bold "Select an option:")

    choice=$(printf "%s\n" "${options_for_gum[@]}" | gum choose --header="$SELECT_TEXT" \
        --selected.foreground="${color0:-#000000}" --selected.background="${color5:-#FFFFFF}" \
        --cursor.foreground="${color5:-#FFFFFF}" \
        --height $(( ${#options_for_gum[@]} + 2 )) )

    if [ -z "$choice" ] || [ "$choice" = "Exit" ]; then
        clear
        exit 0
    fi

    script_to_run=""
    for item_definition in "${MENU_DEFINITIONS[@]}"; do
        display_name="${item_definition%%|*}"
        if [ "$display_name" = "$choice" ]; then
            script_to_run="${item_definition#*|}"
            break
        fi
    done

    if [ -n "$script_to_run" ]; then
        if gum confirm "Run '$choice'?"; then
            clear
            echo "$HEADER"
            gum style --foreground "$color4" --bold "Running '$choice'..."
            
            EXIT_STATUS=0 # Default to success

            if [ -f "$script_to_run" ]; then
                # Determine how to execute the script
                if [ -x "$script_to_run" ]; then
                    # If the script is executable, run it directly.
                    # The shebang (e.g., #!/bin/bash or #!/usr/bin/env python3) will be respected.
                    "$script_to_run"
                    EXIT_STATUS=$?
                elif [[ "$script_to_run" == *.sh ]]; then
                    # If it's a .sh file and not executable, run it with bash.
                    bash "$script_to_run"
                    EXIT_STATUS=$?
                elif [[ "$script_to_run" == *.py ]]; then
                    # If it's a .py file and not executable, run it with python3.
                    local py_interp
                    py_interp=$(command -v python3)
                    if [ -n "$py_interp" ]; then
                        "$py_interp" "$script_to_run"
                        EXIT_STATUS=$?
                    else
                        gum style --foreground "$color1" --bold "Error: python3 interpreter not found for '$script_to_run'."
                        EXIT_STATUS=127 # Command not found
                    fi
                else
                    # Not executable and not a recognized extension (.sh or .py).
                    # Attempt to make it executable and run it if successful.
                    gum style --foreground "$color3" "Warning: Script '$script_to_run' is not executable and its type is unknown. Attempting to make it executable..."
                    chmod +x "$script_to_run"
                    if [ -x "$script_to_run" ]; then
                        "$script_to_run"
                        EXIT_STATUS=$?
                    else
                        gum style --foreground "$color1" --bold "Error: Failed to make '$script_to_run' executable or it still cannot be run."
                        EXIT_STATUS=126 # Command invoked cannot execute
                    fi
                fi

                if [ $EXIT_STATUS -ne 0 ]; then
                    gum style --foreground "$color1" --bold "Error executing '$choice' (Exit Code: $EXIT_STATUS). Please check the script or its logs."
                else
                    echo # Add a newline for better spacing
                    gum style --foreground "$color4" --bold "'$choice' completed successfully."
                fi
            else
                gum style --foreground "$color1" --bold "Error: Script file '$script_to_run' for '$choice' not found."
            fi
            read -r -p "Press Enter to continue..."
        fi
    else
        gum style --foreground "$color1" --bold "Internal error: No script found for '$choice'."
        read -r -p "Press Enter to continue..."
    fi
done