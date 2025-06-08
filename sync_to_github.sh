#!/bin/bash

# Strict mode: exit on error, treat unset variables as an error, and fail pipe if any command fails.
# We temporarily disable 'e' during the git push to handle failures gracefully.
set -uo pipefail

# --- Configuration ---
# Add the full paths to your local Git repositories here.
REPOS_TO_SYNC=(
    "$HOME/Fedora_Setup"
    "$HOME/Speed-Reader"
    # "$HOME/my-other-project"
)

# --- Helper Functions for Rich Output ---
# FIX: Explicitly use the '-' argument to tell rich to read from stdin.
# This is the most reliable way to pipe text to the rich-cli tool.

print_header() {
    # This function was already correct.
    echo "-- $1 --" | rich --panel rounded --style "bold bright_cyan" --padding 1 -
}

print_repo_header() {
    # Corrected: Pipe the formatted string to `rich` and use '-'
    echo "[bold white on blue] Repository: $1 [/]" | rich -
}

print_success() {
    # Corrected: Pipe the formatted string to `rich` and use '-'
    echo "[bold green]✔[/] $1" | rich -
}

print_error() {
    # Corrected: Pipe the formatted string to `rich` and use '-'
    echo "[bold red]✖[/] $1" | rich -
}

print_warning() {
    # Corrected: Pipe the formatted string to `rich` and use '-'
    echo "[bold yellow]![/] $1" | rich -
}

print_info() {
    # Corrected: Pipe the formatted string to `rich` and use '-'
    echo "[dim]❯[/] [cyan]$1[/]" | rich -
}

print_separator() {
    # FIX: The style argument needs its own flag (--style).
    rich --rule --style "dim"
}
# --- End of Helper Functions ---


# --- Main Script ---
# 1. Check for required dependencies
if ! command -v git &> /dev/null; then
    print_error "Required command 'git' not found. Please install it."
    exit 1
fi
if ! command -v rich &> /dev/null; then
    print_error "Required command 'rich' not found. Please install it (e.g., 'pip install rich-cli')."
    exit 1
fi

print_header "Multi-Repo Git Sync"
echo

synced_count=0
repos_with_changes=0

# 2. Loop through each repository defined in the configuration
for repo_dir in "${REPOS_TO_SYNC[@]}"; do
    repo_name=$(basename "$repo_dir")
    print_repo_header "$repo_name"

    if [ ! -d "$repo_dir" ]; then
        print_warning "Directory not found: $repo_dir. Skipping."
        print_separator
        continue
    fi

    # FIX: Use pushd/popd to manage directories instead of a subshell.
    # This ensures that our counters ($synced_count, etc.) are modified
    # in the main script's scope and are not lost.
    pushd "$repo_dir" > /dev/null || { print_warning "Could not navigate to $repo_dir. Skipping."; print_separator; continue; }

    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        print_warning "$repo_name is not a Git repository. Skipping."
    else
        print_info "Checking for local changes..."

        if [ -n "$(git status --porcelain)" ]; then
            ((repos_with_changes++))
            print_warning "Changes detected in $repo_name."
            
            echo
            echo "[bold]Staged & Unstaged Changes:[/]" | rich -
            # This pipe is correct: it sends the output of `git status` to rich's stdin.
            git status --short | rich -
            echo

            print_info "Staging all changes..."
            git add .

            commit_message=$(gum input --header "Enter commit message for '$repo_name'" --placeholder "Your changes...")

            if [ -z "$commit_message" ]; then
                print_warning "Empty commit message. Resetting staged files and skipping repo."
                git reset > /dev/null
            else
                print_info "Committing with message: '$commit_message'..."
                git commit -m "$commit_message" > /dev/null

                current_branch=$(git rev-parse --abbrev-ref HEAD)
                print_info "Attempting to push changes to 'origin/$current_branch'..."
                
                # --- ROBUST PUSH LOGIC ---
                set +e
                push_output=$(git push origin "$current_branch" 2>&1)
                push_exit_code=$?
                set -e

                if [ $push_exit_code -eq 0 ]; then
                    print_success "Successfully synced '$repo_name' to GitHub."
                    ((synced_count++))
                else
                    print_error "Git push failed for '$repo_name'."
                    echo
                    echo "$push_output" | rich --panel rounded --border-style "red" --title "Git Push Error Output" -
                    print_warning "Please check the output above for errors (e.g., authentication)."
                fi
                # --- END OF PUSH LOGIC ---
            fi
        else
            print_success "No local changes to sync."
        fi
    fi
    
    # Return to the original directory
    popd > /dev/null
    print_separator
done

# --- Final Summary ---
print_header "Sync Complete"
print_info "Processed ${#REPOS_TO_SYNC[@]} configured repositories."

if [ "$repos_with_changes" -eq 0 ]; then
    print_success "All repositories were already up-to-date."
else
    print_success "Successfully synced $synced_count of $repos_with_changes repositories that had changes."
fi

echo