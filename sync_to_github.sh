#!/bin/bash

# Navigate to your local repository
cd ~/Fedora_Setup || exit

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

