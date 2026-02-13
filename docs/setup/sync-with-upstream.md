# Syncing Dotfiles with Upstream

This guide explains how to sync your personal dotfiles with upstream changes from a template or base repository.

## Overview

The `sync-dotfiles.sh` script provides a safe way to merge upstream changes into your personal dotfiles repository while preserving your customizations.

## Quick Start

### 1. Set Up Upstream Remote

First, add the upstream repository as a remote:

```bash
# Navigate to your dotfiles
cdot

# Add upstream remote (replace with your template repository)
git remote add upstream https://github.com/template-user/dotfiles.git

# Or use the sync script to set it up
./scripts/sync-dotfiles.sh --upstream https://github.com/template-user/dotfiles.git
```

### 2. Sync with Upstream

```bash
# Preview changes without applying them
dfsyncd

# Sync with backup (recommended)
dfsyncb

# Or sync directly
dfsync
```

## Available Commands

| Command | Description |
|---------|-------------|
| `dfsync` | Sync dotfiles with upstream repository |
| `dfsyncb` | Sync with upstream and create backup |
| `dfsyncd` | Preview sync changes without applying |

## Script Options

The sync script supports several options:

```bash
./scripts/sync-dotfiles.sh [OPTIONS]

Options:
  --upstream <url>     Set upstream repository URL
  --dry-run           Show what would be done without making changes
  --force             Force sync even with conflicts
  --backup            Create backup before syncing
  --help              Show help message
```

## Workflow

The sync process follows these steps:

1. **Prerequisites Check**: Verifies you're in a git repository and checks for uncommitted changes
2. **Upstream Setup**: Configures or updates the upstream remote
3. **Fetch Changes**: Downloads latest changes from upstream
4. **Show Changes**: Displays what changes will be applied
5. **Create Backup**: (Optional) Creates a timestamped backup
6. **Merge Changes**: Attempts to merge upstream changes
7. **Handle Conflicts**: Guides you through conflict resolution if needed
8. **Update Symlinks**: Runs setup.sh to update symlinks

## Safety Features

### Automatic Backup

When using `--backup` or `dfsyncb`, the script creates a timestamped backup:

```bash
# Backup location
~/.dotfiles-backup-20240101-120000/

# To restore from backup
cp -r ~/.dotfiles-backup-20240101-120000/dotfiles/* ~/dotfiles/
```

### Conflict Detection

The script detects potential issues:

- Uncommitted changes (use `--force` to override)
- Merge conflicts (manual resolution required)
- Missing upstream remote (helpful error messages)

### Dry Run Mode

Preview changes before applying:

```bash
./scripts/sync-dotfiles.sh --dry-run
```

## Handling Conflicts

If merge conflicts occur:

1. **Resolve conflicts** in your editor
2. **Stage resolved files**: `git add .`
3. **Complete merge**: `git commit`
4. **Or abort**: `git merge --abort`

## Best Practices

### Before Syncing

1. **Commit your changes**: `git add . && git commit -m "Save my customizations"`
2. **Create a backup**: Use `--backup` flag
3. **Test in a branch**: Create a test branch first

### After Syncing

1. **Test your configuration**: `./scripts/validate-config.sh`
2. **Reload your shell**: `src` (Zsh) or restart terminal
3. **Check customizations**: Verify your `.local` files still work
4. **Update if needed**: Modify any customizations that conflict

## Example Workflow

```bash
# 1. Navigate to dotfiles
cdot

# 2. Commit any local changes
git add .
git commit -m "Save my customizations"

# 3. Preview upstream changes
dfsyncd

# 4. Sync with backup
dfsyncb

# 5. Test configuration
./scripts/validate-config.sh

# 6. Reload shell
src
```

## Troubleshooting

### "No upstream remote configured"

```bash
# Add upstream remote
./scripts/sync-dotfiles.sh --upstream https://github.com/user/dotfiles.git
```

### "You have uncommitted changes"

```bash
# Commit your changes first
git add .
git commit -m "Save changes"

# Or force sync (not recommended)
./scripts/sync-dotfiles.sh --force
```

### Merge conflicts

```bash
# Resolve conflicts manually
git status
# Edit conflicted files
git add .
git commit

# Or abort the merge
git merge --abort
```

### Symlink issues

```bash
# Re-run setup to fix symlinks
./setup.sh
```

## Integration with Local Customizations

The sync script works well with the `.local` file pattern:

- **Personal configs**: `~/.gitconfig.local`, `~/.zshrc.local`
- **Safe from updates**: Won't be overwritten during sync
- **Automatic loading**: Loaded by main configuration files

## Advanced Usage

### Custom Upstream Branch

```bash
# Sync from a specific branch
git fetch upstream feature-branch
git merge upstream/feature-branch
```

### Selective Syncing

```bash
# Sync specific files only
git checkout upstream/master -- path/to/file
```

### Multiple Upstreams

```bash
# Add multiple upstreams
git remote add upstream1 https://github.com/user1/dotfiles.git
git remote add upstream2 https://github.com/user2/dotfiles.git
```

## Security Considerations

- **Verify upstream URLs**: Ensure you trust the upstream repository
- **Review changes**: Always review what changes will be applied
- **Backup regularly**: Create backups before major syncs
- **Test changes**: Validate configuration after syncing

## Contributing Back

If you make improvements to the dotfiles:

1. **Fork the upstream repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Submit a pull request**

This helps improve the template for everyone!