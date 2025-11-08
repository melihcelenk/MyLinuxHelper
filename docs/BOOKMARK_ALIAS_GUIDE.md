# Bookmark Alias Configuration Guide

This guide explains how to configure a custom shortcut/alias for the `bookmark` command.

## Quick Start

1. Create the config file:

```bash
mkdir -p ~/.mylinuxhelper
echo "BOOKMARK_ALIAS=bm" > ~/.mylinuxhelper/bookmark-alias.conf
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
bm list -i     # Interactive list
```

## Configuration Details

### Config File Location

The configuration file must be at:

```
~/.mylinuxhelper/bookmark-alias.conf
```

### Config File Format

The file should contain a single line:

```bash
BOOKMARK_ALIAS=your_alias_name
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

You can add comments or other variables:

```bash
# Bookmark alias configuration
BOOKMARK_ALIAS=bm

# Other settings can go here too
SOME_OTHER_VAR=value
```

Only `BOOKMARK_ALIAS` is used by the bookmark system.

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
User types: bm list -i
  ↓
bm() function in ~/.bashrc
  ↓
bookmark() function in ~/.bashrc  
  ↓
mlh-bookmark.sh executes
  ↓
cd command executed in parent shell
```

## Changing Your Alias

To change the alias:

1. Edit the config file:

```bash
echo "BOOKMARK_ALIAS=fav" > ~/.mylinuxhelper/bookmark-alias.conf
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

**Note**: The old alias will remain in your `.bashrc` but won't cause issues. You can manually remove it if desired.

## Disabling the Alias

To disable the alias and use only `bookmark`:

1. Clear the config file:

```bash
echo "" > ~/.mylinuxhelper/bookmark-alias.conf
# Or delete it
rm ~/.mylinuxhelper/bookmark-alias.conf
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

- Make sure the config file exists at `~/.mylinuxhelper/bookmark-alias.conf`
- Verify the config file is readable: `cat ~/.mylinuxhelper/bookmark-alias.conf`
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
echo "BOOKMARK_ALIAS=b" > ~/.mylinuxhelper/bookmark-alias.conf
./setup.sh
source ~/.bashrc

b .              # Save
b 1              # Jump
b list           # List
```

### Example 2: Descriptive alias 'goto'

```bash
echo "BOOKMARK_ALIAS=goto" > ~/.mylinuxhelper/bookmark-alias.conf
./setup.sh
source ~/.bashrc

goto .           # Save
goto projects    # Jump to named bookmark
goto list        # List
```

### Example 3: Using with categories

```bash
echo "BOOKMARK_ALIAS=fav" > ~/.mylinuxhelper/bookmark-alias.conf
./setup.sh
source ~/.bashrc

fav . -n myapp in projects/java
fav myapp
fav list projects
```

## Advanced: Checking Current Configuration

To see your current alias configuration:

```bash
cat ~/.mylinuxhelper/bookmark-alias.conf
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
