#!/bin/bash

# Configuration script for Rofi and autostart color changes

------------------------------------------------------------------
# --- Variables ---
------------------------------------------------------------------
ROFI_THEME_DIR="$HOME/.local/share/rofi/themes"
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"
AUTOSTART_CONF="$HOME/.config/hypr/conf/autostart.conf"
UPDATE_SCRIPT="$HOME/Fedora_Setup/update_rofi_color.sh"

------------------------------------------------------------------
# --- Step 1: Create or Update Rofi Configuration File ---
------------------------------------------------------------------
# Ensure the theme directory exists
mkdir -p "$ROFI_THEME_DIR"

# Create or overwrite the Rofi configuration file
cat > "$ROFI_CONFIG" <<EOL
@theme "$ROFI_THEME_DIR/rounded-nord-dark.rasi"
configuration {
    show-icons: true;
    display-drun: "";
}
EOL

------------------------------------------------------------------
# --- Step 2: Add Color Change Command to Autostart Configuration ---
------------------------------------------------------------------
# Ensure the autostart configuration directory exists
mkdir -p "$(dirname "$AUTOSTART_CONF")"

# Append the color change command to the autostart configuration
if ! grep -q "$UPDATE_SCRIPT" "$AUTOSTART_CONF"; then
    echo "exec-once = while true; do \
  [ -f \"$HOME/.cache/wal/sequences\" ] && \
  inotifywait -e modify \"$HOME/.cache/wal/sequences\" && \
  $UPDATE_SCRIPT; \
done" >> "$AUTOSTART_CONF"
fi

