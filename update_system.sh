#!/usr/bin/bash

# Define color for output
set PURPLE '\033[1;35m'
set NC '\033[0m' # No Color

# Update and upgrade DNF packages
echo -e "$PURPLE Updating DNF packages... $NC"
sudo dnf update -y

# Remove unused packages
echo -e "$PURPLE Removing unused packages... $NC"
sudo dnf autoremove -y

# Clean up DNF cache
echo -e "$PURPLE Cleaning up DNF cache... $NC"
sudo dnf clean all

# Update Flatpak packages
echo -e "$PURPLE Updating Flatpak packages... $NC"
flatpak update -y

# Check for broken packages (Fedora uses rpm for package validation)
echo -e "$PURPLE Checking for broken packages... $NC"
sudo rpm --rebuilddb
sudo dnf check

echo -e "$PURPLE System update completed! $NC"
