# MyLinuxHelper v1.5.0 - Release Notes

**Release Date:** 2025-11-09
**Previous Version:** v1.4.1

---

## 🎉 What's New in v1.5.0

### ⭐ Major Feature: Configurable Bookmark Shortcuts (Phase 4)

We've added a highly requested usability feature - **configurable shortcut aliases** for the `bookmark` command!

#### Key Highlights:

- **Custom Shortcuts:** Create your own shortcut/alias for the `bookmark` command (e.g., `bm`, `fav`, `goto`)
- **Simple Setup:** Just add `BOOKMARK_ALIAS=bm` to `~/.mylinuxhelper/mlh.conf` and run `./setup.sh`
- **Smart Conflict Detection:** Setup warns if your chosen alias conflicts with existing commands
- **Dynamic Help:** Help text automatically shows examples using your configured shortcut
- **Full Feature Support:** All bookmark features work with the alias - it's just a convenient shortcut

#### Example Usage:

```bash
# After setup, if you chose 'bm':
bm .                    # Save current directory
bm list                 # Interactive list (NEW: default behavior)
bm myproject            # Jump to named bookmark
bm --help               # Help shows 'bm' in examples
```

#### Configuration:

- **Config file:** `~/.mylinuxhelper/mlh.conf` (new centralized config for all MLH settings)
- **Format:** `BOOKMARK_ALIAS=bm`
- **Example:** See `docs/config/mlh.conf.example` in repository
- Change anytime by editing the config file and re-running `./setup.sh`
- Set to empty string to disable the shortcut

---

### 🚀 Improved Default Behavior

#### Interactive List by Default
- **`bookmark list` now shows interactive TUI by default** (was non-interactive)
- **Faster workflow:** No need to add `-i` flag anymore
- **New flag:** Use `bookmark list -n` for non-interactive simple output
- **Filter support:** `bookmark list <category>` opens interactive list filtered by category

**Before:**
```bash
bookmark list           # Non-interactive output
bookmark list -i        # Interactive TUI (had to specify)
```

**Now:**
```bash
bookmark list           # Interactive TUI (default - faster!)
bookmark list -n        # Non-interactive output (when needed)
```

---


### ✨ Enhancements

#### Unified Configuration System
- **New:** Centralized `mlh.conf` for all MLH configuration
- **Better organized:** Clear sections for different features
- **Future-ready:** All future MLH settings will use this file
- **Example provided:** See `docs/config/mlh.conf.example`

#### Bookmark System
- **Improved:** Hierarchical category display in list view
  - Categories now display with proper indentation: `📂 projects/linux`
  - Subcategories are shown nested under parent categories
- **Improved:** Path validation warnings with better visual indicators (⚠ symbol)
- **Improved:** Better handling of command name conflicts during bookmark creation

#### Testing & Quality
- **Reorganized:** Bookmark tests moved to `tests/bookmark/` subdirectory
- **Added:** Comprehensive test suite for bookmark alias feature (41 new tests)
  - Config file handling (28 tests)
  - Dynamic help display
  - Alias validation and conflict detection
  - Integration tests (13 tests)
- **Added:** Automated ShellCheck validation test suite
  - Validates all shell scripts for code quality
  - Integrated into main test runner
- **Total Test Count:** Now **293 tests** (was 246)
  - bookmark/mlh-bookmark: 80 tests
  - bookmark/bookmark-alias: 28 tests  
  - bookmark/bookmark-alias-integration: 13 tests
  - shellcheck: 6 tests (validates code quality)
  - All other test suites: stable
- **Code Quality:** All scripts pass ShellCheck validation
- **Formatting:** All scripts formatted with shfmt for consistency

---

### 📚 Documentation Updates

#### New Documentation
- **`docs/config/mlh.conf.example`:** Template configuration file with all options documented
- **`docs/BOOKMARK_ALIAS_GUIDE.md`:** Comprehensive alias setup and troubleshooting guide (moved from old location)

#### Updated Documentation
- **`CLAUDE.md`:** 
  - Updated with centralized config system architecture
  - New test structure documentation
  - Bookmark alias implementation details
