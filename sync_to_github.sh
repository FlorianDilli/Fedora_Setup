#!/bin/bash

# Strict mode: exit on error, treat unset variables as an error, and fail pipe if any command fails.
set -euo pipefail

# --- Configuration ---
# Source directory for your Waybar theme
WAYBAR_THEME_SOURCE_DIR="$HOME/.config/waybar/themes/my-modern-theme"
# Destination base directory for Waybar themes in your setup
WAYBAR_THEME_DEST_BASE_DIR="$HOME/Fedora_Setup/Config_Files/Waybar"
# Name of the theme directory (derived from source)
THEME_NAME=$(basename "$WAYBAR_THEME_SOURCE_DIR")
# Path to your local Git repository
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
check_command "ssh-add" # Good to have for SSH agent interaction

# 1. Copy Waybar Theme
echo "--- Copying Waybar Theme ---"
if [ ! -d "$WAYBAR_THEME_SOURCE_DIR" ]; then
    echo "Error: Source Waybar theme directory not found: $WAYBAR_THEME_SOURCE_DIR"
    exit 1
fi

# Ensure the destination base directory exists
mkdir -p "$WAYBAR_THEME_DEST_BASE_DIR"

# Remove the old theme directory in the destination if it exists
if [ -d "$WAYBAR_THEME_DEST_BASE_DIR/$THEME_NAME" ]; then
    echo "Removing old theme directory: $WAYBAR_THEME_DEST_BASE_DIR/$THEME_NAME"
    rm -rf "$WAYBAR_THEME_DEST_BASE_DIR/$THEME_NAME"
fi

# Copy the new theme
echo "Copying '$THEME_NAME' from $WAYBAR_THEME_SOURCE_DIR to $WAYBAR_THEME_DEST_BASE_DIR/"
cp -rp "$WAYBAR_THEME_SOURCE_DIR" "$WAYBAR_THEME_DEST_BASE_DIR/"
echo "Waybar theme copied successfully."
echo

# 2. Navigate to your local repository
echo "--- Git Operations ---"
cd "$REPO_DIR" || { echo "Error: Could not navigate to repository $REPO_DIR"; exit 1; }
echo "Navigated to $REPO_DIR"

# Check if it's a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: $REPO_DIR is not a Git repository."
    exit 1
fi

# Verify remote 'origin' URL (optional but good for debugging)
echo "Checking remote 'origin' URL..."
if git remote -v | grep -q '^origin.*github.com'; then
    if git remote -v | grep '^origin' | grep -q 'git@github.com'; then
        echo "Remote 'origin' is an SSH URL. Ensuring SSH agent is effective..."
        # Check if SSH agent has keys. If not, prompt user.
        if ssh-add -l &>/dev/null; then
            echo "SSH agent has keys."
        else
            echo "Warning: SSH agent has no keys loaded (ssh-add -l failed or shows no identities)."
            echo "If your SSH key is passphrase protected, you might be prompted for it."
            echo "Consider running 'ssh-add ~/.ssh/your_private_key' in your terminal."
        fi
    elif git remote -v | grep '^origin' | grep -q 'https://github.com'; then
        echo "Remote 'origin' is an HTTPS URL. You may be prompted for username/PAT."
    else
        echo "Remote 'origin' is a GitHub URL, but type (SSH/HTTPS) is unclear from simple check."
    fi
else
    echo "Warning: Remote 'origin' does not seem to be a standard GitHub URL or is not set."
fi
echo

# 3. Check and set Git email
current_email=$(git config user.email || echo "") # Get local or global, default to empty
if [[ -z "$current_email" ]]; then
    echo "Git user email is not set."
    read -p "Please enter your email address for Git: " new_email
    git config --global user.email "$new_email" # Set globally if not set at all
    echo "Git email updated to: $new_email"
elif [[ ! "$current_email" == *"passinbox"* ]]; then # Example condition, adjust as needed
    echo "Current Git email: $current_email"
    read -p "Your Git email does not seem to be the preferred one. Enter new email (or press Enter to keep current): " new_email
    if [[ -n "$new_email" ]]; then
        git config user.email "$new_email" # Set for current repo. Use --global for global.
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

    # Commit the changes
    echo "Committing changes..."
    git commit -m "$commit_message"

    current_branch_name=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch_name" == "HEAD" ]]; then
        if git show-ref --verify --quiet refs/heads/main; then
            default_branch="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            default_branch="master"
        else
            echo "Warning: Could not reliably determine default branch, assuming 'main'."
            default_branch="main"
        fi
    else
        default_branch="$current_branch_name"
    fi
    echo "Attempting to push to 'origin $default_branch'..."

    # Key change here: Use GIT_SSH_COMMAND to force ssh to prompt on tty if needed
    # GIT_TERMINAL_PROMPT=1 is for git's own prompts (e.g. HTTP auth)
    # unset SSH_ASKPASS GIT_ASKPASS prevents external GUI helpers for ssh/git
    # ssh -o AskPass= explicitly tells ssh not to use any AskPass program, forcing TTY prompt for passphrases
    # ssh -o BatchMode=no ensures ssh *can* prompt (default is no for non-interactive)
    if GIT_SSH_COMMAND="ssh -o BatchMode=no -o AskPass=" \
       GIT_TERMINAL_PROMPT=1 \
       git push origin "$default_branch"; then # Note: unset SSH_ASKPASS/GIT_ASKPASS is implicitly handled by GIT_SSH_COMMAND overriding ssh call
        echo "Sync to GitHub complete!"
    else
        echo "Error: Git push failed."
        echo "This might be an authentication issue."
        echo "Suggestions:"
        echo "1. Ensure your remote 'origin' is set correctly ('git remote -v')."
        echo "2. If using SSH (URL like git@github.com:...):"
        echo "   - Ensure your SSH key is added to your ssh-agent ('ssh-add -l' to list)."
        echo "   - If prompted for a passphrase, enter it."
        echo "   - Test with 'ssh -T git@github.com'."
        echo "   - (Recommended) Check SSH key setup on GitHub: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
        echo "3. If using HTTPS (URL like https://github.com/...):"
        echo "   - Ensure you entered your username/Personal Access Token correctly when prompted."
        echo "   - Consider setting up a Git credential helper: "
        echo "     'git config --global credential.helper cache' (caches for 15 mins)"
        echo "     'git config --global credential.helper store' (stores unencrypted - less secure)"
        echo "     Or use a system-specific helper like 'libsecret' on Linux."
        exit 1 # Exit with error if push fails
    fi
else
    echo "No changes to sync."
fi

echo
echo "Script finished."
