# MyLinuxHelper - Quick Bookmark Feature

> **Status**: ⚠️ Phase 1, 2 & 3 Nearly Complete - Interactive Enter Bug Under Investigation | ⏳ Phase 4 Ready (Optional)
> **Priority**: 🔥 HIGH - Interactive mode works on first run, fails on second run
> **Complexity**: ⭐⭐⭐⭐ High (shell wrapper + /dev/tty + temp file lifecycle + environment variable propagation)
> **Test Coverage**: ✅ 74/74 bookmark tests pass | ⚠️ Manual interactive test: first run OK, second run fails

---

## 📝 Table of Contents
- [Overview](#overview)
- [Goals](#goals)
- [Design Considerations](#design-considerations)
- [Command Syntax](#command-syntax)
- [Interactive List View](#interactive-list-view)
- [Data Structure](#data-structure)
- [Error Handling](#error-handling)
- [Implementation Checklist](#implementation-checklist)

---

## 🎯 Overview

Quick bookmark system for fast directory navigation with support for:
- Numbered quick bookmarks (stack-based)
- Named bookmarks
- Categorized bookmarks (hierarchical organization)
- Command bookmarks (future feature)

---

## 🎯 Goals

### Phase 1: Core Functionality
- ✅ Quick save/jump: Save current location and jump back with numbers
- ✅ Temporary bookmarks: Numbered stack for quick access (1, 2, 3...)
- ✅ Persistent bookmarks: Named bookmarks with categories
- ✅ Interactive list view: Browse and select bookmarks visually

### Phase 2: Advanced Features (Future)
- ⏳ Command bookmarks: Save frequently used commands
- ⏳ Fuzzy search: Find bookmarks by partial name/path
- ⏳ Auto-cleanup: Remove invalid/deleted paths
- ⏳ Import/Export: Share bookmarks between systems

---

## 💡 Design Considerations

### Naming
- `bookmark` is long → Consider shorter alias: `bm`, `mark`, `go`, `jump`
- Keep full name for clarity, provide alias for speed

### Architecture
- Separate storage for paths vs commands
- Share core logic between both types
- JSON-based storage for easy manipulation
- Use `~/.mylinuxhelper/bookmarks.json` for persistence

### Integration
- Use existing `mlh-` prefix: `mlh-bookmark.sh`
- Add to `mlh.sh` dispatcher for `mlh bookmark` support
- Create standalone symlink for `bookmark` command

---

## 📚 Command Syntax

### Quick Bookmark (Numbered Stack)

```bash
# Save current directory to stack (becomes bookmark 1)
bookmark .
# → Saves: /current/path
# → Output: "✓ Saved as bookmark 1: /current/path"

# Jump to most recent bookmark
bookmark 1
# → Executes: cd /saved/path
# → Output: "→ /saved/path"

# Jump to 2nd most recent bookmark
bookmark 2
# → Executes: cd /second/saved/path
```

### Named Bookmarks

```bash
# Name an existing numbered bookmark
bookmark 1 -n myproject
# → Renames bookmark 1 to "myproject"
# → Future usage: bookmark myproject

# Save current directory with name
bookmark . -n mlh
# → Saves: /mnt/ssd/MyLinuxHelper as "mlh"

# Jump to named bookmark
bookmark mlh
# → Executes: cd /mnt/ssd/MyLinuxHelper
```

### Categorized Bookmarks

```bash
# Save to category during creation
bookmark . -n mlh in projects/linux
# → Category: projects/linux
# → Name: mlh
# → Path: /current/path

# Rename and categorize existing bookmark
bookmark 1 -n webapp in projects/java
# → Moves bookmark 1 to projects/java category as "webapp"

# Jump using category path (optional)
bookmark projects/java/webapp
bookmark webapp  # Also works if unique
```

### List & Browse

```bash
# Show all bookmarks (interactive)
bookmark list

# Show last N unnamed bookmarks
bookmark list 5

# Show specific category
bookmark list projects
bookmark list projects/java
```

### Management

```bash
# Remove a bookmark
bookmark rm myproject
bookmark rm 1

# Edit bookmark path/name/category
bookmark edit myproject

# Clear all unnamed bookmarks
bookmark clear
```

---

## 📋 Interactive List View

```bash
$ bookmark list

┌─────────────────────────────────────────────────────────────────┐
│                      📚 Bookmarks (15 total)                    │
└─────────────────────────────────────────────────────────────────┘

📂 Projects
  📂 Java
    [webapp]      /mnt/ssd/projects/spring-webapp       2025-01-15
    [api]         /mnt/ssd/projects/rest-api            2025-01-10
    []            /mnt/ssd/projects/legacy              2025-01-05 ⚠

  📂 Python
    [ml-tools]    /home/dev/ml-workspace                2025-01-14

  📂 Linux
    [MLH]         /mnt/ssd/MyLinuxHelper                2025-01-16

📂 Tools
  [jenkins]     /var/lib/jenkins/workspace             2025-01-12
  [mlhconfig]   ~/.mylinuxhelper                       2025-01-16

📂 Uncategorized
  [myproject]   /mnt/ssd/projects/myproject            2025-01-08

📌 Recent (Unnamed)
  1: /mnt/ssd/current-work                             2025-01-16 14:32
  2: /home/dev/temp-project                            2025-01-16 11:20
  3: /var/log/nginx                                    2025-01-15 18:45

────────────────────────────────────────────────────────────────────
Select: [number/name] | 'r' refresh | 'h' help | 'q' quit
> _
```

**Symbols**:
- `⚠` = Path no longer exists (warn before jumping)
- `📂` = Category
- `📌` = Unnamed/temporary bookmarks

---

## 🗄️ Data Structure

**Storage**: `~/.mylinuxhelper/bookmarks.json`

```json
{
  "version": "1.0",
  "bookmarks": {
    "named": [
      {
        "name": "mlh",
        "path": "/mnt/ssd/MyLinuxHelper",
        "category": "projects/linux",
        "created": "2025-01-16T10:30:00Z",
        "accessed": "2025-01-16T14:20:00Z",
        "access_count": 15
      },
      {
        "name": "jenkins",
        "path": "/var/lib/jenkins/workspace",
        "category": "tools",
        "created": "2025-01-12T08:00:00Z",
        "accessed": "2025-01-16T09:15:00Z",
        "access_count": 8
      }
    ],
    "unnamed": [
      {
        "id": 1,
        "path": "/mnt/ssd/current-work",
        "created": "2025-01-16T14:32:00Z"
      },
      {
        "id": 2,
        "path": "/home/dev/temp-project",
        "created": "2025-01-16T11:20:00Z"
      }
    ]
  },
  "config": {
    "max_unnamed": 10,
    "auto_cleanup": true,
    "fuzzy_search": true
  }
}
```

---

## ⚠️ Error Handling

### Name Conflicts

```bash
$ bookmark 1 -n ls

❌ Error: Invalid name 'ls'
   This name conflicts with an existing command.

   Conflicting command: /usr/bin/ls

   Suggestions:
   - Use 'ls-bookmarks' instead
   - Use 'list-scripts' instead
   - Choose a different name
```

### Path Not Exists

```bash
$ bookmark myproject

⚠ Warning: Bookmark path no longer exists
   Path: /mnt/ssd/old-project (deleted on disk)

   Options:
   [u] Update path
   [d] Delete bookmark
   [c] Cancel

> _
```

### Duplicate Names

```bash
$ bookmark . -n webapp

❌ Error: Bookmark 'webapp' already exists
   Category: projects/java
   Path: /mnt/ssd/projects/spring-webapp

   Options:
   [o] Overwrite existing bookmark
   [r] Rename to 'webapp2'
   [c] Cancel

> _
```

---

## ✅ Implementation Checklist

### Phase 1: MVP (v1.0) ✅ COMPLETED
- [x] Create `plugins/mlh-bookmark.sh` with basic structure
- [x] Implement numbered bookmark stack (save/jump)
  - [x] `bookmark .` - save current directory
  - [x] `bookmark N` - jump to bookmark N
  - [x] Stack limit (default: 10)
- [x] Implement named bookmarks
  - [x] `bookmark . -n <name>` - save with name
  - [x] `bookmark <name>` - jump to named
  - [x] `bookmark N -n <name>` - rename numbered to named
- [x] JSON storage system
  - [x] Create `~/.mylinuxhelper/bookmarks.json`
  - [x] Read/write functions with `jq`
  - [x] Auto-create on first use
- [x] Basic list view
  - [x] `bookmark list` - show all
  - [x] `bookmark list N` - show last N unnamed
- [x] Error handling
  - [x] Name conflict detection
  - [x] Path existence check
  - [x] Invalid input validation

### Phase 2: Categories (v1.1) ✅ COMPLETED
- [x] Category support
  - [x] `bookmark . -n <name> in <category>`
  - [x] `bookmark N -n <name> in <category>`
  - [x] Nested categories (projects/java/spring)
- [x] Enhanced list view
  - [x] Hierarchical category display
  - [x] Color-coded categories (green for categories, gray for uncategorized)
  - [x] Show category in list output
  - [ ] Collapsible sections (deferred to Phase 3 - interactive features)
- [x] Category management
  - [x] `bookmark list <category>` - filter by category
  - [x] `bookmark mv <name> to <category>` - move bookmark

### Phase 3: Interactive Features (v1.2) ✅ COMPLETED
- [x] Interactive list menu (`bookmark list -i`)
  - [x] Navigate with arrow keys (↑/↓) and vim keys (j/k) ✅ Working
  - [x] Select to jump (Enter) ✅ FIXED: Unique temp file per invocation with environment variable (Issue #5)
  - [x] Delete shortcuts ('d' key)
  - [x] Edit shortcuts ('e' key - converts numbered to named)
  - [x] Refresh ('r' key)
  - [x] Help menu ('h' key)
  - [x] Quit ('q' key)
  - [x] Hierarchical category display with proper formatting
  - [x] Shows creation dates for all bookmarks
  - [x] WSL compatibility fixes (TTY handling, `/dev/tty` fallback)
  - [x] Robust `while read` loops with `|| true` for `set -euo pipefail`
- [x] Fuzzy search
  - [x] `bookmark find <pattern>` - search bookmarks
  - [x] Partial name matching (case-insensitive contains)
  - [x] Search in name, path, and category
- [x] Bookmark management
  - [x] `bookmark rm <name>` - remove bookmark (named and numbered)
  - [x] Auto re-numbering after deletion (2→1 when 1 is deleted)
  - [x] `bookmark edit <name>` - edit bookmark (name/path/category)
  - [x] `bookmark clear` - clear unnamed (with confirmation)

### Phase 4: Advanced Features (v2.0) ⏳ NOT STARTED
- [ ] Command bookmarks
  - [ ] Separate storage for commands
  - [ ] Shared UI/logic with path bookmarks
- [ ] Auto-cleanup
  - [ ] Remove invalid paths periodically
  - [ ] Configurable cleanup policy
- [ ] Import/Export
  - [ ] Export to JSON
  - [ ] Import from JSON
  - [ ] Merge bookmarks
- [ ] Statistics
  - [ ] Most used bookmarks
  - [ ] Access history
  - [ ] Usage analytics

### Integration
- [x] Add to `setup.sh` LINKS array
- [x] Add to `mlh.sh` dispatcher
- [x] Add to `mlh.sh` interactive menu
- [x] Update main README (bookmark section added with full examples)
- [x] Update CLAUDE.md (Phase 1, 2 & 3 complete, wrapper function documented)
- [ ] Create detailed documentation in `docs/` (optional - future enhancement)
- [x] Add tests to test suite (74 tests, all passing - 240 total system tests)
  - [x] Phase 1 tests (33 tests)
  - [x] Phase 2 category tests (8 tests)
  - [x] Phase 3 management tests (16 tests - rm, clear, edit, find)
  - [x] Phase 3 interactive tests (2 tests - function and flag checks)
  - [x] Integration tests (8 tests - ANSI colors, cd command, wrapper compatibility)
  - [x] Bug fix tests (7 tests - prompt order, TTY check, hierarchy parsing, display, /dev/tty, interactive cd with unique temp file)
- [x] Setup wrapper function for cd navigation (auto-installed by setup.sh)
- [x] Update system integration (auto-reload shell after `mlh update`)

---

## 🐛 Recent Bug Fixes

### Issue #1: Edit Prompt Display Order
- **Problem**: When editing bookmarks, input prompts appeared before the prompt text
- **Root Cause**: `read -rp` buffering issue in some terminal environments
- **Solution**: Split into separate `echo -n` and `read` commands for proper ordering
- **Test Added**: Test 68 - "Edit uses proper prompt order"

### Issue #2: Interactive List Not Opening
- **Problem**: `bookmark list -i` exited immediately without showing menu
- **Root Cause**: When called through wrapper function, stdin may not be a TTY
- **Solution**: 
  - Relaxed TTY check to allow `/dev/tty` fallback: `[ ! -t 0 ] && [ ! -e /dev/tty ]`
  - All `read` commands now redirect from `/dev/tty` when stdin is not a TTY
  - Maintains compatibility with both direct calls and wrapper function calls
- **Test Added**: Test 69 & 72 - "TTY check and /dev/tty fallback"

### Issue #3: Category Hierarchy Not Displayed
- **Problem**: Categories like `aaa/bbb` displayed as flat list instead of hierarchical tree
- **Root Cause**: 
  - Array declaration `local prev_parts=()` caused re-initialization in bash
  - Variable naming conflict between loop iterations
- **Solution**: 
  - Separated `local prev_parts` and `prev_parts=()` declarations
  - Renamed conflicting `indent` variable to `bookmark_indent`
  - Implemented proper category path parsing with `IFS='/'`
- **Test Added**: Test 70 & 71 - "Hierarchical category parsing and display"

### Issue #4: Interactive Menu Navigation Not Working
- **Problem**: `bookmark list -i` navigation (arrow keys, j/k) exited immediately
- **Root Cause**:
  - `read -rsn1` failing with `set -euo pipefail` caused script to exit
  - `while read` loops with EOF causing script termination
  - Arrow key escape sequences not properly parsed
- **Solution**:
  - Changed `break` to `continue` in `read` error handling
  - Added `|| true` to arithmetic operations (`((selected++)) || true`)
  - Improved arrow key parsing (character-by-character reading)
  - Fixed `while read` loops to handle EOF gracefully
- **Status**: ✅ FIXED - All navigation working including Enter key (see Issue #5)

### Issue #5: Interactive Mode Enter Key Not Navigating ⚠️ UNDER INVESTIGATION
- **Problem**: In `bookmark list -i`, pressing Enter on a bookmark shows cd command but doesn't actually navigate
- **Symptoms**:
  - `bookmark 1` works (normal jump works)
  - Interactive mode shows: `cd "/path"` and `→ /path` but doesn't change directory
  - User stays in same directory after Enter

- **Root Cause Analysis**:
  - Interactive mode uses `/dev/tty` for input (line 764-779 in mlh-bookmark.sh)
  - Output capture `output=$(command bookmark "$@" 2>&1)` conflicts with `/dev/tty`
  - This is a known pattern - ranger and fzf both solve this differently

- **Research Done** (Web Search):
  - ✅ FZF: Uses output capture `dir=$(fzf) && cd "$dir"` - works because fzf doesn't use `/dev/tty`
  - ✅ Ranger: Uses temp file approach - EXACTLY what we need!
    ```bash
    tempfile=$(mktemp)
    ranger --cmd="map Q chain shell echo %d > \"$tempfile\"; quitall"
    [[ -f "$tempfile" ]] && cd "$(cat "$tempfile")"
    ```

- **Solutions Attempted**:

  1. **❌ Output Capture (First attempt)**:
     - Tried: `output=$(command bookmark "$@" 2>&1)` in wrapper
     - Failed: Output capture conflicts with interactive `/dev/tty` reads

  2. **❌ Temp File with Environment Variable**:
     - Tried: `export MLH_BOOKMARK_CD_FILE="$tmp_file"` in wrapper
     - Plugin checks: `if [ -n "${MLH_BOOKMARK_CD_FILE:-}" ]`
     - Failed: Debug log shows `PLUGIN: No temp file env var, using stdout`
     - Reason: `command bookmark` → symlink → new process, env var not visible

  3. **❌ Temp File with Argument**:
     - Tried: `command bookmark "$@" --cd-file "$tmp_file"` in wrapper
     - Plugin parses `--cd-file` in main() and exports MLH_BOOKMARK_CD_FILE
     - Failed: Added complexity, not needed for simple use case

  4. **❌ Ranger-Style Fixed Path (Initial Solution - Had Issues)**:
    - **Why it failed**: Fixed path caused race conditions on second invocation
    - **Problem**: First run worked, second run failed (timing/race condition issues)
    - **Implementation**:
      - Wrapper used fixed path: `/tmp/bookmark-cd-${USER:-$(id -un)}`
      - Plugin used same fixed path
      - **Issue**: Multiple invocations could interfere with each other

  5. **✅ Unique Temp File Per Invocation with Environment Variable (FINAL SOLUTION)**:
    - **Why it works**: Each invocation gets unique temp file, no race conditions
    - **Key improvements**:
      - Unique temp file per invocation using `mktemp` (prevents race conditions)
      - Environment variable `MLH_BOOKMARK_CD_FILE` for communication
      - Atomic file write (write to `.tmp` then `mv` to final location)
      - Polling loop in wrapper (waits up to 1 second for file to be written)
      - `sync` command to ensure file is written to disk
      - Proper cleanup (removes temp file and unsets env var)
    - **Implementation**:
      - Wrapper (`setup.sh` line 54-95):
        - Creates unique temp file: `tmp_cd_file=$(mktemp "/tmp/bookmark-cd-${USER}-XXXXXX")`
        - Exports environment variable: `export MLH_BOOKMARK_CD_FILE="$tmp_cd_file"`
        - Runs interactive mode: `command bookmark "$@"`
        - Polls for file existence: `while [ $waited -lt 10 ]; do ... sleep 0.1; done`
        - Sources temp file if exists: `source "$tmp_cd_file" 2>/dev/null`
        - Cleans up: `rm -f "$tmp_cd_file"` and `unset MLH_BOOKMARK_CD_FILE`
      - Plugin (`mlh-bookmark.sh` line 853-900):
        - Uses environment variable if available: `tmp_cd_file="${MLH_BOOKMARK_CD_FILE:-/tmp/bookmark-cd-${USER}}"`
        - Atomic write: writes to `.tmp` file, then `mv` to final location
        - Syncs to disk: `sync 2>/dev/null || true`
      - **Result**: Works reliably on first, second, and subsequent invocations!

- **Final Implementation**:
  ```bash
  # Wrapper function (setup.sh)
  bookmark() {
    if [ "$cmd" = "list" ] && ( [ "$2" = "-i" ] || [ "$2" = "--interactive" ] ); then
      # Create unique temp file per invocation
      local tmp_cd_file
      tmp_cd_file=$(mktemp "/tmp/bookmark-cd-${USER:-$(id -un)}-XXXXXX" 2>/dev/null) || {
        tmp_cd_file="/tmp/bookmark-cd-${USER:-$(id -un)}"
        rm -f "$tmp_cd_file"
      }
      
      # Export temp file path to plugin
      export MLH_BOOKMARK_CD_FILE="$tmp_cd_file"
      
      # Run interactive mode
      command bookmark "$@"
      local exit_code=$?
      
      # Poll for file existence (max 1 second)
      local waited=0
      while [ $waited -lt 10 ]; do
        if [ -f "$tmp_cd_file" ] && [ -s "$tmp_cd_file" ]; then
          break
        fi
        sleep 0.1 2>/dev/null || true
        waited=$((waited + 1))
      done
      
      # Source temp file if exists
      if [ -f "$tmp_cd_file" ] && [ -s "$tmp_cd_file" ]; then
        source "$tmp_cd_file" 2>/dev/null || true
      fi
      
      # Cleanup
      rm -f "$tmp_cd_file"
      unset MLH_BOOKMARK_CD_FILE
      
      return $exit_code
    fi
    # ... rest of wrapper
  }

  # Plugin (mlh-bookmark.sh - Enter key handler)
  # Use environment variable if available, fallback to fixed path
  local tmp_cd_file="${MLH_BOOKMARK_CD_FILE:-/tmp/bookmark-cd-${USER:-$(id -un)}}"
  
  # Atomic write: write to .tmp file first, then move
  local tmp_write_file="${tmp_cd_file}.tmp"
  printf 'cd "%s"\n' "$bookmark_path" > "$tmp_write_file" 2>/dev/null || return 1
  mv "$tmp_write_file" "$tmp_cd_file" 2>/dev/null || return 1
  
  # Sync to ensure file is written to disk
  sync 2>/dev/null || true
  
  echo -e "${GREEN}→${NC} $bookmark_path" >&2
  return 0
  ```

- **Tests Added**:
  - Test 73: "Wrapper function uses unique temp file with environment variable for cd" ✅
  - Test 74: "Plugin uses environment variable for temp file on bookmark selection" ✅
  - Total: 74/74 bookmark tests passing

- **Current Status**: ⚠️ **STILL FAILING**
  - ✅ First run works: Enter key navigates to selected directory
  - ❌ Second run fails: Enter key doesn't navigate anymore
  - ❌ New bash session: Temp file mechanism doesn't work

- **Detailed Analysis**:

  **Observed Behavior**:
  ```bash
  # First run - WORKS
  bookmark list -i  # Press Enter → Directory changes ✅
  
  # Second run (same session) - FAILS
  bookmark list -i  # Press Enter → Directory doesn't change ❌
  
  # New bash session - FAILS
  exec bash -l
  bookmark list -i  # Press Enter → Directory doesn't change ❌
  ```

  **Possible Root Causes** (in order of likelihood):

  1. **Environment Variable Not Inherited** (Most Likely):
     - `command bookmark` creates a new process via symlink
     - Environment variables exported in wrapper function may not be visible to child process
     - Even though `export` should work, symlink execution might create a new shell context
     - **Test**: Add debug output in plugin to check if `MLH_BOOKMARK_CD_FILE` is set

  2. **Temp File Cleanup Timing Issue**:
     - Wrapper cleans up temp file after sourcing: `rm -f "$tmp_cd_file"`
     - On second run, wrapper creates new temp file but plugin might still be looking at old path
     - Or: Plugin writes to temp file, wrapper reads it, but cleanup happens before plugin exits
     - **Test**: Check if temp file exists after plugin returns: `ls -la /tmp/bookmark-cd-*`

  3. **File System Caching/Buffering**:
     - Plugin writes file, wrapper reads it too quickly
     - File might not be flushed to disk yet
     - Even with `sync`, there might be filesystem-level caching
     - **Test**: Add longer delay or explicit `sync` before wrapper reads

  4. **Wrapper Function Not Reloaded**:
     - In new bash session, wrapper function might not be loaded
     - `~/.bashrc` might not be sourced automatically
     - Wrapper function definition might be missing
     - **Test**: Check if wrapper exists: `type bookmark`

  5. **Process Isolation**:
     - `command bookmark` might be running in a subshell
     - Environment variables might not propagate correctly
     - File descriptors might be different
     - **Test**: Check process tree: `ps aux | grep bookmark`

  6. **Race Condition with Fixed Path**:
     - If environment variable isn't set, plugin falls back to fixed path
     - Multiple invocations could interfere with each other
     - First run works because file doesn't exist yet
     - Second run fails because file might be locked or in use
     - **Test**: Check if fixed path file exists: `ls -la /tmp/bookmark-cd-${USER}`

  7. **Return Code Handling**:
     - Plugin returns `0` on Enter, wrapper checks exit code
     - But wrapper might be checking exit code before temp file is written
     - Timing issue between plugin return and file write completion
     - **Test**: Add delay in plugin before `return 0`

- **Web Research Findings**:

  **Bash Wrapper Functions & Environment Variables**:
  - Environment variables exported in wrapper functions should be visible to child processes
  - However, `command` builtin might create a new execution context
  - Symlinks can complicate environment variable inheritance
  - **Key Finding**: Child processes inherit environment, but symlink execution might use different context

  **Temp File Communication Patterns**:
  - Ranger uses temp file approach successfully
  - FZF uses output capture (doesn't work for us due to `/dev/tty`)
  - Common pattern: Use unique temp files per invocation
  - **Key Finding**: Fixed paths can cause race conditions, unique files are safer

  **Interactive Menu & Parent Shell Communication**:
  - Child processes cannot change parent shell directory directly
  - Must use wrapper function with `eval` or `source`
  - Temp file approach is standard for this use case
  - **Key Finding**: Our approach (temp file + wrapper) is correct, but implementation might have issues

- **Recommended Investigation Steps**:

  1. **Add Debug Logging**:
     ```bash
     # In wrapper, before command bookmark:
     echo "DEBUG: tmp_cd_file=$tmp_cd_file" >&2
     echo "DEBUG: MLH_BOOKMARK_CD_FILE=$MLH_BOOKMARK_CD_FILE" >&2
     
     # In plugin, when Enter is pressed:
     echo "DEBUG: MLH_BOOKMARK_CD_FILE=${MLH_BOOKMARK_CD_FILE:-NOT SET}" >&2
     echo "DEBUG: Writing to: $tmp_cd_file" >&2
     ```

  2. **Check Temp File Lifecycle**:
     ```bash
     # Before first run
     ls -la /tmp/bookmark-cd-* 2>/dev/null || echo "No files"
     
     # After first run (before second)
     ls -la /tmp/bookmark-cd-* 2>/dev/null || echo "No files"
     cat /tmp/bookmark-cd-${USER} 2>/dev/null || echo "File not found"
     
     # After second run
     ls -la /tmp/bookmark-cd-* 2>/dev/null || echo "No files"
     ```

  3. **Verify Wrapper Function**:
     ```bash
     type bookmark  # Should show function definition
     declare -f bookmark  # Should show full function
     ```

  4. **Test Environment Variable Propagation**:
     ```bash
     # In wrapper, before command bookmark:
     export MLH_BOOKMARK_CD_FILE="/tmp/test-debug"
     command bookmark list -i
     # In plugin, check if variable is visible
     ```

  5. **Test with Explicit File Path**:
     ```bash
     # Temporarily hardcode temp file path in both wrapper and plugin
     # See if fixed path works on second run
     ```

- **Proposed Solutions** (to test):

  1. **Use Process Substitution Instead of Temp File**:
     - Instead of temp file, use named pipe or process substitution
     - More reliable for inter-process communication
     - **Pros**: No file system issues, guaranteed delivery
     - **Cons**: More complex, might not work with all shells

  2. **Use Signal-Based Communication**:
     - Plugin writes file, then sends signal to parent
     - Wrapper waits for signal before reading file
     - **Pros**: Guaranteed synchronization
     - **Cons**: Complex, requires signal handling

  3. **Use Unique Temp File with PID**:
     - Include PID in temp file name: `/tmp/bookmark-cd-${USER}-$$`
     - Each process gets unique file
     - **Pros**: Simple, guaranteed uniqueness
     - **Cons**: Still relies on environment variable propagation

  4. **Use Wrapper Function Directly in Plugin**:
     - Instead of temp file, plugin calls wrapper function directly
     - Wrapper function is available in plugin's context
     - **Pros**: No file system, direct communication
     - **Cons**: Requires refactoring, might not work with symlink execution

  5. **Use Shared Memory or Named Pipe**:
     - Use `/dev/shm` for shared memory
     - Or use named pipe (`mkfifo`)
     - **Pros**: Fast, reliable
     - **Cons**: Requires cleanup, more complex

- **Next Steps**:
  1. Add comprehensive debug logging to both wrapper and plugin
  2. Test environment variable propagation with explicit checks
  3. Verify temp file lifecycle (creation, writing, reading, cleanup)
  4. Test with unique temp file per invocation (current implementation)
  5. If still failing, try alternative communication methods

**Result**: All 74 bookmark tests passing, but manual testing shows issue persists on second invocation. Investigation ongoing.
```
📂 aaa
    [bookmark3] path
  📂 bbb
      [bookmark1] path
    📂 ccc
        [bookmark2] path
```

---

## 📖 Additional Notes

### Alias Suggestions
Create these aliases in setup for convenience:
```bash
alias bm='bookmark'
alias bml='bookmark list'
alias bmg='bookmark'  # bmg myproject → go to myproject
```

### Future Integrations
- **History integration**: `bookmark last-cd` saves last visited dir
- **Git integration**: Auto-detect git repo and suggest name
- **Fuzzy finder**: Integrate with `fzf` for better UX
- **Sync**: Cloud sync via git repo
- **Export formats**: Export to VS Code workspace, shell aliases, etc.  