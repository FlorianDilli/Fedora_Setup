#!/bin/bash

# Script for automating ML4W scaling adjustments and Rofi theme configuration




# ------------------------------------------------------------------
# --- Step 1: place my custom.conf file ---
# ------------------------------------------------------------------
# remove custom.conf file
rm /home/florian/.config/hypr/conf/custom.conf

# replace it with a symlink to my own custom.conf
ln -s /home/florian/Fedora_Setup/Config_Files/Hyprland/custom.conf /home/florian/.config/hypr/conf/custom.conf



# ------------------------------------------------------------------
# --- Step 2: Set my Rofi Theme ---
# ------------------------------------------------------------------
# remove config.rasi file
rm /home/florian/.config/rofi/config.rasi

# replace it with a symlink to my own config.rasi
ln -s /home/florian/Fedora_Setup/Config_Files/Rofi/config.rasi /home/florian/.config/rofi/config.rasi



# ------------------------------------------------------------------
# --- Step 3: Insert my own Waybar Theme ---
# ------------------------------------------------------------------

# remove folder first
rm -rf /home/florian/.config/waybar/themes/my-modern-theme

# copy my theme from my folder to the waybar themes folder 
cp -r /home/florian/Fedora_Setup/Config_Files/Waybar/my-modern-theme /home/florian/.config/waybar/themes/


# ------------------------------------------------------------------
# --- Step 4: Insert my own Wallust Config ---
# ------------------------------------------------------------------

# remove folder first
rm -rf /home/florian/.config/wallust

# copy my theme from my folder to the waybar themes folder 
cp -r /home/florian/Fedora_Setup/Config_Files/wallust /home/florian/.config/

