#!/bin/bash

# Navigate to your local repository
cd ~/Fedora_Setup || exit

# Check if the Git email contains "passinbox"
current_email=$(git config --global user.email)

if [[ ! "$current_email" == *"passinbox"* ]]; then
    read -p "Your Git email does not contain 'passinbox'. Please enter your email address: " new_email
    git config --global user.email "$new_email"
    echo "Git email updated to: $new_email"
fi

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

