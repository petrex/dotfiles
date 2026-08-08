# Setup Script Documentation

Welcome to the comprehensive setup script documentation for the dotfiles repository. This collection of guides will help you successfully install, configure, and maintain your development environment using our automated setup script.

## 📋 Quick Reference

| Scenario | Guide | Description |
| --- | --- | --- |
| **New Installation** | [Installation Guide](installation-guide.md) | Complete walkthrough for a fresh machine |
| **Safety Boundaries** | [Safety Boundaries](security-boundaries.md) | Link, user, and privileged system phases |
| **Command Examples** | [Usage Examples](usage-examples.md) | All setup script options with practical examples |
| **Issues & Fixes** | [Troubleshooting](troubleshooting.md) | Common problems and their solutions |
| **Personal Setup** | [Customization](customization.md) | Local configuration and personal overrides |
| **From Other Dotfiles** | [Migration Guide](migration.md) | Moving from other dotfiles repositories |

## 🚀 Quick Start

For first-time users who want to get started immediately:

1. **Prerequisites**: Install Git and [GNU Stow](https://www.gnu.org/software/stow/)
2. **Clone**: `git clone https://github.com/petrex/dotfiles.git ~/dotfiles`
3. **Preview**: `~/dotfiles/setup.sh --dry-run` (see what will happen)
4. **Link**: `~/dotfiles/setup.sh` (no sudo or network access)
5. **Optional user setup**: `~/dotfiles/scripts/setup-user.sh`
6. **Optional system setup**: Preview with `~/dotfiles/scripts/setup-system.sh --dry-run`, then apply without `--dry-run`

For detailed instructions, see the [Installation Guide](installation-guide.md).

## 🛠️ Setup Script Features

The setup is split by trust level. `setup.sh` provides a focused, idempotent linking experience:

- **Safe to run multiple times** - Script detects existing configurations
- **Dry-run capability** - Preview changes before applying them
- **Automatic conflict resolution** - Backs up existing files with timestamps
- **Comprehensive error handling** - Clear error messages and recovery guidance
- **Prerequisite checking** - Validates required tools before proceeding
- **No privilege escalation** - Never invokes sudo or modifies system settings
- **No network access** - Only manages local directories, backups, and symlinks

User-owned state and machine-wide settings are handled by separate scripts. See
the [Safety Boundaries](security-boundaries.md) guide.

## 📖 Documentation Structure

### Core Guides

- **[Installation Guide](installation-guide.md)** - Complete step-by-step installation walkthrough
  - Fresh macOS setup procedures
  - Pre-installation checklist
  - Post-installation verification
  - Common first-time user scenarios

- **[Usage Examples](usage-examples.md)** - Practical command examples and scenarios
  - Basic installation examples
  - Advanced configuration options
  - Update and maintenance procedures
  - Recovery from failed installations

### Specialized Guides

- **[Troubleshooting](troubleshooting.md)** - Solutions for common issues
  - Permission and Stow problems
  - Stow conflicts and symlink issues
  - Homebrew installation problems
  - Shell configuration conflicts

- **[Customization](customization.md)** - Personalizing your setup
  - Local configuration patterns
  - Environment variable overrides
  - Selective package installation
  - Personal data integration

- **[Migration Guide](migration.md)** - Moving from other dotfiles
  - Backup strategies for existing configurations
  - Conflict resolution approaches
  - Safe testing and rollback procedures
  - Integration with existing tools

## 🎯 Choose Your Path

### I'm new to dotfiles

→ Start with the [Installation Guide](installation-guide.md) for a complete walkthrough

### I want to see examples first

→ Check out [Usage Examples](usage-examples.md) to understand the setup script options

### I'm having problems

→ Go to [Troubleshooting](troubleshooting.md) for solutions to common issues

### I have existing dotfiles

→ See the [Migration Guide](migration.md) for safe transition strategies

### I want to customize everything

→ Read the [Customization Guide](customization.md) for personalization options

## 🔗 Related Documentation

- **[Main README](../../README.md)** - Repository overview and highlights
- **[Function Documentation](../functions/README.md)** - Shell function reference
- **[Abbreviations Reference](../abbreviations.md)** - Complete command shortcuts guide
- **[CLAUDE.md](../../CLAUDE.md)** - AI assistant guidance for development

## 💡 Getting Help

If you encounter issues not covered in these guides:

1. **Check existing documentation** - Search through all setup guides
2. **Review the script** - Read `setup.sh` directly for implementation details
3. **Test with dry-run** - Use `--dry-run` to understand what will happen
4. **File an issue** - Report problems on the [GitHub repository](https://github.com/petrex/dotfiles/issues)

## ⚡ TL;DR Commands

```bash
# Quick installation for experienced users
git clone https://github.com/petrex/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh --dry-run  # Preview first!
~/dotfiles/setup.sh            # Create links
~/dotfiles/scripts/setup-user.sh

# Common maintenance commands
~/dotfiles/setup.sh --dry-run  # Check what would change
~/dotfiles/setup.sh            # Update configuration (idempotent)
```

Happy coding! 🚀
