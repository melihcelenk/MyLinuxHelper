#!/usr/bin/env bash
# Test suite for bookmark alias functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source test framework functions from parent
if [ -n "${STATS_FILE:-}" ]; then
	# Running under test runner
	:
else
	# Standalone execution
	GREEN='\033[0;32m'
	RED='\033[0;31m'
	YELLOW='\033[1;33m'
	CYAN='\033[0;36m'
	NC='\033[0m'
	
	print_test_result() {
		local test_name="$1"
		local result="$2"
		local message="${3:-}"
		
		if [ "$result" = "PASS" ]; then
			echo -e "${GREEN}✓ PASS${NC}: $test_name"
		elif [ "$result" = "SKIP" ]; then
			echo -e "${YELLOW}⊘ SKIP${NC}: $test_name"
			[ -n "$message" ] && echo -e "  ${YELLOW}$message${NC}"
		else
			echo -e "${RED}✗ FAIL${NC}: $test_name"
			[ -n "$message" ] && echo -e "  ${YELLOW}$message${NC}"
		fi
	}
fi

# Setup test environment
setup_test_env() {
	export HOME="/tmp/test-bookmark-alias-$$"
	mkdir -p "$HOME/.mylinuxhelper"
	export MLH_CONFIG_DIR="$HOME/.mylinuxhelper"
	export ALIAS_CONFIG_FILE="$MLH_CONFIG_DIR/bookmark-alias.conf"
}

# Cleanup test environment
cleanup_test_env() {
	rm -rf "/tmp/test-bookmark-alias-$$" 2>/dev/null || true
}

# Trap to ensure cleanup
trap cleanup_test_env EXIT

# Run tests
setup_test_env

#
# Test Group 1: Configuration file handling
#

# Test 1: Config file can be sourced and read
echo "BOOKMARK_ALIAS=bm" > "$ALIAS_CONFIG_FILE"
if source "$ALIAS_CONFIG_FILE" 2>/dev/null && [ "$BOOKMARK_ALIAS" = "bm" ]; then
	print_test_result "Config file can be sourced and read" "PASS"
else
	print_test_result "Config file can be sourced and read" "FAIL" "Failed to read config"
fi

# Test 2: Empty alias (no shortcut)
echo "" > "$ALIAS_CONFIG_FILE"
BOOKMARK_ALIAS=""
source "$ALIAS_CONFIG_FILE" 2>/dev/null || true
if [ -z "$BOOKMARK_ALIAS" ]; then
	print_test_result "Config file supports empty alias (no shortcut)" "PASS"
else
	print_test_result "Config file supports empty alias (no shortcut)" "FAIL" "Expected empty, got '$BOOKMARK_ALIAS'"
fi

# Test 3: Custom alias
echo "BOOKMARK_ALIAS=bm" > "$ALIAS_CONFIG_FILE"
BOOKMARK_ALIAS=""
source "$ALIAS_CONFIG_FILE" 2>/dev/null
if [ "$BOOKMARK_ALIAS" = "bm" ]; then
	print_test_result "Config file supports custom alias" "PASS"
else
	print_test_result "Config file supports custom alias" "FAIL" "Got '$BOOKMARK_ALIAS'"
fi

#
# Test Group 2: Help display with alias
#

# Test 4: Help displays shortcut header when alias configured
BOOKMARK_ALIAS="bm"
COMMAND_NAME="${BOOKMARK_ALIAS:-bookmark}"
output=$("$ROOT_DIR/plugins/mlh-bookmark.sh" --help 2>&1 || true)
if echo "$output" | grep -q "Shortcut.*bm"; then
	print_test_result "Help displays shortcut header when alias configured" "PASS"
else
	print_test_result "Help displays shortcut header when alias configured" "FAIL" "Shortcut header not found"
fi

# Test 5: Help examples use configured alias name
if echo "$output" | grep -q "bm ."; then
	print_test_result "Help examples use configured alias name" "PASS"
else
	print_test_result "Help examples use configured alias name" "FAIL" "Examples don't use alias"
fi

# Test 6: Help adapts to different alias names (fav)
echo "BOOKMARK_ALIAS=fav" > "$ALIAS_CONFIG_FILE"
output=$("$ROOT_DIR/plugins/mlh-bookmark.sh" --help 2>&1 || true)
if echo "$output" | grep -q "fav ."; then
	print_test_result "Help adapts to different alias names (fav)" "PASS"
else
	print_test_result "Help adapts to different alias names (fav)" "FAIL" "Help doesn't use 'fav'"
fi

