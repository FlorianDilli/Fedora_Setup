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
check_command "ssh-add" # Keep this check as ssh-agent is relevant

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
    # Check if ssh-agent has keys.
    # ssh-add -l returns 0 if agent has keys, 1 if no keys, 2 if agent not available.
    if ssh-add -l >/dev/null 2>&1; then
        echo "SSH agent has keys."
    else
        # Capture the exit code of ssh-add -l to provide a more specific message
        ssh_add_status=0
        ssh-add -l >/dev/null 2>&1 || ssh_add_status=$? # Check status without printing error

        if [ "$ssh_add_status" -eq 1 ]; then # Agent running, but no identities
            echo "Warning: SSH agent is running but has no keys loaded."
            echo "If your SSH key is passphrase protected, you might be prompted for it during the push."
            echo "Consider running 'ssh-add ~/.ssh/your_private_key' in your terminal if issues persist."
        elif [ "$ssh_add_status" -eq 2 ]; then # Agent not running or not available
            echo "Warning: SSH agent does not seem to be running or is not available."
            echo "If your SSH key is passphrase protected, you will likely be prompted for it."
            echo "For a smoother experience, ensure ssh-agent is running and your key is added."
        else # Other error (should not happen if ssh-add command exists)
            echo "Warning: Could not determine SSH agent status (ssh-add -l exited with $ssh_add_status)."
        fi
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
elif [[ ! "$current_email" == *"passinbox"* ]]; then # Example check, adjust as needed
    echo "Current Git email: $current_email"
    read -p "Your Git email does not seem to be the preferred one. Enter new email (or press Enter to keep current): " new_email
    if [[ -n "$new_email" ]]; then
        git config user.email "$new_email" # Use local config for this repo unless --global is intended
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
    if [[ "$current_branch_name" == "HEAD" ]]; then # In detached HEAD state
        # Try to find a common default branch name
        if git show-ref --verify --quiet refs/heads/main; then default_branch="main";
        elif git show-ref --verify --quiet refs/heads/master; then default_branch="master";
        else
            echo "Warning: Could not reliably determine default branch from detached HEAD, assuming 'main'."
            echo "You might want to create and checkout a branch first: git checkout -b new-branch-name"
            default_branch="main";
        fi
    else
        default_branch="$current_branch_name"
    fi
    echo "Attempting to push to 'origin $default_branch'..."

    # --- MODIFIED SECTION ---
    # GIT_TERMINAL_PROMPT=1 allows Git to prompt on the terminal.
    # BatchMode=no in GIT_SSH_COMMAND ensures ssh itself can prompt if needed
    # and isn't running in a non-interactive batch mode that would suppress prompts.
    if GIT_SSH_COMMAND="ssh -o BatchMode=no" \
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
        echo "     If not, run 'ssh-add /path/to/your/private_key' (e.g., ~/.ssh/id_ed25519)."
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
