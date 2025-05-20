#!/bin/bash

# Strict mode: exit on error, treat unset variables as an error, and fail pipe if any command fails.
set -euo pipefail

# --- Configuration ---
WAYBAR_THEME_SOURCE_DIR="$HOME/.config/waybar/themes/my-modern-theme"
WAYBAR_THEME_DEST_BASE_DIR="$HOME/Fedora_Setup/Config_Files/Waybar"
THEME_NAME=$(basename "$WAYBAR_THEME_SOURCE_DIR")
REPO_DIR="$HOME/Fedora_Setup"

# --- Helper Functions ---
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: Required command '$1' not found. Please install it."
        exit 1
    fi
}

# --- Main Script ---

# 0. Check for required commands
check_command "git"
check_command "ssh-add"

# 1. Copy Waybar Theme
echo "--- Copying Waybar Theme ---"
if [ ! -d "$WAYBAR_THEME_SOURCE_DIR" ]; then
    echo "Error: Source Waybar theme directory not found: $WAYBAR_THEME_SOURCE_DIR"
    exit 1
fi
mkdir -p "$WAYBAR_THEME_DEST_BASE_DIR"
if [ -d "$WAYBAR_THEME_DEST_BASE_DIR/$THEME_NAME" ]; then
    echo "Removing old theme directory: $WAYBAR_THEME_DEST_BASE_DIR/$THEME_NAME"
    rm -rf "$WAYBAR_THEME_DEST_BASE_DIR/$THEME_NAME"
fi
echo "Copying '$THEME_NAME' from $WAYBAR_THEME_SOURCE_DIR to $WAYBAR_THEME_DEST_BASE_DIR/"
cp -rp "$WAYBAR_THEME_SOURCE_DIR" "$WAYBAR_THEME_DEST_BASE_DIR/"
echo "Waybar theme copied successfully."
echo

# 2. Navigate to your local repository
echo "--- Git Operations ---"
cd "$REPO_DIR" || { echo "Error: Could not navigate to repository $REPO_DIR"; exit 1; }
echo "Navigated to $REPO_DIR"

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: $REPO_DIR is not a Git repository."
    exit 1
fi

# Check if remote 'origin' exists and is an SSH URL
echo "Checking remote 'origin' URL..."
if ! git remote get-url origin > /dev/null 2>&1; then
    echo "Error: Git remote 'origin' is not configured in $REPO_DIR."
    echo "Please add it using: git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPONAME.git"
    exit 1
fi

REMOTE_URL=$(git remote get-url origin)
echo "Remote 'origin' URL: $REMOTE_URL"

if [[ "$REMOTE_URL" == git@* ]]; then
    echo "Remote 'origin' is an SSH URL. Ensuring SSH agent is effective..."
    if ssh-add -l &>/dev/null; then
        echo "SSH agent has keys."
    else
        echo "Warning: SSH agent has no keys loaded (ssh-add -l failed or shows no identities)."
        echo "If your SSH key is passphrase protected, you might be prompted for it."
        echo "Consider running 'ssh-add ~/.ssh/your_private_key' in your terminal if issues persist."
    fi
elif [[ "$REMOTE_URL" == https://* ]]; then
    echo "Remote 'origin' is an HTTPS URL. You may be prompted for username/PAT."
else
    echo "Warning: Remote 'origin' URL type is unclear: $REMOTE_URL"
fi
echo

# 3. Check and set Git email (No changes here, assuming it's fine)
current_email=$(git config user.email || echo "")
if [[ -z "$current_email" ]]; then
    echo "Git user email is not set."
    read -p "Please enter your email address for Git: " new_email
    git config --global user.email "$new_email"
    echo "Git email updated to: $new_email"
elif [[ ! "$current_email" == *"passinbox"* ]]; then
    echo "Current Git email: $current_email"
    read -p "Your Git email does not seem to be the preferred one. Enter new email (or press Enter to keep current): " new_email
    if [[ -n "$new_email" ]]; then
        git config user.email "$new_email"
        echo "Git email updated for this repository to: $new_email"
    else
        echo "Keeping current Git email: $current_email"
    fi
fi
echo

# 4. Add, Commit, Push
echo "Adding changes to staging area..."
git add .

if ! git diff-index --quiet HEAD --; then
    echo "Changes detected."
    read -p "Enter your commit message: " commit_message

    echo "Committing changes..."
    git commit -m "$commit_message"

    current_branch_name=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch_name" == "HEAD" ]]; then
        if git show-ref --verify --quiet refs/heads/main; then default_branch="main";
        elif git show-ref --verify --quiet refs/heads/master; then default_branch="master";
        else echo "Warning: Could not reliably determine default branch, assuming 'main'."; default_branch="main"; fi
    else
        default_branch="$current_branch_name"
    fi
    echo "Attempting to push to 'origin $default_branch'..."

    # Corrected GIT_SSH_COMMAND
    # AskPass='' (empty string) tells ssh not to use an askpass program.
    # Alternatively, AskPass=/dev/null could be used.
    if GIT_SSH_COMMAND="ssh -o BatchMode=no -o AskPass=''" \
       GIT_TERMINAL_PROMPT=1 \
       git push origin "$default_branch"; then
        echo "Sync to GitHub complete!"
    else
        echo "Error: Git push failed."
        echo "This might be an authentication issue."
        echo "Suggestions:"
        echo "1. Ensure your remote 'origin' is set correctly ('git remote -v') and points to an SSH URL (git@github.com:...). If not, fix it."
        echo "2. If using SSH:"
        echo "   - Test connection: 'ssh -T git@github.com'. It should succeed."
        echo "   - Ensure your SSH key is added to ssh-agent: 'ssh-add -l' (should list your key)."
        echo "   - If prompted for a passphrase, enter it correctly."
        echo "   - (Recommended) Check SSH key setup on GitHub: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
        echo "3. If you were trying to use HTTPS (URL like https://github.com/...):"
        echo "   - The GIT_SSH_COMMAND line is for SSH. For HTTPS, ensure you have a credential helper configured or enter credentials when prompted."
        exit 1
    fi
else
    echo "No changes to sync."
fi

echo
echo "Script finished."
