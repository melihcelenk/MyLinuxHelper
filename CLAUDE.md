# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MyLinuxHelper is a modular collection of Bash utility scripts that simplify Linux system administration tasks. It provides a plugin-based architecture where each command is implemented as an independent shell script.

## Installation & Setup

The project uses a two-stage installation process:

1. **Bootstrap**: `get-mlh.sh` downloads the repository (via git or tarball) to `~/.mylinuxhelper`
2. **Setup**: `setup.sh` creates symlinks in `~/.local/bin` and adds it to PATH

### Running Setup

```bash
# After making changes to plugin scripts
./setup.sh

# Optional: Install to /usr/local/bin (requires sudo)
MLH_INSTALL_USR_LOCAL=1 ./setup.sh
```

The setup script automatically:
- Creates symlinks for all commands in `~/.local/bin`
- Adds `~/.local/bin` to PATH in `~/.bashrc` and `~/.profile`
- Makes all plugin scripts executable
- Re-execs the shell if commands aren't immediately available

## Architecture

### Command Dispatcher Pattern

The `mlh.sh` script acts as the main dispatcher for sub-commands. It uses a category-based routing system:

- `mlh docker <cmd>` → delegates to `mlh-docker.sh`
- `mlh json <cmd>` → delegates to `mlh-json.sh`
- `mlh --version` → delegates to `mlh-version.sh`
- `mlh about` → delegates to `mlh-about.sh`
- `mlh` (no args) → shows interactive menu

### Symlink Resolution Pattern

All plugin scripts follow this pattern to resolve the repository root, even when called via symlinks:

```bash
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  TARGET="$(readlink "$SOURCE")"
  if [[ $TARGET == /* ]]; then
    SOURCE="$TARGET"
  else
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$DIR/$TARGET"
  fi
done
PLUGIN_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
ROOT_DIR="$(dirname "$PLUGIN_DIR")"
```

This ensures scripts can locate `install.sh` and other resources regardless of how they're invoked.

### Shared Installer Function

The `install.sh` script provides both:
1. A CLI command (`i <package>`)
2. A sourceable function for use in other scripts

Scripts that need to install dependencies (e.g., `jq` for JSON operations) source it:

```bash
. "$ROOT_DIR/install.sh"
# Now can use: i jq
```

The installer auto-detects the system package manager (apt/yum/dnf/zypper/pacman/apk) and handles sudo appropriately.

## Key Components

### JSON Validation Architecture

There are two entry points but one validation engine:

- **Quick validation**: `isjsonvalid <file>` → outputs "Yes" or "No"
- **Detailed validation**: `isjsonvalid -d <file>` or `mlh json --isvalid <file>` → colored output with error details

Both use `isjsonvalid.sh` as the centralized validation engine. The `mlh-json.sh` script delegates validation to `isjsonvalid.sh` and adds fuzzy search capabilities.

### Container Management

The `linux.sh` script manages Docker containers with two modes:

- **Ephemeral** (default): `linux <name>` creates a container that auto-removes on exit
- **Permanent**: `linux -p <name>` creates a persistent container

Key feature: Automatically mounts the MyLinuxHelper repository at `/opt/mlh` inside containers, making all commands available inside the container by sourcing `/opt/mlh/install.sh`.

### Version Management & Auto-Update

`mlh-version.sh` implements:
- Version display (hardcoded VERSION constant)
- Manual updates via `mlh update`
- Periodic update configuration (daily/weekly/monthly)
- Auto-update hooks in `~/.bashrc`

Configuration is stored in `~/.mylinuxhelper/.update-config`.

## Testing & Development

### Manual Testing

After making changes to any plugin script:

1. Run `./setup.sh` to refresh symlinks and permissions
2. Test the command directly (e.g., `mlh docker in test`)
3. Test both standalone mode and via `mlh` dispatcher

### Common Development Patterns

**Adding a new command:**

1. Create `plugins/<command>.sh` with proper shebang and symlink resolution
2. Add entry to setup.sh LINKS array: `["$LOCAL_BIN/<cmd>"]="$PLUGINS_DIR/<command>.sh"`
3. Optionally add to `mlh.sh` interactive menu
4. Run `./setup.sh` to install

**Adding a new `mlh` sub-command:**

1. Create `plugins/mlh-<category>.sh`
2. Add case statement in `mlh.sh`:
   ```bash
   <category>)
     exec "$SCRIPT_DIR/mlh-<category>.sh" "$@"
     ;;
   ```
3. Update help text in `mlh.sh`

## Important Conventions

### Error Handling

Use `set -euo pipefail` at the start of all scripts for:
- `-e`: Exit on error
- `-u`: Error on undefined variables
- `-o pipefail`: Catch errors in pipes

### Color Output

Standard color definitions used across scripts:

```bash
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
```

### Help Messages

All commands should support `--help` or `-h` flags with usage examples.

### Interactive Menus

Follow the pattern in `mlh.sh` and `mlh-docker.sh`:
- Display numbered options
- Use `read -rp "Select [1-N]: " SELECTION`
- Validate input range
- Support 'q' to quit where appropriate

## Version Updates

When releasing a new version:

1. Update VERSION constant in `plugins/mlh-version.sh`:
   ```bash
   readonly VERSION="X.Y.Z"
   readonly VERSION_DATE="DD.MM.YYYY"
   ```
2. Commit and push to main branch
3. Users can update via `mlh update`

## File Structure

```
/
├── get-mlh.sh          # Bootstrap installer (downloads repo)
├── setup.sh            # Creates symlinks and configures PATH
├── install.sh          # Universal package installer (provides 'i' command)
└── plugins/
    ├── mlh.sh          # Main command dispatcher with interactive menu
    ├── mlh-docker.sh   # Docker container shortcuts
    ├── mlh-json.sh     # JSON search (delegates validation to isjsonvalid.sh)
    ├── mlh-version.sh  # Version management and auto-update system
    ├── mlh-about.sh    # Project information
    ├── linux.sh        # Docker container lifecycle management
    ├── search.sh       # File search using find
    ├── isjsonvalid.sh  # Centralized JSON validation engine
    └── ll.sh           # ls -la shortcut
```
