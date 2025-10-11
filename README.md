# MyLinuxHelper

A lightweight and modular collection of utility tools to simplify your Linux experience.

## Features

- **Isolated Linux Containers**: Quickly launch and manage Linux containers with the `linux` command
- **Smart Package Manager**: Automatically detects and uses apt, yum, dnf, or other package managers with the `i` command
- **JSON Validation**: Quickly validate JSON files with the `isjsonvalid` command
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

#### `isjsonvalid` - JSON Validator
Validate JSON files using jq:
```bash
# Validate a JSON file
isjsonvalid data.json

# Validate multiple files
isjsonvalid file1.json file2.json
```

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



## 📦 Structure

```
/
├── setup.sh            # Main setup script
├── install.sh          # Universal package installer
└── plugins/
    ├── linux.sh        # Launch and manage Docker containers
    ├── isjsonvalid.sh  # Validate JSON files using jq
    └── ll.sh           # Shortcut for "ls -la"
```

