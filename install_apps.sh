#!/bin/bash

# Check if gum is installed
if ! command -v gum &> /dev/null; then
    echo "gum is not installed. Please install it first."
    exit 1
fi

# Check if wget is installed
if ! command -v wget &> /dev/null; then
    echo "wget is not installed. Please install it first."
    exit 1
fi

# Check if rpm is installed (for installing Filen)
if ! command -v rpm &> /dev/null; then
    echo "rpm is not installed. Please install it first (likely part of a package like 'rpm-utils')."
    exit 1
fi

# Define available applications
apps=(
    "chat.simplex.simplex:SimpleX Chat"
    "com.brave.Browser:Brave Browser"
    "com.github.jeromerobert.pdfarranger:PDF Arranger"
    "md.obsidian.Obsidian:Obsidian"
    "org.onlyoffice.desktopeditors:OnlyOffice"
    "Filen:Filen Desktop" # Add Filen to the list
)

echo "Select applications to install:"

# Create selection menu and store in an array
readarray -t selected < <(
    for app in "${apps[@]}"; do
        echo "${app#*:}"
    done | gum choose --no-limit
)

# Install selected applications
for choice in "${selected[@]}"; do  # Iterate over the array elements
    for app in "${apps[@]}"; do
        name="${app#*:}"
        id="${app%:*}"
        if [ "$choice" = "$name" ]; then
            if [ "$name" = "Filen Desktop" ]; then
                echo "Installing Filen Desktop..."
                # Download Filen
                wget -O filen.rpm "https://cdn.filen.io/@filen/desktop/release/latest/Filen_linux_x86_64.rpm"
                # Install Filen (using rpm)
                sudo rpm -i filen.rpm
            else
                echo "Installing $name..."
                flatpak install flathub "$id" -y
            fi
        fi
    done
done

echo "Installation complete."
