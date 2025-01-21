#!/bin/bash

# Navigate to your local repository
cd ~/Fedora_Setup || exit

# -----------------------------------------------
# --- Copy the Waybar theme folder ---
# -----------------------------------------------

SOURCE_FOLDER="/home/florian/.config/waybar/themes/my-modern-theme"
DESTINATION_FOLDER="/home/florian/Fedora_Setup/Config_Files/Waybar"

# Remove the existing Waybar folder if it exists
rm -rf "$DESTINATION_FOLDER"

# Create the destination directory (if it doesn't exist)
mkdir -p "$DESTINATION_FOLDER"

# Copy the Waybar theme folder recursively
cp -r "$SOURCE_FOLDER" "$DESTINATION_FOLDER"

# --- End of Waybar theme copying ---

# Add any new or modified files to the staging area
git add .

# Check if there are any changes to commit
if ! git diff-index --quiet HEAD --; then
    # Prompt for a commit message
    read -p "Enter your commit message: " commit_message

    # Commit the changes with the provided message
    git commit -m "$commit_message"
    
    # Push the changes to the remote repository
    git push origin main  # Change 'main' to 'master' if that's your default branch

    echo "Sync to GitHub complete!"
else
    echo "No changes to sync."
fi

