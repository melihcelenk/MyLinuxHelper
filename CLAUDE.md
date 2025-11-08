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
- Installs wrapper functions in `~/.bashrc`:
    - `mlh()` wrapper: Ensures current session history is visible
    - `bookmark()` wrapper: Enables `cd` functionality for bookmark navigation
    - `<alias>()` wrapper: Creates custom alias if configured (e.g., `bm()`)
- Creates symlink for bookmark alias if configured
- Shows warning message when `.bashrc` is updated (reminds user to run `source ~/.bashrc`)
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
- **Automatic shell reload**: After update, automatically reloads shell with `exec bash -l`

Configuration is stored in `~/.mylinuxhelper/.update-config`.

**Update Process:**

1. Downloads `get-mlh.sh` from GitHub
2. Runs installation (updates files, runs `setup.sh`)
3. Automatically reloads shell to apply wrapper functions and updates
4. No manual `source ~/.bashrc` required

### Quick Directory Bookmarks

`mlh-bookmark.sh` provides a fast navigation system with hierarchical organization:

**Features (Phase 1, 2 & 3 Complete):**

- **Numbered stack**: Quick save/restore (max 10 bookmarks, auto re-numbering on delete)
- **Named bookmarks**: Persistent bookmarks with memorable names
- **Hierarchical categories**: Organize bookmarks (e.g., `projects/linux`, `projects/java`)
- **Interactive menu**: Full-featured TUI with arrow key navigation (`bookmark list -i`)
    - Navigate with ↑/↓ or j/k (vim-style)
    - Jump, edit, delete bookmarks in real-time
    - Hierarchical category display
    - Built-in help menu ('h' key)
- **Category filtering**: List and filter by category
- **Move bookmarks**: Relocate bookmarks between categories
- **Smart search**: Find bookmarks by name, path, or category (`bookmark find <pattern>`)
- **Bookmark management**: Edit, remove, clear operations
- **JSON storage**: `~/.mylinuxhelper/bookmarks.json`
- **Shell integration**: Wrapper function enables instant `cd` navigation

**Architecture:**

- Stack-based unnamed bookmarks (LIFO, auto-rotating)
- Named bookmarks with category support and access tracking
- Command name conflict detection (prevents naming conflicts with system commands)
- Path validation with warnings (⚠ symbol for missing paths)
- jq-based JSON manipulation
- Bash wrapper function for parent shell directory changes

**Usage patterns:**

```bash
bookmark .                      # Save current dir (becomes #1)
bookmark 1                      # Jump to bookmark #1
bookmark . -n myproject         # Save with name
bookmark . -n mlh in projects   # Save with category
bookmark myproject              # Jump to named bookmark
bookmark list                   # Show all bookmarks (grouped by category)
bookmark list -i                # Interactive menu (arrow keys, edit, delete)
bookmark list projects          # Filter by category
bookmark mv mlh to tools        # Move bookmark to different category
bookmark edit myproject         # Edit bookmark (name/path/category)
bookmark rm myproject           # Remove bookmark
bookmark rm 2                   # Remove #2 (auto re-numbers remaining)
bookmark find java              # Search bookmarks
bookmark clear                  # Clear all numbered bookmarks
```

**Wrapper Function (setup.sh):**

The `setup.sh` script automatically installs a wrapper function in `~/.bashrc` that enables `cd` functionality:

- When jumping to bookmarks (`bookmark 1` or `bookmark name`), the wrapper evaluates the output
- The script outputs a `cd` command that the wrapper executes in the parent shell
- Other commands (`list`, `mv`, save operations) pass through normally

**Alias Support:**

Users can configure a custom shortcut/alias for the bookmark command:

- Configuration file: `~/.mylinuxhelper/bookmark-alias.conf`
- Format: `BOOKMARK_ALIAS=bm` (or any alphanumeric name)
- Example config: `bookmark-alias.conf.example` in repository root
- After configuration, run `setup.sh` and `source ~/.bashrc`
- Aliases delegate to the main bookmark function (full feature support)
- Command conflict detection prevents overriding system commands
- Help dynamically shows alias name in examples when configured
- See `docs/BOOKMARK_ALIAS_GUIDE.md` for detailed setup instructions

