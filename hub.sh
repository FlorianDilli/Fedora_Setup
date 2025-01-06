#!/bin/bash
clear

# Check if Gum is installed
if ! command -v gum &> /dev/null; then
    echo "Gum is not installed. Installing Gum..."
    sudo dnf install -y gum || {
        echo "Failed to install Gum. Please install it manually."
        exit 1
    }
fi

# Menu options (titles only)
OPTIONS=(
    "Backup Files and Scripts"
    "Install Applications"
    "Post-Install Configuration (Hyprland & Rofi)"
    "Post-Update Rofi Customization"
    "Update Rofi Colors"
    "Update System"
    "Sync to GitHub"
    "Exit"
)

# Corresponding commands for the options
COMMANDS=(
    "./backup.sh"
    "./install_apps.sh"
    "./ml4w_post_install.sh"
    "./ml4w_post_update.sh"
    "./update_rofi_color.sh"
    "./update_system.sh"
    "./sync_to_github.sh"
    "exit 0"
)

# Beautiful header with ASCII art
HEADER=$(gum style \
    --foreground 212 --background 0 --bold \
    --margin "1" --padding "1 1" \
    --align left \
    "$(cat << 'EOF'
 _____                _____     _           
|  |  |_ _ ___ ___   |   __|___| |_ _ _ ___ 
|     | | | . |  _|  |__   | -_|  _| | | . |
|__|__|_  |  _|_|    |_____|___|_| |___|  _|
      |___|_|                          |_|  
EOF
)")

echo "$HEADER"

# Show menu and capture the choice
CHOICE=$(printf "%s\n" "${OPTIONS[@]}" | gum choose --header="Select an option to execute:")

# Find the corresponding command for the selected option
for i in "${!OPTIONS[@]}"; do
    if [[ "${OPTIONS[$i]}" == "$CHOICE" ]]; then
        COMMAND="${COMMANDS[$i]}"
        break
    fi
done

# Confirm action
gum confirm "Do you want to run '$CHOICE'?" || exit

# Run the selected script interactively
if [[ "$COMMAND" != "exit 0" ]]; then
    echo "Running '$CHOICE'..."
    bash -c "$COMMAND"
    EXIT_STATUS=$?
    if [ $EXIT_STATUS -ne 0 ]; then
        echo "Error executing '$CHOICE'. Please check the script."
        exit 1
    fi
fi

# Completion message
echo
gum style --foreground 212 --bold "'$CHOICE' completed successfully."
