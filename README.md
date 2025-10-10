# MyLinuxHelper

Use Linux easily.

## Quick Setup

```bash
chmod +x setup.sh
./setup.sh
```

## Example Usage

```bash
isjsonvalid a.json
ll /etc
```

## Linux Utility Plugins

A lightweight, modular plugin system for Linux shell environments.

## 📦 Structure

```
/
├── setup.sh         # Main setup script
├── install.sh       # Universal package installer
└── plugins/
    ├── isjsonvalid.sh  # Validate JSON files using jq
    └── ll.sh           # Shortcut for "ls -la"
```

## 🚀 Usage

1. Give execute permission **only once**:
    ```bash
    chmod +x setup.sh
    ```
2. Run setup:
    ```bash
    ./setup.sh
    ```
3. Start using:
    ```bash
    isjsonvalid data.json
    ll /etc
    i net-tools 
    ```