# Bookmark Alias Configuration Guide

This guide explains how to configure a custom shortcut/alias for the `bookmark` command.

## Quick Start

1. Create the config file:
```bash
mkdir -p ~/.mylinuxhelper
echo "BOOKMARK_ALIAS=bm" > ~/.mylinuxhelper/mlh.conf
```

2. Run setup:
```bash
cd ~/.mylinuxhelper
./setup.sh
```

3. Apply changes (important!):
```bash
source ~/.bashrc
```

Now you can use `bm` instead of `bookmark`:
```bash
bm .           # Save current directory
bm 1           # Jump to bookmark 1
bm list        # Interactive list (default)
```

## Configuration Details

### Config File Location

The configuration file must be at:
```
~/.mylinuxhelper/mlh.conf
```

### Config File Format

The file should contain:
```bash
# MyLinuxHelper Configuration
BOOKMARK_ALIAS=bm
```

**Valid alias names:**
- Alphanumeric characters and underscores only
- No spaces or special characters
- Examples: `bm`, `b`, `fav`, `goto`, `quick_mark`

**Invalid alias names:**
- Names with spaces: `my bookmark` ❌
- Names with special chars: `book-mark`, `book@mark` ❌
- Existing command names: `cd`, `ls`, `git` ❌ (will be detected and skipped)

### Multiple Variables

You can add comments or other settings:
```bash
# MyLinuxHelper Configuration
# Bookmark command alias
BOOKMARK_ALIAS=bm

# Other future settings can go here
```

Only `BOOKMARK_ALIAS` is used by the bookmark system currently.

## How It Works

When you configure an alias:

1. **Symlink**: A symlink is created at `~/.local/bin/your_alias` → `mlh-bookmark.sh`
2. **Wrapper Function**: A bash function is added to `~/.bashrc`:
   ```bash
   your_alias() {
     bookmark "$@"
   }
   ```
3. **Help Integration**: The `--help` output automatically uses your alias name

### Command Chain

```
User types: bm list
  ↓
bm() function in ~/.bashrc
  ↓
bookmark() function in ~/.bashrc  
  ↓
mlh-bookmark.sh executes
  ↓
Interactive TUI displayed
```

## Changing Your Alias

To change the alias:

1. Edit the config file:
```bash
nano ~/.mylinuxhelper/mlh.conf
# Change BOOKMARK_ALIAS=bm to BOOKMARK_ALIAS=fav
```

2. Re-run setup:
```bash
cd ~/.mylinuxhelper
./setup.sh
```

3. Apply changes:
```bash
source ~/.bashrc
```

**Note**: The old alias function will remain in your `.bashrc` but won't cause issues. You can manually remove it if desired.

## Disabling the Alias

To disable the alias and use only `bookmark`:

1. Edit or clear the config file:
```bash
nano ~/.mylinuxhelper/mlh.conf
# Set BOOKMARK_ALIAS="" or delete the line
```

2. Re-run setup:
```bash
cd ~/.mylinuxhelper
./setup.sh
```

The symlink won't be created, but the function in `.bashrc` will remain (harmless).

## Troubleshooting

### Alias not working after setup

**Problem**: You ran setup but `bm` doesn't work.

**Solution**: You must reload your shell:
```bash
source ~/.bashrc
```

Or open a new terminal.

### Command conflict detected

**Problem**: Setup says "Command 'xyz' already exists"

**Solution**: 
- Choose a different alias name that doesn't conflict
- The setup script checks `command -v your_alias` to prevent conflicts

### Help still shows 'bookmark' instead of alias

**Problem**: `bm --help` shows examples with `bookmark` instead of `bm`

**Solution**:
- Make sure the config file exists at `~/.mylinuxhelper/mlh.conf`
- Verify the config file is readable: `cat ~/.mylinuxhelper/mlh.conf`
- The plugin reads the config at runtime

### Alias works but directory doesn't change

**Problem**: `bm 1` runs but doesn't change directory

**Solution**: Make sure you sourced `.bashrc` after setup:
```bash
source ~/.bashrc
```

The wrapper function must be loaded for `cd` to work.

## Examples

### Example 1: Short alias 'b'
```bash
echo "BOOKMARK_ALIAS=b" > ~/.mylinuxhelper/mlh.conf
./setup.sh
source ~/.bashrc

b .              # Save
b 1              # Jump
b list           # Interactive list
```

### Example 2: Descriptive alias 'goto'
```bash
echo "BOOKMARK_ALIAS=goto" > ~/.mylinuxhelper/mlh.conf
./setup.sh
source ~/.bashrc

goto .           # Save
goto projects    # Jump to named bookmark
goto list        # Interactive list
```

### Example 3: Using with categories
```bash
echo "BOOKMARK_ALIAS=fav" > ~/.mylinuxhelper/mlh.conf
./setup.sh
source ~/.bashrc

fav . -n myapp in projects/java
fav myapp
fav list projects
```

## Advanced: Checking Current Configuration

To see your current alias configuration:
```bash
cat ~/.mylinuxhelper/mlh.conf
```

To test if the alias is loaded:
```bash
type bm    # Should show: bm is a function
type bookmark  # Should show: bookmark is a function
```

To see where the symlink points:
```bash
ls -l ~/.local/bin/bm
# Should show: bm -> /home/user/.mylinuxhelper/plugins/mlh-bookmark.sh
```