**Storage format:**

```json
{
   "bookmarks": {
      "named": [
         {
            name,
            path,
            category,
            created,
            accessed,
            access_count
         }
      ],
      "unnamed": [
         {
            id,
            path,
            created
         }
      ]
   },
   "config": {
      max_unnamed: 10,
      auto_cleanup: true
   }
}
```

## Testing & Development

### Test Execution (Project-Specific)

**Docker command for this project:**

```bash
docker run --rm -v "//c/Kodlar/Python-Bash-Bat/MyLinuxHelper://mlh" ubuntu:22.04 bash -c \
  "cd /mlh && apt-get update -qq && apt-get install -y -qq jq >/dev/null 2>&1 && \
   bash tests/test <test-name>"
```

**Local testing:**

```bash
bash tests/test <test-name>
```

### Automated Testing

The test suite uses a standardized framework:

```bash
# Run all tests
bash tests/test

# Run specific test suite
bash tests/test mlh-bookmark

# Test output format
✓ PASS: Test description
✗ FAIL: Test description
  Error details
⊘ SKIP: Test description
  Reason for skip
```

**Test File Structure:**

```bash
tests/
├── test                              # Main test runner
├── test-mlh-bookmark.sh             # Bookmark feature tests (80 tests - Phase 1, 2 & 3 + bug fixes)
├── test-bookmark-alias.sh           # Bookmark alias tests (28 tests)
├── test-bookmark-alias-integration.sh # Alias integration tests (11 tests)
├── test-mlh-history.sh              # History feature tests
├── test-mlh-json.sh                 # JSON validation tests
└── ...
```

### Manual Testing

After making changes to any plugin script:

1. Run `./setup.sh` to refresh symlinks and permissions
2. **Run automated tests**: `bash tests/test <component>`
3. **Verify all tests pass** before proceeding
4. Test the command directly (e.g., `mlh docker in test`)
5. Test both standalone mode and via `mlh` dispatcher

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
├── setup.sh            # Creates symlinks, configures PATH, installs wrapper functions
├── install.sh          # Universal package installer (provides 'i' command)
├── README.md           # User documentation with usage examples
├── CLAUDE.md           # Development documentation (this file)
├── TODO.md             # Feature roadmap and implementation checklist
├── .gitignore          # Ignore IDE files, OS files, runtime data
├── plugins/
│   ├── mlh.sh          # Main command dispatcher with interactive menu
│   ├── mlh-bookmark.sh # Quick directory bookmarks (JSON-based, category support)
│   ├── mlh-docker.sh   # Docker container shortcuts
│   ├── mlh-json.sh     # JSON search (delegates validation to isjsonvalid.sh)
│   ├── mlh-history.sh  # Enhanced command history with date tracking
│   ├── mlh-version.sh  # Version management and auto-update system
│   ├── mlh-about.sh    # Project information
│   ├── linux.sh        # Docker container lifecycle management
│   ├── search.sh       # File search using find
│   ├── isjsonvalid.sh  # Centralized JSON validation engine
│   └── ll.sh           # ls -la shortcut
└── tests/
    ├── test                              # Main test runner framework (285 tests total)
    ├── test-mlh-bookmark.sh             # Bookmark tests (80 tests, requires jq)
    ├── test-bookmark-alias.sh           # Bookmark alias tests (28 tests)
    ├── test-bookmark-alias-integration.sh # Alias integration tests (11 tests)
    ├── test-mlh-history.sh              # History tests (34 tests)
    ├── test-mlh-json.sh                 # JSON validation tests (18 tests)
    ├── test-mlh-docker.sh               # Docker tests (18 tests)
    ├── test-current-session.sh          # Session history tests (1 test)
    ├── test-time-debug.sh               # Time parsing tests (4 tests)
    └── ...
```
