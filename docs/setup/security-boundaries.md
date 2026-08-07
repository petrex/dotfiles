# Setup Safety Boundaries

The setup workflow is separated into link, user, and system phases. Each phase
has a deliberately different permission and side-effect boundary.

## Link Phase

```bash
./setup.sh --dry-run
./setup.sh
```

The link phase:

- creates `~/.config` and `~/.local/bin` when needed;
- backs up conflicting home-directory files;
- creates GNU Stow symlinks; and
- never uses sudo, changes system settings, or accesses the network.

This is the safe default for updating an existing machine. It can also be
tested with an isolated home directory:

```bash
test_home="$(mktemp -d)"
HOME="${test_home}" DOTFILES="$PWD" ./setup.sh
```

## User Phase

```bash
./scripts/setup-user.sh --dry-run
./scripts/setup-user.sh
```

The user phase configures state that cannot be represented by symlinks:

- Fish universal paths;
- compiled terminfo entries under `~/.terminfo`; and
- Tmux Plugin Manager under the dotfiles tmux package.

It never invokes sudo or changes machine-wide settings. It may access GitHub to
clone Tmux Plugin Manager. Use `--dry-run` to prevent changes and network access.

## System Phase

```bash
./scripts/setup-system.sh --dry-run
./scripts/setup-system.sh
```

The system phase is the only setup phase allowed to request administrator
access. It currently synchronizes the macOS `HostName` and SMB `NetBIOSName`
with the existing `LocalHostName`. No Linux system settings are currently
managed.

The script prints every planned system change before calling `sudo`. Run it as
your normal user; do not run the entire script with `sudo`, because doing so can
create root-owned files in your home directory.

## Full Bootstrap

The fresh-machine bootstrap deliberately orchestrates all three phases:

```text
prerequisites -> clone -> link -> runtimes -> packages -> user -> system -> shell
```

Preview the complete process with:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/petrex/dotfiles/master/scripts/bootstrap.sh) --dry-run
```

Running `setup.sh` by itself remains link-only. This keeps routine dotfile
updates nonprivileged while retaining the one-command fresh-machine workflow.
