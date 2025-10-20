# MyLinuxHelper

A lightweight and modular collection of utility tools to simplify your Linux experience.

## Features

- **Interactive Command Menu**: Browse and explore all commands with the `mlh` interactive menu
- **Smart Docker Management**: Quickly enter running containers by name pattern with `mlh docker in`
- **Enhanced Command History**: View command history with dates, search commands, and filter by date range using `mlh history`
- **Fast File Search**: Find files quickly in current directory and subdirectories with the `search` command
- **Isolated Linux Containers**: Quickly launch and manage Linux containers with the `linux` command
- **Smart Package Manager**: Automatically detects and uses apt, yum, dnf, or other package managers with the `i` command
- **Advanced JSON Operations**: Validate and search JSON files with fuzzy matching and intelligent path navigation
- **Enhanced Directory Listing**: View detailed file and directory information with the `ll` command (ls -la shortcut)
- Lightweight and modular plugin system
- Easy installation and usage
- Extensible architecture for adding custom commands

## ⚡ Quick Setup
Run the command below:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/melihcelenk/MyLinuxHelper/main/get-mlh.sh)" \
|| bash -c "$(wget -qO- https://raw.githubusercontent.com/melihcelenk/MyLinuxHelper/main/get-mlh.sh)"
```

## 🚀 Usage

### Available Commands

#### `mlh` - Interactive Command Menu
Browse all available commands interactively:
```bash
# Show interactive menu
mlh

# Show version
mlh -v
mlh --version

# Docker shortcuts
mlh docker in <pattern>
```

**Interactive Menu Example:**
```
MyLinuxHelper - Available Commands
===================================

1. linux <name>              - Create and manage Linux containers
2. i <package>               - Install packages (auto-detects package manager)
3. isjsonvalid <file.json>   - Validate JSON files
4. ll [path]                 - Enhanced directory listing (ls -la)
5. mlh docker in <pattern>   - Enter running Docker container

Select [1-5, q]:
```

#### `mlh docker in` - Smart Container Access
Enter running Docker containers by name pattern:
```bash
# Enter container by name
mlh docker in web

# If multiple containers match, shows interactive menu:
# Multiple containers found matching 'mycontainer':
#
#   1. mycontainer-web (nginx:latest | Up 2 hours)
#   2. mycontainer-api (node:18 | Up 2 hours)
#   3. mycontainer-db (postgres:14 | Up 2 hours)
#
# Select container [1-3]: 1
```

#### `linux` - Container Management
Launch and manage isolated Linux containers quickly:
```bash
# Create ephemeral container (auto-removed on exit)
linux mycontainer

# Create permanent container
linux -p mycontainer

# Stop container
linux -s mycontainer

# Delete container
linux -d mycontainer

# Use different base image
linux -i debian:12 mycontainer

# Bind mount directory
linux -m "$PWD:/workspace" -p mycontainer
```

#### `mlh history` - Enhanced Command History
View command history with dates, search, and filtering:
```bash
# Show last 100 commands (default)
mlh history

# Show all history
mlh history -a

# Show last 10 commands
mlh history 10

# Show detailed history with colors and formatting
mlh history -d

# Search for commands containing "docker"
mlh history -f docker

# Show specific command by number
mlh history -g 1432

# Show commands from specific date
mlh history -t 2025-10-20

# Show commands in date range
mlh history -t 2025-10-18..2025-10-20

# Configure settings (default limit, date tracking, display mode)
mlh history -c
```

**Key Features:**
- **Current session support**: Automatically includes commands from current session via wrapper function
- **Smart defaults**: Shows last 100 commands by default (configurable)
- **Show all**: Use `-a` to display entire history
- **Date tracking**: Shows when each command was executed (configurable)
- **Search functionality**: Find commands by pattern with `mlh history -f <pattern>`
- **Direct access**: Jump to specific command with `mlh history -g <number>`
- **Date filtering**: Filter by date or date range with `mlh history -t <date>`
- **Relative time support**: Use formats like `3d`, `20m`, `2h` for recent commands
- **Before offset**: Specify time offset with `-b` flag (e.g., `-t 20m -b 1h`)
- **Multiple display modes**: Simple (numbered with dates), Detailed (formatted), Minimal (plain)
- **Configurable defaults**: Set default limit, display mode, and enable/disable date tracking
- **Helpful messages**: When no results found, shows latest command timestamp with suggestions
- **Non-intrusive**: Doesn't affect the system `history` command

#### `i` - Smart Package Installer
Automatically detects your package manager (apt, yum, dnf, etc.) and installs packages:
```bash
# Install a package
i nginx

# Install multiple packages
i git curl wget

# Show help
i --help
```

#### `mlh json` / `isjsonvalid` - JSON Operations
Advanced JSON validation and fuzzy search with intelligent path navigation:
```bash
# Quick validation (Yes/No output)
isjsonvalid data.json
# Output: Yes

# Detailed validation
isjsonvalid -d data.json
mlh json --isvalid data.json
# Output: ✓ Valid JSON

# Search for a field (fuzzy match, case-insensitive)
mlh json get name from users.json
# Output: "users"."name": "John"

# Partial key matching - finds "RequestedTags" with just "req"
mlh json get req from config.json
# Output: "RequestedTags": [...]

# Search with path hint (targeted search, no menu)
mlh json get settings.lang from config.json
# Output: "settings"."language": "en"

# Multiple matches - shows interactive menu
mlh json get user from data.json
# Found 3 matches for 'user':
# 1. "users": [...]
# 2. "username": "john"
# 3. "userProfile"."userId": "123"

# Show help
mlh json --help
```

**Key Features:**
- **Centralized validation**: Both `isjsonvalid` and `mlh json --isvalid` use the same engine
- **Flexible output modes**: Quick (Yes/No) or detailed (with colors and error messages)
- Searches ALL JSON keys (arrays, objects, scalars)
- Fuzzy and partial matching (e.g., `req` → `RequestedTags`)
- Path hints for targeted search
- Interactive menu for multiple matches
- Auto-installs `jq` if needed

#### `ll` - Enhanced Directory Listing
Shortcut for `ls -la` to view detailed file information:
```bash
# List current directory
ll

# List specific directory
ll /var/log

# List with pattern
ll *.json
```

#### `search` - Fast File Search
Find files quickly in current directory and subdirectories:
```bash
# Search for file by name
search myfile

# Search for files with wildcard pattern
search "*.json"

# Search in specific directory
search config.js ./src

# Search for configuration files in /etc
search "*.conf" /etc
```



## 📦 Structure

```
/
├── setup.sh            # Main setup script
├── install.sh          # Universal package installer
├── plugins/
│   ├── mlh.sh          # Interactive menu and command dispatcher
│   ├── mlh-docker.sh   # Docker shortcuts and container management
│   ├── mlh-history.sh  # Enhanced command history with dates, search, and filtering
│   ├── mlh-json.sh     # Advanced JSON search (delegates validation to isjsonvalid.sh)
│   ├── mlh-version.sh  # Version management and auto-update system
│   ├── mlh-about.sh    # Project information and about page
│   ├── linux.sh        # Launch and manage Docker containers
│   ├── search.sh       # Fast file search using find
│   ├── isjsonvalid.sh  # Centralized JSON validation with flexible output modes
│   └── ll.sh           # Shortcut for "ls -la"
└── tests/
    ├── test            # Main test runner
    └── test-mlh-history.sh  # Test suite for mlh-history plugin
```

## 🧪 Testing

Run tests to verify functionality:

```bash
# Run all tests
./tests/test

# Run specific test suite
./tests/test mlh-history
```

The test framework includes:
- **28+ tests for mlh-history**: Relative time parsing, date filtering, before offset functionality, edge cases
- **Comprehensive coverage**: Function tests, integration tests, error handling, helpful error messages
- **Color-coded output**: Easy to read pass/fail results
- **Modular design**: Easy to add new test suites for other plugins

**Test Features:**
- Relative time parsing validation (3d, 20m, 2h, etc.)
- Time filtering with recent and old commands
- Before offset calculation accuracy
- Helpful debugging messages when no results found