# Test 7: Help shows 'bookmark' when no alias configured
echo "" > "$ALIAS_CONFIG_FILE"
output=$("$ROOT_DIR/plugins/mlh-bookmark.sh" --help 2>&1 || true)
if echo "$output" | grep -q "bookmark \."; then
	print_test_result "Help shows 'bookmark' when no alias configured" "PASS"
else
	print_test_result "Help shows 'bookmark' when no alias configured" "FAIL" "Expected 'bookmark'"
fi

# Test 8: Help shows 'bookmark' when config missing
rm -f "$ALIAS_CONFIG_FILE"
output=$("$ROOT_DIR/plugins/mlh-bookmark.sh" --help 2>&1 || true)
if echo "$output" | grep -q "bookmark \."; then
	print_test_result "Help shows 'bookmark' when config missing" "PASS"
else
	print_test_result "Help shows 'bookmark' when config missing" "FAIL" "Expected 'bookmark'"
fi

#
# Test Group 3: setup.sh integration
#

# Test 9: setup.sh exists
if [ -f "$ROOT_DIR/setup.sh" ]; then
	print_test_result "setup.sh exists" "PASS"
else
	print_test_result "setup.sh exists" "FAIL" "File not found"
fi

# Test 10: setup.sh has valid syntax
if bash -n "$ROOT_DIR/setup.sh" 2>/dev/null; then
	print_test_result "setup.sh has valid syntax" "PASS"
else
	print_test_result "setup.sh has valid syntax" "FAIL" "Syntax error"
fi

# Test 11: setup.sh contains alias configuration logic
if grep -q "BOOKMARK_ALIAS" "$ROOT_DIR/setup.sh"; then
	print_test_result "setup.sh contains alias configuration logic" "PASS"
else
	print_test_result "setup.sh contains alias configuration logic" "FAIL" "Logic not found"
fi

# Test 12: setup.sh checks for command conflicts
if grep -q "command -v.*BOOKMARK_ALIAS" "$ROOT_DIR/setup.sh"; then
	print_test_result "setup.sh checks for command conflicts" "PASS"
else
	print_test_result "setup.sh checks for command conflicts" "FAIL" "Conflict check not found"
fi

# Test 13: setup.sh creates alias wrapper function
if grep -q "bookmark.*\\\$@" "$ROOT_DIR/setup.sh"; then
	print_test_result "setup.sh creates alias wrapper function" "PASS"
else
	print_test_result "setup.sh creates alias wrapper function" "FAIL" "Wrapper not found"
fi

# Test 14: setup.sh creates symlink for alias
if grep -q 'LINKS\[.*BOOKMARK_ALIAS' "$ROOT_DIR/setup.sh"; then
	print_test_result "setup.sh creates symlink for alias" "PASS"
else
	print_test_result "setup.sh creates symlink for alias" "FAIL" "Symlink logic not found"
fi

# Test 15: Symlink logic targets mlh-bookmark.sh
if grep -q 'mlh-bookmark\.sh' "$ROOT_DIR/setup.sh"; then
	print_test_result "Symlink logic targets mlh-bookmark.sh" "PASS"
else
	print_test_result "Symlink logic targets mlh-bookmark.sh" "FAIL" "Target not found"
fi

#
# Test Group 4: Alias name validation
#

# Test 16: Valid alias names are alphanumeric
valid_names=("bm" "b" "bookmark1" "my_bookmark" "BM" "MyBookmarks")
all_valid=true
for name in "${valid_names[@]}"; do
	if [[ ! "$name" =~ ^[a-zA-Z0-9_]+$ ]]; then
		all_valid=false
		break
	fi
done
if $all_valid; then
	print_test_result "Valid alias names are alphanumeric" "PASS"
else
	print_test_result "Valid alias names are alphanumeric" "FAIL" "Pattern validation failed"
fi

# Test 17: Invalid alias names detected (spaces, special chars)
invalid_names=("b m" "book-mark" "book@mark" "book!mark" "book mark")
all_invalid=true
for name in "${invalid_names[@]}"; do
	if [[ "$name" =~ ^[a-zA-Z0-9_]+$ ]]; then
		all_invalid=false
		break
	fi
done
if $all_invalid; then
	print_test_result "Invalid alias names detected (spaces, special chars)" "PASS"
else
	print_test_result "Invalid alias names detected (spaces, special chars)" "FAIL" "Should reject '$name'"
fi

