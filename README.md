# MyLinuxHelper

A lightweight and modular collection of utility tools to simplify your Linux experience.

## Features

- **JSON Validation**: Quickly validate JSON files with the `isjsonvalid` command
- **Enhanced Directory Listing**: View detailed file and directory information with the `ll` command (ls -la shortcut)
- **Smart Package Manager**: Automatically detects and uses apt, yum, dnf, or other package managers with the `i` command
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

1. Start using:
    ```bash
    isjsonvalid data.json
    ll /etc
    i --help
    i net-tools
    ```



## 📦 Structure

```
/
├── setup.sh         # Main setup script
├── install.sh       # Universal package installer
└── plugins/
    ├── isjsonvalid.sh  # Validate JSON files using jq
    └── ll.sh           # Shortcut for "ls -la"
```

