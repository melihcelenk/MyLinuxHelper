# MyLinuxHelper

A lightweight and modular collection of utility tools to simplify your Linux experience.

## Features

- **Interactive Command Menu**: Browse and explore all commands with the `mlh` interactive menu
- **Smart Docker Management**: Quickly enter running containers by name pattern with `mlh docker in`
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
└── plugins/
    ├── mlh.sh          # Interactive menu and command dispatcher
    ├── mlh-docker.sh   # Docker shortcuts and container management
    ├── mlh-json.sh     # Advanced JSON search (delegates validation to isjsonvalid.sh)
    ├── mlh-version.sh  # Version management and auto-update system
    ├── mlh-about.sh    # Project information and about page
    ├── linux.sh        # Launch and manage Docker containers
    ├── search.sh       # Fast file search using find
    ├── isjsonvalid.sh  # Centralized JSON validation with flexible output modes
    └── ll.sh           # Shortcut for "ls -la"
```