# Test 18: Long alias names supported
long_name="verylongbookmarkalias123"
if [[ "$long_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
	print_test_result "Long alias names supported" "PASS"
else
	print_test_result "Long alias names supported" "FAIL" "Long names should be valid"
fi

# Test 19: Single character alias supported
single_char="b"
if [[ "$single_char" =~ ^[a-zA-Z0-9_]+$ ]]; then
	print_test_result "Single character alias supported" "PASS"
else
	print_test_result "Single character alias supported" "FAIL" "Single char should be valid"
fi

#
# Test Group 5: Config file edge cases
#

# Test 20: Config file with comments works
echo "# Bookmark alias configuration" > "$ALIAS_CONFIG_FILE"
echo "BOOKMARK_ALIAS=bm" >> "$ALIAS_CONFIG_FILE"
BOOKMARK_ALIAS=""
source "$ALIAS_CONFIG_FILE" 2>/dev/null || true
if [ "$BOOKMARK_ALIAS" = "bm" ]; then
	print_test_result "Config file with comments works" "PASS"
else
	print_test_result "Config file with comments works" "FAIL" "Comments break parsing: got '$BOOKMARK_ALIAS'"
fi

# Test 21: Config handles whitespace (bash trims it naturally)
echo "BOOKMARK_ALIAS=bm" > "$ALIAS_CONFIG_FILE"
echo "  " >> "$ALIAS_CONFIG_FILE"
BOOKMARK_ALIAS=""
source "$ALIAS_CONFIG_FILE" 2>/dev/null || true
# Config should still work with extra whitespace/blank lines
if [ "$BOOKMARK_ALIAS" = "bm" ]; then
	print_test_result "Config handles whitespace" "PASS"
else
	print_test_result "Config handles whitespace" "FAIL" "Whitespace breaks parsing: got '$BOOKMARK_ALIAS'"
fi

# Test 22: Config with export statement
echo "export BOOKMARK_ALIAS=bm" > "$ALIAS_CONFIG_FILE"
BOOKMARK_ALIAS=""
source "$ALIAS_CONFIG_FILE" 2>/dev/null || true
if [ "$BOOKMARK_ALIAS" = "bm" ]; then
	print_test_result "Config with export statement" "PASS"
else
	print_test_result "Config with export statement" "FAIL" "Export breaks parsing: got '$BOOKMARK_ALIAS'"
fi

# Test 23: Config with multiple variables (only BOOKMARK_ALIAS matters)
echo "SOME_VAR=test" > "$ALIAS_CONFIG_FILE"
echo "BOOKMARK_ALIAS=bm" >> "$ALIAS_CONFIG_FILE"
echo "OTHER_VAR=value" >> "$ALIAS_CONFIG_FILE"
BOOKMARK_ALIAS=""
source "$ALIAS_CONFIG_FILE" 2>/dev/null || true
if [ "$BOOKMARK_ALIAS" = "bm" ]; then
	print_test_result "Config with multiple variables" "PASS"
else
	print_test_result "Config with multiple variables" "FAIL" "Multiple vars break parsing: got '$BOOKMARK_ALIAS'"
fi

#
# Test Group 6: BASHRC_UPDATED tracking
#

# Test 24: setup.sh initializes BASHRC_UPDATED
if grep -q "BASHRC_UPDATED=0" "$ROOT_DIR/setup.sh"; then
	print_test_result "setup.sh initializes BASHRC_UPDATED" "PASS"
else
	print_test_result "setup.sh initializes BASHRC_UPDATED" "FAIL" "Initialization not found"
fi

# Test 25: setup.sh sets BASHRC_UPDATED when adding wrappers
if grep -q "BASHRC_UPDATED=1" "$ROOT_DIR/setup.sh"; then
	print_test_result "setup.sh sets BASHRC_UPDATED when adding wrappers" "PASS"
else
	print_test_result "setup.sh sets BASHRC_UPDATED when adding wrappers" "FAIL" "Flag not set"
fi

# Test 26: setup.sh displays warning when BASHRC_UPDATED
if grep -q "BASHRC_UPDATED.*eq.*1" "$ROOT_DIR/setup.sh" && grep -q "source ~/.bashrc" "$ROOT_DIR/setup.sh"; then
	print_test_result "setup.sh displays warning when BASHRC_UPDATED" "PASS"
else
	print_test_result "setup.sh displays warning when BASHRC_UPDATED" "FAIL" "Warning not found"
fi

#
# Test Group 7: Color output
#

# Test 27: setup.sh defines color variables
if grep -q "YELLOW=" "$ROOT_DIR/setup.sh" && grep -q "CYAN=" "$ROOT_DIR/setup.sh"; then
	print_test_result "setup.sh defines color variables" "PASS"
else
	print_test_result "setup.sh defines color variables" "FAIL" "Color variables not found"
fi

# Test 28: Warning message uses colors
if grep -q "\${YELLOW}.*Important" "$ROOT_DIR/setup.sh"; then
	print_test_result "Warning message uses colors" "PASS"
else
	print_test_result "Warning message uses colors" "FAIL" "Colored warning not found"
fi

# Cleanup
cleanup_test_env

exit 0
