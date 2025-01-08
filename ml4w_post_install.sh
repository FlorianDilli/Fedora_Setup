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
    echo "$SCALING_LINE" >> "$CUSTOM_CONF"
fi

# ------------------------------------------------------------------
# --- Step 2: Install and Configure Rofi Themes ---
# ------------------------------------------------------------------
ROFI_THEME_DIR="$HOME/florian/Fedora_Setup/Config_Files/Rofi"
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
# --- Step 3: Dynamic Color Updates for Rofi ---
# ------------------------------------------------------------------
AUTOSTART_CONF="$HOME/.config/hypr/conf/autostart.conf"
UPDATE_SCRIPT="$HOME/Fedora_Setup/update_rofi_color.sh"

# Install inotify-tools for monitoring file changes
sudo dnf install -y inotify-tools

# Ensure the autostart configuration directory exists
mkdir -p "$(dirname "$AUTOSTART_CONF")"

# Append dynamic color update script to the autostart configuration
if ! grep -q "$UPDATE_SCRIPT" "$AUTOSTART_CONF"; then
    echo "exec-once = while true; do \
  [ -f \"$HOME/.cache/wal/colors\" ] && \
  inotifywait -e modify \"$HOME/.cache/wal/colors\" && \
  $UPDATE_SCRIPT; \
done" >> "$AUTOSTART_CONF"
fi

