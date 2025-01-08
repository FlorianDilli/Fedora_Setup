#!/bin/bash

# Configuration script for Rofi

# ------------------------------------------------------------------
# --- Step 2: Set my Rofi Theme in the Rofi Config ---
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
