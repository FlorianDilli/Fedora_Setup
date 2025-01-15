#!/bin/bash

# Script for automating ML4W scaling adjustments and Rofi theme configuration

# ------------------------------------------------------------------
# --- Step 1: Adjust ML4W Scaling ---
# ------------------------------------------------------------------
CUSTOM_CONF="$HOME/.config/hypr/conf/custom.conf"
SCALING_LINE="monitor=,preferred,auto,1.666667"

# Ensure the configuration directory exists
mkdir -p "$(dirname "$CUSTOM_CONF")"

# Append scaling configuration if not already present
if ! grep -q "^${SCALING_LINE}$" "$CUSTOM_CONF"; then
    # Check if the file is not empty
    if [ -s "$CUSTOM_CONF" ]; then
        echo "" >> "$CUSTOM_CONF"  # Add a new line before appending
    fi
    echo "$SCALING_LINE" >> "$CUSTOM_CONF"
fi

# ------------------------------------------------------------------
# --- Step 2: Set my Rofi Theme ---
# ------------------------------------------------------------------
ROFI_THEME_DIR="$HOME/Fedora_Setup/Config_Files/Rofi"
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"

# Create or overwrite the Rofi configuration file
cat > "$ROFI_CONFIG" <<EOL
@theme "$ROFI_THEME_DIR/my_rofi_theme.rasi"
configuration {
    show-icons: true;
    display-drun: "";
}
EOL


# ------------------------------------------------------------------
# --- Step 3: Insert my own Waybar Theme ---
# ------------------------------------------------------------------

# create symbolic link from my folder to the waybar themes folder 
ln -s ~/Fedora_Setup/Config_Files/Waybar/my_starter ~/.config/waybar/themes/my_starter
