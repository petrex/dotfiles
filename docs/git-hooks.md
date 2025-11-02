# Git Hooks Guide

Automated validation and quality checks for the dotfiles repository using [pre-commit framework](https://pre-commit.com/).

## 📋 Overview

Git hooks automatically run checks before commits and pushes to:

- Validate shell syntax (Fish, Zsh, Bash)
- Lint scripts with shellcheck
- Format code consistently
- Check for secrets and large files
- Validate YAML, JSON, and Markdown
- Run test suite
- Ensure configuration integrity

## 🚀 Quick Start

### Installation

```bash
# Install pre-commit framework
brew install pre-commit
# or
pip install pre-commit

# Setup git hooks
./scripts/setup-git-hooks.sh

# Verify installation
./scripts/setup-git-hooks.sh --check
```

### Basic Usage

```bash
# Hooks run automatically on git commit
git commit -m "Your commit message"

# Hooks run automatically on git push
git push

# Manually run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run shellcheck --all-files

# Bypass hooks (use sparingly!)
git commit --no-verify
SKIP=shellcheck git commit -m "Skip shellcheck only"
```

## 🔧 Available Hooks

### Pre-commit Hooks (Run on `git commit`)

#### File Formatting

- **trailing-whitespace** - Removes trailing whitespace
- **end-of-file-fixer** - Ensures files end with newline
- **mixed-line-ending** - Fixes mixed line endings (uses LF)

#### Security Checks

- **detect-private-key** - Detects committed private keys
- **check-added-large-files** - Prevents large files (>500KB)
- **check-secrets** - Scans for potential secrets in code
- **check-merge-conflict** - Detects unresolved merge conflicts

#### Syntax Validation

- **check-yaml** - Validates YAML syntax
- **check-json** - Validates JSON syntax
- **check-toml** - Validates TOML syntax
- **fish-syntax** - Checks Fish shell syntax
- **zsh-syntax** - Checks Zsh shell syntax

#### Shell Script Quality

- **shellcheck** - Comprehensive shell script linting
- **shfmt** - Shell script formatting
- **lint-shell** - Custom shell linting script

#### Code Quality

- **check-case-conflict** - Prevents case-insensitive filename conflicts
- **check-symlinks** - Validates symbolic links
- **check-executables-have-shebangs** - Ensures scripts have proper shebangs

#### Markdown & Documentation

- **markdownlint-cli2** - Lints markdown files for consistency

#### YAML Linting

- **yamllint** - Validates YAML files with custom rules

#### Dotfiles-Specific

- **validate-config** - Runs dotfiles configuration validation
- **check-generated-files** - Ensures abbreviations are regenerated
- **check-todos** - Reports TODO/FIXME markers (informational)

### Pre-push Hooks (Run on `git push`)

More intensive checks that run before pushing to remote:

- **run-tests** - Executes full test suite (bats tests)
- **full-validation** - Runs complete validation framework
- **check-todos** - Warns about TODO/FIXME markers

### Post-commit Hook (Run after `git commit`)

- **dirty-tree-detection** - Warns if pre-commit hooks modified files after staging

## 📚 Configuration Files

### Main Configuration

- **`.pre-commit-config.yaml`** - Main pre-commit configuration
- **`.gitlint`** - Commit message linting rules
- **`markdown/.markdownlint-cli2.yaml`** - Markdown linting rules
- **`yamllint/.yamllint`** - YAML linting rules

### Local Overrides

Create `.pre-commit-config.local.yaml` (gitignored) to override defaults:

```bash
cp .pre-commit-config.local.yaml.example .pre-commit-config.local.yaml
vim .pre-commit-config.local.yaml
```

## 🎯 Common Workflows

### Skip Specific Hooks

```bash
# Skip one hook
SKIP=shellcheck git commit -m "message"

# Skip multiple hooks
SKIP=shellcheck,shfmt git commit -m "message"

# Skip all hooks (emergency only!)
git commit --no-verify -m "message"
```

### Run Hooks Manually

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run on specific files
pre-commit run --files file1.sh file2.fish

# Run specific hook
pre-commit run shellcheck

# Run with verbose output
pre-commit run --all-files --verbose

# Show diff when hooks fail
pre-commit run --all-files --show-diff-on-failure
```

### Update Hook Versions

```bash
# Update to latest versions
pre-commit autoupdate

# Update hooks after config change
./scripts/setup-git-hooks.sh --update
```

### Troubleshooting Failed Hooks

```bash
# View detailed error output
pre-commit run --verbose --all-files

# Fix auto-fixable issues
./scripts/validate-config.sh --fix

# Clean pre-commit cache
pre-commit clean

# Reinstall hooks
pre-commit uninstall
pre-commit install
```

## 🔍 Hook Details

### Shellcheck Configuration

Shellcheck runs with these settings:

- **Severity**: warning (ignores info/style)
- **Shell**: bash (POSIX-compatible)
- **Excluded**: test files, scratchpad files

Common shellcheck issues:

```bash
# SC2086: Quote variables to prevent word splitting
echo $VAR          # Bad
echo "$VAR"        # Good

# SC2046: Quote command substitution
rm $(find .)       # Bad
rm "$(find .)"     # Good

# SC2034: Variable appears unused
# Add comment: # Used in sourced file
```

### Shfmt Configuration

Shell scripts are formatted with:

- **Indent**: 2 spaces
- **Binary ops**: Start of line
- **Switch cases**: Indented
- **Redirect**: Space after redirect

### Markdown Linting

Follows [markdownlint rules](https://github.com/DavidAnson/markdownlint):

- Line length: 80 characters (MD013 disabled)
- Consistent heading style
- Proper list formatting
- No trailing spaces

### Commit Message Linting

Follows gitlint rules:

- Max title length: 72 characters
- Max body line length: 80 characters
- No trailing whitespace
- Optional: Conventional Commits format

## 📊 Performance

Hook execution times (approximate):

- **Pre-commit hooks**: 5-15 seconds (depending on file changes)
- **Pre-push hooks**: 30-120 seconds (includes test suite)
- **Post-commit hooks**: <1 second

Optimize performance:

```bash
# Run hooks only on changed files (default)
git commit

# Skip expensive pre-push hooks during development
git push --no-verify

# Use --fast flag for tests
./scripts/run-tests --fast
```

## 🛠️ Advanced Usage

### Custom Hooks

Add personal hooks in `.pre-commit-config.local.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: my-custom-check
        name: My custom validation
        entry: ./scripts/my-check.sh
        language: script
        pass_filenames: false
```

### Disable Specific Hook Permanently

Edit `.pre-commit-config.yaml` and remove or comment out the hook.

### Run Hooks in CI/CD

Pre-commit hooks run automatically in GitHub Actions via the validation workflow.

Manual CI execution:

```bash
pre-commit run --all-files --show-diff-on-failure
```

### Hook Debugging

```bash
# Enable verbose output
pre-commit run --verbose shellcheck

# Run specific hook with debug
pre-commit run --verbose --hook-stage manual shellcheck

# Check hook installation
pre-commit validate-config
pre-commit validate-manifest
```

## 📝 Best Practices

1. **Run hooks before committing** - Catch issues early
2. **Don't bypass hooks** - Use `--no-verify` only in emergencies
3. **Fix issues, don't skip** - Address root causes
4. **Update regularly** - Run `pre-commit autoupdate` monthly
5. **Test locally** - Use `pre-commit run --all-files` before pushing
6. **Review auto-fixes** - Check what hooks changed
7. **Keep hooks fast** - Expensive checks in pre-push only

## 🆘 Troubleshooting

### Hook Failed with "Command not found"

```bash
# Install missing tool
brew install shellcheck

# Or ensure it's in PATH
which shellcheck
```

### Hook Keeps Failing

```bash
# View detailed error
pre-commit run --verbose hook-id

# Try auto-fix
./scripts/validate-config.sh --fix

# Check hook configuration
pre-commit validate-config
```

### Hooks Not Running

```bash
# Check installation
./scripts/setup-git-hooks.sh --check

# Reinstall
./scripts/setup-git-hooks.sh --uninstall
./scripts/setup-git-hooks.sh
```

### Files Modified After Commit

This is normal for auto-formatting hooks. The post-commit hook will warn you:

```bash
# Include fixes in last commit
git add .
git commit --amend --no-edit

# Or create separate commit
git add .
git commit -m "style: auto-fix by pre-commit hooks"
```

### Performance Issues

```bash
# Clear cache
pre-commit clean

# Run only fast hooks
SKIP=run-tests,full-validation git push

# Use --fast flag for tests
./scripts/run-tests --fast
```

## 🔗 Resources

- [Pre-commit Framework](https://pre-commit.com/)
- [Pre-commit Hooks Repository](https://github.com/pre-commit/pre-commit-hooks)
- [Shellcheck Wiki](https://www.shellcheck.net/wiki/)
- [Markdownlint Rules](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Gitlint Documentation](https://jorisroovers.com/gitlint/)

## 💡 Tips

- Use `git commit -v` to see diff while writing commit message
- Set `export SKIP=hook-id` in shell config to permanently skip a hook
- Create git aliases for common operations:
  ```bash
  git config alias.nc 'commit --no-verify'
  git config alias.np 'push --no-verify'
  ```
- Run `pre-commit run --all-files` before creating PR
- Use `pre-commit try-repo` to test new hooks before adding

---

*Last updated: 2025-10-23*