- **`README.md`:** 
  - Updated bookmark examples to show new default behavior
  - Config system reference

---

## 📊 Test Results

```
Total tests:  293
Passed:       288 (98.3%)
Skipped:       5 (shellcheck tests when shellcheck not available)
Failed:        0

Test Coverage by Component:
✅ bookmark/bookmark-alias-integration: 13/13 passed
✅ bookmark/bookmark-alias:             28/28 passed
✅ bookmark/mlh-bookmark:               80/80 passed
✅ current-session:                     1/1 passed
✅ isjsonvalid:                         18/18 passed
✅ linux:                               15/15 passed
✅ ll:                                  10/10 passed
✅ mlh-about:                           12/12 passed
✅ mlh-docker:                          18/18 passed
✅ mlh-history:                         34/34 passed
✅ mlh-json:                            18/18 passed
✅ mlh:                                 20/20 passed
✅ search:                              16/16 passed
✅ shellcheck:                           6/6 passed (when shellcheck available)
✅ time-debug:                          4/4 passed
```

**Note:** All tests pass when required tools (shellcheck, tmux) are available. Test suite now includes automated ShellCheck validation.

---

## 🔄 Migration Guide

### Upgrading from v1.4 or v1.4.1

1. **Run Update:**
   ```bash
   mlh update
   # Or manually:
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/melihcelenk/MyLinuxHelper/main/get-mlh.sh)"
   ```

2. **Configure Alias (Optional):**
   ```bash
   # Create/edit config file
   mkdir -p ~/.mylinuxhelper
   nano ~/.mylinuxhelper/mlh.conf
   
   # Add your preferred alias
   BOOKMARK_ALIAS=bm
   
   # Re-run setup to apply changes
   cd ~/.mylinuxhelper
   ./setup.sh
   
   # Reload shell
   source ~/.bashrc
   ```

### No Breaking Changes

- All existing `bookmark` commands continue to work exactly as before
- **New default:** `bookmark list` now shows interactive menu (faster workflow!)
- Existing bookmarks in `~/.mylinuxhelper/bookmarks.json` are fully compatible
- Shortcut/alias feature is completely optional

---

## 📦 Installation

### New Installation
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/melihcelenk/MyLinuxHelper/main/get-mlh.sh)" \
|| bash -c "$(wget -qO- https://raw.githubusercontent.com/melihcelenk/MyLinuxHelper/main/get-mlh.sh)"
```

### Update Existing Installation
```bash
mlh update
```

---

## 🎯 Roadmap for v1.6

Based on the TODO.md and GitHub issues, future enhancements being considered:

- **Centralized config system expansion** - Additional settings for history, docker, etc.
- **fzf integration** for fuzzy finding bookmarks
- **Tab completion** for bookmark names and categories
- **Git repo detection** - automatically bookmark git repository roots
- **Frecency-based sorting** - most frequently/recently used bookmarks first
- **Bookmark export/import** for sharing across machines
- **Bookmark sync** via Git for multi-device workflows

---

## 🐛 Known Issues

1. **ShellCheck Tests:** ShellCheck validation tests are skipped if `shellcheck` is not installed. Install with `sudo apt-get install shellcheck` (or use Docker) to run these tests.
2. **WSL Compatibility:** Interactive mode works but may require `/dev/tty` fallback in some WSL configurations. This is automatically handled by the code.

---

## 📞 Support & Feedback

- **Issues:** https://github.com/melihcelenk/MyLinuxHelper/issues
- **Discussions:** https://github.com/melihcelenk/MyLinuxHelper/discussions
- **Documentation:** See `README.md` and `CLAUDE.md` in the repository

---

## 🙏 Acknowledgments

Special thanks to all contributors and users who provided feedback on the bookmark system and requested the alias feature!

---

**Full Changelog:** https://github.com/melihcelenk/MyLinuxHelper/compare/v1.4.1...v1.5.0

---

## 📝 Note on v1.4.1

v1.4.1 was an internal release with code quality improvements (ShellCheck fixes, formatting). This release (v1.5.0) includes all user-facing features and enhancements since v1.4.1.
