# Local Configuration Templates

This directory contains example configuration files for personalizing your dotfiles without modifying the main repository files.

## 📋 Overview

Local configuration files allow you to:

- Store personal information (name, email, tokens)
- Override default environment variables
- Add custom shell functions and abbreviations
- Customize laptop setup scripts
- Keep sensitive data out of version control

**All `*.local` files are gitignored and safe for personal data.**

## 🚀 Quick Start

1. Copy an example file and remove the `.example` suffix:

   ```bash
   cp local/gitconfig.local.example ~/.gitconfig.local
   ```

2. Edit the file with your personal information
3. The dotfiles will automatically load your local configuration

## 📁 Available Templates

### Git Configuration (`gitconfig.local.example`)

**Purpose:** Personal git configuration (name, email, signing, aliases)

**Location after setup:** `~/.gitconfig.local`

**Auto-loaded by:** `git/.gitconfig`

**Contains:**

- User identity (name, email)
- GPG signing configuration
- Personal git aliases
- Custom git settings

**Usage:**

```bash
cp local/gitconfig.local.example ~/.gitconfig.local
# Edit with your information
vim ~/.gitconfig.local
```

### Laptop Setup (`laptop.local.example`)

**Purpose:** Customize the laptop bootstrap script with additional packages and configurations

**Location after setup:** `~/.laptop.local`

**Auto-loaded by:** [laptop script](https://github.com/joshukraine/laptop)

**Contains:**

- Additional Homebrew packages
- Custom ASDF language versions
- Extra gems, npm packages, pip packages
- Personal setup commands

**Usage:**

```bash
cp local/laptop.local.example ~/.laptop.local
# Customize with your preferred tools
vim ~/.laptop.local
# Run laptop script
sh mac 2>&1 | tee ~/laptop.log
```

### Fish Shell Environment (`config.fish.local`)

**Purpose:** Fish-specific environment variables and functions

**Location after setup:** `~/dotfiles/local/config.fish.local`

**Auto-loaded by:** `fish/.config/fish/config.fish`

**Contains:**

- API tokens and credentials
- Custom environment variables
- Fish-specific functions
- Path modifications

**Usage:**

```bash
cp local/config.fish.example ~/dotfiles/local/config.fish.local
# Add your environment variables
vim ~/dotfiles/local/config.fish.local
```

### Shell Environment Variables (`shell-env.local.example`)

**Purpose:** Shell-agnostic environment variables for both Fish and Zsh

**Location after setup:** `~/dotfiles/local/shell-env.local`

**Auto-loaded by:** `shared/environment.sh` and `shared/environment.fish`

**Contains:**

- API keys and tokens
- Cloud provider credentials
- Database connection strings
- Custom paths
- Project-specific variables

**Usage:**

```bash
cp local/shell-env.local.example ~/dotfiles/local/shell-env.local
# Add your environment variables
vim ~/dotfiles/local/shell-env.local
```

## 🔐 Security Best Practices

### Sensitive Data

**Never commit files containing:**

- API keys, tokens, passwords
- SSH keys or GPG keys
- Personal email addresses (if private)
- Company-specific information
- Database credentials

### Using 1Password CLI (Recommended)

Instead of storing secrets in plain text, use [1Password CLI](https://developer.1password.com/docs/cli/):

```fish
# In config.fish.local
set -xg GITHUB_TOKEN (op read "op://Private/GitHub/token")
set -xg AWS_ACCESS_KEY (op read "op://Private/AWS/access_key")
```

```bash
# In shell-env.local
export GITHUB_TOKEN=$(op read "op://Private/GitHub/token")
export AWS_ACCESS_KEY=$(op read "op://Private/AWS/access_key")
```

### Encrypted Secrets

For team-shared secrets, consider:

- [git-crypt](https://github.com/AGWA/git-crypt)
- [sops](https://github.com/mozilla/sops)
- [pass](https://www.passwordstore.org/)

## 📝 Configuration Loading Order

Understanding the load order helps with troubleshooting:

### Zsh

1. `shared/environment.sh` - Shared environment variables
2. `local/shell-env.local` - Your custom environment variables
3. `zsh/.zshrc` - Main Zsh configuration
4. `~/.zshrc.local` - Optional Zsh-specific overrides

### Fish

1. `shared/environment.fish` - Shared environment variables
2. `local/shell-env.local` - Your custom environment variables (sourced)
3. `fish/.config/fish/config.fish` - Main Fish configuration
4. `local/config.fish.local` - Your custom Fish configuration

### Git

1. `git/.gitconfig` - Main git configuration
2. `~/.gitconfig.local` - Your personal git configuration

## 🔧 Customization Examples

### Custom Abbreviations

Add project-specific abbreviations to your shell config:

```fish
# In local/config.fish.local
abbr -a gpr 'cd ~/projects/my-repo'
abbr -a dcu 'docker compose up -d'
```

### Custom Functions

Add custom functions for your workflow:

```fish
# In local/config.fish.local
function work
    cd ~/projects/work
    tmux attach -t work || tmux new -s work
end
```

### Environment-Specific Settings

Set up different configurations per machine:

```bash
# In local/shell-env.local
if [ "$(hostname)" = "work-laptop" ]; then
    export WORK_MODE=true
    export DOCKER_HOST="unix:///var/run/docker.sock"
fi
```

## 🆘 Troubleshooting

### Changes Not Taking Effect

**Solution:** Reload your shell configuration

```bash
# Fish
exec fish

# Zsh
source ~/.zshrc
# or
src  # using the abbreviation
```

### Local File Not Loading

**Check:**

1. File is in the correct location
2. File has correct name (without `.example`)
3. File has proper syntax for the shell
4. No typos in variable names

**Debug:**

```fish
# Fish: Check if file is being sourced
echo "Loading local config" # Add to top of config.fish.local

# Zsh: Check if file exists and is readable
test -f ~/dotfiles/local/shell-env.local && echo "File exists"
```

### Syntax Errors

**Fish:**

```bash
fish -n local/config.fish.local  # Check syntax without executing
```

**Bash/Zsh:**

```bash
bash -n local/shell-env.local    # Check bash syntax
shellcheck local/shell-env.local # Lint the file
```

## 📚 Additional Resources

- [Dotfiles Setup Guide](../docs/setup/installation-guide.md)
- [Customization Guide](../docs/setup/customization.md)
- [Troubleshooting](../docs/setup/troubleshooting.md)
- [1Password CLI](https://developer.1password.com/docs/cli/)
- [Fish Shell Documentation](https://fishshell.com/docs/current/)
- [Zsh Documentation](https://zsh.sourceforge.io/Doc/)

## 💡 Tips

1. **Start small:** Copy one template at a time and test
2. **Document your changes:** Add comments explaining custom settings
3. **Back up regularly:** Keep backups of your local config files
4. **Use version control:** Consider a private repo for your local configs
5. **Test in isolation:** Use `fish -c` or `zsh -c` to test snippets

## 🤝 Contributing

Found an issue with a template or have a suggestion?

1. Open an issue at [github.com/joshukraine/dotfiles](https://github.com/joshukraine/dotfiles)
2. Include which template and what improvement you suggest
3. Consider submitting a pull request with your enhancement

---

*Last updated: 2025-10-23*
