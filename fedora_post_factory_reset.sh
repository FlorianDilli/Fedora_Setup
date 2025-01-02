#!/bin/bash

# Run this script after a fresh install of fedora with hyprland to install all apps and make the flatpak version of obsidian open under hyprland

# Install Flatpak applications
flatpak install flathub \
    chat.simplex.simplex \
    com.brave.Browser \
    com.github.jeromerobert.pdfarranger \
    md.obsidian.Obsidian \
    org.onlyoffice.desktopeditors -y

# Enable Wayland override for Obsidian
flatpak override --user --socket=wayland md.obsidian.Obsidian

# Install required packages for xdg-desktop-portal
sudo dnf install -y xdg-desktop-portal-gtk xdg-desktop-portal-hyprland

# Restart the xdg-desktop-portal service
systemctl --user restart xdg-desktop-portal

# Completion message
echo "Flatpak applications installed, Wayland override applied, required packages installed, and xdg-desktop-portal restarted."

