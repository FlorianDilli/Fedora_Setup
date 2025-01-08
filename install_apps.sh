#!/bin/bash

# Check if gum is installed
if ! command -v gum &> /dev/null; then
    echo "gum is not installed. Please install it first."
    exit 1
fi

# Define available applications
apps=(
    "chat.simplex.simplex:SimpleX Chat"
    "com.brave.Browser:Brave Browser"
    "com.github.jeromerobert.pdfarranger:PDF Arranger"
    "md.obsidian.Obsidian:Obsidian"
    "org.onlyoffice.desktopeditors:OnlyOffice"
)

echo "Select applications to install:"

# Create selection menu
selected=$(
    for app in "${apps[@]}"; do
        echo "${app#*:}"
    done | gum choose --no-limit
)

# Install selected applications
for choice in $selected; do
    for app in "${apps[@]}"; do
        name="${app#*:}"
        id="${app%:*}"
        if [ "$choice" = "$name" ]; then
            echo "Installing $name..."
            flatpak install flathub "$id" -y
        fi
    done
done
