#!/bin/bash

# Get the current color scheme
current_scheme=$(gsettings get org.gnome.desktop.interface color-scheme)

# Check the current scheme and toggle
if [ "$current_scheme" == "'prefer-light'" ]; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    echo "Switched to Dark Mode"
else
    gsettings set org.gnome.desktop.interface color-scheme prefer-light
    echo "Switched to Light Mode"
fi
