#!/usr/bin/env bash
#
# Dotfiles Sync Script
# Syncs local dotfiles with upstream repository changes
#
# Usage:
#   ./scripts/sync-dotfiles.sh [options]
#
# Options:
#   --upstream <url>     Set upstream repository URL
#   --dry-run           Show what would be done without making changes
#   --force              Force sync even with conflicts
#   --backup             Create backup before syncing
#   --help               Show this help message
#
# Examples:
#   ./scripts/sync-dotfiles.sh --upstream https://github.com/user/dotfiles.git
#   ./scripts/sync-dotfiles.sh --dry-run
#   ./scripts/sync-dotfiles.sh --backup

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
readonly BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Default values
UPSTREAM_URL=""
DRY_RUN=false
FORCE=false
BACKUP=false

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Dotfiles Sync Script

Syncs local dotfiles with upstream repository changes.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --upstream <url>     Set upstream repository URL
    --dry-run           Show what would be done without making changes
    --force             Force sync even with conflicts
    --backup            Create backup before syncing
    --help              Show this help message

EXAMPLES:
    $0 --upstream https://github.com/user/dotfiles.git
    $0 --dry-run
    $0 --backup

WORKFLOW:
    1. Fetches changes from upstream
    2. Shows diff of changes
    3. Creates backup (if --backup specified)
    4. Merges upstream changes
    5. Handles conflicts (if any)
    6. Updates symlinks if needed

NOTES:
    - Run from the dotfiles directory
    - Ensure you have committed or stashed local changes
    - Backup is recommended for safety
EOF
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository. Please run from the dotfiles directory."
        exit 1
    fi
    
    # Check if we're in the dotfiles directory
    if [[ ! -f "$DOTFILES_DIR/setup.sh" ]]; then
        log_error "Not in dotfiles directory. Please run from the dotfiles root."
        exit 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_warning "You have uncommitted changes."
        if [[ "$FORCE" == false ]]; then
            log_error "Please commit or stash your changes before syncing."
            log_info "Use --force to override this check."
            exit 1
        fi
    fi
    
    log_success "Prerequisites check passed"
}

setup_upstream() {
    if [[ -n "$UPSTREAM_URL" ]]; then
        log_info "Setting up upstream remote: $UPSTREAM_URL"
        
        if git remote get-url upstream > /dev/null 2>&1; then
            log_info "Updating existing upstream remote"
            git remote set-url upstream "$UPSTREAM_URL"
        else
            log_info "Adding new upstream remote"
            git remote add upstream "$UPSTREAM_URL"
        fi
        
        log_success "Upstream remote configured"
    else
        # Check if upstream already exists
        if ! git remote get-url upstream > /dev/null 2>&1; then
            log_error "No upstream remote configured."
            log_info "Please specify upstream URL with --upstream <url>"
            log_info "Example: $0 --upstream https://github.com/user/dotfiles.git"
            exit 1
        fi
        
        log_info "Using existing upstream remote: $(git remote get-url upstream)"
    fi
}

fetch_upstream() {
    log_info "Fetching changes from upstream..."
    git fetch upstream
    
    # Get the current branch
    local current_branch
    current_branch=$(git branch --show-current)
    
    # Get upstream branch (usually master or main)
    local upstream_branch
    upstream_branch=$(git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null | sed 's@^refs/remotes/upstream/@@' || echo "master")
    
    log_info "Current branch: $current_branch"
    log_info "Upstream branch: $upstream_branch"
    
    # Check if there are new commits
    local commits_behind
    commits_behind=$(git rev-list --count HEAD..upstream/$upstream_branch 2>/dev/null || echo "0")
    
    if [[ "$commits_behind" == "0" ]]; then
        log_success "Already up to date with upstream"
        return 0
    fi
    
    log_info "Found $commits_behind new commits from upstream"
    return 1
}

show_upstream_changes() {
    local current_branch
    current_branch=$(git branch --show-current)
    
    local upstream_branch
    upstream_branch=$(git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null | sed 's@^refs/remotes/upstream/@@' || echo "master")
    
    log_info "Changes from upstream ($upstream_branch):"
    echo
    git log --oneline --graph HEAD..upstream/$upstream_branch
    echo
    
    log_info "Detailed diff:"
    git diff HEAD..upstream/$upstream_branch
}

create_backup() {
    if [[ "$BACKUP" == true ]]; then
        log_info "Creating backup in $BACKUP_DIR..."
        mkdir -p "$BACKUP_DIR"
        
        # Copy the entire dotfiles directory
        cp -r "$DOTFILES_DIR" "$BACKUP_DIR/"
        
        log_success "Backup created: $BACKUP_DIR"
        log_info "To restore: cp -r $BACKUP_DIR/dotfiles/* $DOTFILES_DIR/"
    fi
}

merge_upstream() {
    local current_branch
    current_branch=$(git branch --show-current)
    
    local upstream_branch
    upstream_branch=$(git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null | sed 's@^refs/remotes/upstream/@@' || echo "master")
    
    log_info "Merging upstream changes..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would merge upstream/$upstream_branch into $current_branch"
        return 0
    fi
    
    # Try to merge
    if git merge upstream/$upstream_branch --no-edit; then
        log_success "Successfully merged upstream changes"
    else
        log_warning "Merge conflicts detected"
        log_info "Please resolve conflicts and run: git add . && git commit"
        log_info "Or abort the merge with: git merge --abort"
        return 1
    fi
}

update_symlinks() {
    log_info "Checking if symlinks need updating..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run setup.sh to update symlinks"
        return 0
    fi
    
    # Run setup.sh to update symlinks
    log_info "Running setup.sh to update symlinks..."
    if bash "$DOTFILES_DIR/setup.sh"; then
        log_success "Symlinks updated successfully"
    else
        log_warning "Setup script had issues, but sync completed"
    fi
}

cleanup() {
    log_info "Sync completed successfully!"
    
    if [[ "$BACKUP" == true ]]; then
        log_info "Backup available at: $BACKUP_DIR"
    fi
    
    log_info "You may want to:"
    log_info "  - Test your configuration: ./scripts/validate-config.sh"
    log_info "  - Reload your shell: src (Zsh) or restart terminal"
    log_info "  - Check for any local customizations that need updating"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --upstream)
            UPSTREAM_URL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting dotfiles sync..."
    
    check_prerequisites
    setup_upstream
    
    if fetch_upstream; then
        log_success "No sync needed - already up to date"
        exit 0
    fi
    
    show_upstream_changes
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create backup, merge changes, and update symlinks"
        exit 0
    fi
    
    create_backup
    
    if merge_upstream; then
        update_symlinks
        cleanup
    else
        log_error "Sync failed due to merge conflicts"
        log_info "Please resolve conflicts and complete the merge manually"
        exit 1
    fi
}

# Run main function
main "$@"