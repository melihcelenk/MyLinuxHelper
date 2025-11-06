#!/usr/bin/env bash
# test-mlh-bookmark.sh - Test suite for mlh-bookmark.sh (Phase 1 MVP)

# Disable strict mode for tests
set +euo pipefail 2>/dev/null || true
set +e

PLUGIN_SCRIPT="$ROOT_DIR/plugins/mlh-bookmark.sh"

# Check if jq is available (required for bookmark feature)
JQ_AVAILABLE=0
if command -v jq >/dev/null 2>&1; then
	JQ_AVAILABLE=1
else
	# Try to install jq if not available
	echo "jq not found. Attempting to install..."
	if [ -f "$ROOT_DIR/install.sh" ]; then
		bash "$ROOT_DIR/install.sh" jq >/dev/null 2>&1
		if command -v jq >/dev/null 2>&1; then
			JQ_AVAILABLE=1
			echo "✓ jq installed successfully"
		else
			echo "✗ Failed to install jq automatically"
		fi
	fi
fi

# Setup test environment
TEST_BOOKMARK_DIR=$(mktemp -d)
TEST_BOOKMARK_FILE="$TEST_BOOKMARK_DIR/bookmarks.json"
export MLH_BOOKMARK_FILE="$TEST_BOOKMARK_FILE" # Allow override for testing

# Create test directories for bookmark testing
TEST_DIR_1=$(mktemp -d)
TEST_DIR_2=$(mktemp -d)
TEST_DIR_3=$(mktemp -d)

# Cleanup function
cleanup_bookmark_tests() {
	rm -rf "$TEST_BOOKMARK_DIR" "$TEST_DIR_1" "$TEST_DIR_2" "$TEST_DIR_3" 2>/dev/null || true
}

trap cleanup_bookmark_tests EXIT

# ============================================================================
# BASIC TESTS
# ============================================================================

# Test 1: Script exists
if [ -f "$PLUGIN_SCRIPT" ]; then
	print_test_result "mlh-bookmark.sh exists" "PASS"
else
	print_test_result "mlh-bookmark.sh exists" "FAIL" "File not found at: $PLUGIN_SCRIPT"
fi

# Test 2: Valid bash syntax
if bash -n "$PLUGIN_SCRIPT" 2>/dev/null; then
	print_test_result "mlh-bookmark.sh has valid syntax" "PASS"
else
	print_test_result "mlh-bookmark.sh has valid syntax" "FAIL" "Syntax errors found"
fi

# Test 3: Help text works
if bash "$PLUGIN_SCRIPT" --help >/dev/null 2>&1; then
	print_test_result "bookmark --help works" "PASS"
else
	print_test_result "bookmark --help works" "FAIL" "Help command failed"
fi

# Skip remaining tests if jq is not available
if [ "$JQ_AVAILABLE" -eq 0 ]; then
	print_test_result "Remaining bookmark tests" "SKIP" "jq not installed (required for bookmark feature)"
	exit 0
fi

# ============================================================================
# NUMBERED BOOKMARK STACK TESTS
# ============================================================================

# Test 4: Save current directory as numbered bookmark
cd "$TEST_DIR_1" || exit 1
result=$(bash "$PLUGIN_SCRIPT" . 2>&1)
if echo "$result" | grep -qi "saved\|bookmark 1"; then
	print_test_result "Save current directory as bookmark 1" "PASS"
else
	print_test_result "Save current directory as bookmark 1" "FAIL" "Expected 'saved' or 'bookmark 1' in output"
fi

# Test 5: Bookmark file created
if [ -f "$TEST_BOOKMARK_FILE" ]; then
	print_test_result "Bookmark file created at $TEST_BOOKMARK_FILE" "PASS"
else
	print_test_result "Bookmark file created" "FAIL" "File not found"
fi

# Test 6: Bookmark file is valid JSON
if jq empty "$TEST_BOOKMARK_FILE" 2>/dev/null; then
	print_test_result "Bookmark file is valid JSON" "PASS"
else
	print_test_result "Bookmark file is valid JSON" "FAIL" "Invalid JSON format"
fi

# Test 7: Bookmark file contains correct path
saved_path=$(jq -r '.bookmarks.unnamed[0].path // empty' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$saved_path" = "$TEST_DIR_1" ]; then
	print_test_result "Bookmark contains correct path" "PASS"
else
	print_test_result "Bookmark contains correct path" "FAIL" "Expected: $TEST_DIR_1, Got: $saved_path"
fi

# Test 8: Add second bookmark (stack behavior)
cd "$TEST_DIR_2" || exit 1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1
saved_path=$(jq -r '.bookmarks.unnamed[0].path // empty' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$saved_path" = "$TEST_DIR_2" ]; then
	print_test_result "Second bookmark becomes bookmark 1 (stack)" "PASS"
else
	print_test_result "Second bookmark becomes bookmark 1 (stack)" "FAIL" "Expected: $TEST_DIR_2, Got: $saved_path"
fi

# Test 9: First bookmark becomes bookmark 2
saved_path=$(jq -r '.bookmarks.unnamed[1].path // empty' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$saved_path" = "$TEST_DIR_1" ]; then
	print_test_result "First bookmark becomes bookmark 2" "PASS"
else
	print_test_result "First bookmark becomes bookmark 2" "FAIL" "Expected: $TEST_DIR_1, Got: $saved_path"
fi

# Test 10: Stack limit (max 10 unnamed bookmarks)
for i in {3..12}; do
	bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1
done
count=$(jq '.bookmarks.unnamed | length' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$count" -le 10 ]; then
	print_test_result "Stack limit enforced (max 10)" "PASS"
else
	print_test_result "Stack limit enforced (max 10)" "FAIL" "Expected ≤10, Got: $count"
fi

# Test 11: Jump to bookmark 1 (source test - prints cd command)
# Note: We can't actually test CD in subshell, so we check output format
result=$(bash "$PLUGIN_SCRIPT" 1 2>&1)
if echo "$result" | grep -q "$TEST_DIR_2\|cd"; then
	print_test_result "Jump to bookmark 1 generates correct output" "PASS"
else
	print_test_result "Jump to bookmark 1 generates correct output" "FAIL" "Expected path or cd command"
fi

# Test 12: Jump to non-existent bookmark number
result=$(bash "$PLUGIN_SCRIPT" 99 2>&1)
if echo "$result" | grep -qi "not found\|invalid\|error"; then
	print_test_result "Jump to non-existent bookmark fails gracefully" "PASS"
else
	print_test_result "Jump to non-existent bookmark fails gracefully" "FAIL" "Should show error message"
fi

# ============================================================================
# NAMED BOOKMARK TESTS
# ============================================================================

# Test 13: Save current directory with name
rm -f "$TEST_BOOKMARK_FILE" # Reset for named tests
cd "$TEST_DIR_1" || exit 1
result=$(bash "$PLUGIN_SCRIPT" . -n testproject 2>&1)
if echo "$result" | grep -qi "saved\|testproject"; then
	print_test_result "Save with name: bookmark . -n testproject" "PASS"
else
	print_test_result "Save with name: bookmark . -n testproject" "FAIL" "Expected success message"
fi

# Test 14: Named bookmark stored correctly
saved_name=$(jq -r '.bookmarks.named[0].name // empty' "$TEST_BOOKMARK_FILE" 2>/dev/null)
saved_path=$(jq -r '.bookmarks.named[0].path // empty' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$saved_name" = "testproject" ] && [ "$saved_path" = "$TEST_DIR_1" ]; then
	print_test_result "Named bookmark stored with correct name and path" "PASS"
else
	print_test_result "Named bookmark stored with correct name and path" "FAIL" "Name: $saved_name, Path: $saved_path"
fi

# Test 15: Jump to named bookmark
result=$(bash "$PLUGIN_SCRIPT" testproject 2>&1)
if echo "$result" | grep -q "$TEST_DIR_1"; then
	print_test_result "Jump to named bookmark works" "PASS"
else
	print_test_result "Jump to named bookmark works" "FAIL" "Expected path in output"
fi

# Test 16: Rename numbered bookmark to named
cd "$TEST_DIR_2" || exit 1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1 # Create unnamed bookmark
result=$(bash "$PLUGIN_SCRIPT" 1 -n myapp 2>&1)
if echo "$result" | grep -qi "renamed\|saved\|myapp"; then
	print_test_result "Rename bookmark 1 to 'myapp'" "PASS"
else
	print_test_result "Rename bookmark 1 to 'myapp'" "FAIL" "Expected success message"
fi

# Test 17: Renamed bookmark accessible by name
result=$(bash "$PLUGIN_SCRIPT" myapp 2>&1)
if echo "$result" | grep -q "$TEST_DIR_2"; then
	print_test_result "Renamed bookmark accessible by name" "PASS"
else
	print_test_result "Renamed bookmark accessible by name" "FAIL" "Expected $TEST_DIR_2 in output"
fi

# Test 18: Duplicate name detection
result=$(bash "$PLUGIN_SCRIPT" . -n testproject 2>&1)
if echo "$result" | grep -qi "exists\|duplicate\|already\|error"; then
	print_test_result "Duplicate bookmark name rejected" "PASS"
else
	print_test_result "Duplicate bookmark name rejected" "FAIL" "Should reject duplicate names"
fi

# Test 19: Invalid name detection (command conflict)
result=$(bash "$PLUGIN_SCRIPT" . -n ls 2>&1)
if echo "$result" | grep -qi "invalid\|conflict\|command\|error"; then
	print_test_result "Invalid name 'ls' rejected (command conflict)" "PASS"
else
	print_test_result "Invalid name 'ls' rejected (command conflict)" "FAIL" "Should reject command names"
fi

# Test 20: Invalid name detection (empty name)
result=$(bash "$PLUGIN_SCRIPT" . -n "" 2>&1)
if echo "$result" | grep -qi "invalid\|empty\|error"; then
	print_test_result "Empty bookmark name rejected" "PASS"
else
	print_test_result "Empty bookmark name rejected" "FAIL" "Should reject empty names"
fi

# ============================================================================
# LIST VIEW TESTS
# ============================================================================

# Test 21: List all bookmarks
result=$(bash "$PLUGIN_SCRIPT" list 2>&1)
if echo "$result" | grep -q "testproject\|myapp"; then
	print_test_result "bookmark list shows named bookmarks" "PASS"
else
	print_test_result "bookmark list shows named bookmarks" "FAIL" "Expected named bookmarks in list"
fi

# Test 22: List shows unnamed bookmarks
cd "$TEST_DIR_3" || exit 1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1
result=$(bash "$PLUGIN_SCRIPT" list 2>&1)
if echo "$result" | grep -qi "unnamed\|recent\|1:"; then
	print_test_result "bookmark list shows unnamed bookmarks" "PASS"
else
	print_test_result "bookmark list shows unnamed bookmarks" "FAIL" "Expected unnamed section"
fi

# Test 23: List last N bookmarks
result=$(bash "$PLUGIN_SCRIPT" list 2 2>&1)
count=$(echo "$result" | grep -c "$TEST_DIR" || echo "0")
if [ "$count" -ge 1 ]; then
	print_test_result "bookmark list N shows limited results" "PASS"
else
	print_test_result "bookmark list N shows limited results" "FAIL" "Expected limited output"
fi

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

# Test 24: Invalid argument handling
result=$(bash "$PLUGIN_SCRIPT" --invalid-flag 2>&1)
if echo "$result" | grep -qi "invalid\|unknown\|error\|usage"; then
	print_test_result "Invalid argument shows error/usage" "PASS"
else
	print_test_result "Invalid argument shows error/usage" "FAIL" "Should show error message"
fi

# Test 25: Non-existent bookmark name
result=$(bash "$PLUGIN_SCRIPT" nonexistent 2>&1)
if echo "$result" | grep -qi "not found\|doesn't exist\|error"; then
	print_test_result "Non-existent bookmark name shows error" "PASS"
else
	print_test_result "Non-existent bookmark name shows error" "FAIL" "Should show error message"
fi

# Test 26: Path no longer exists warning
# Create a bookmark, then delete the directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1
bash "$PLUGIN_SCRIPT" . -n deleted_dir >/dev/null 2>&1
rm -rf "$TEMP_DIR"
result=$(bash "$PLUGIN_SCRIPT" deleted_dir 2>&1)
if echo "$result" | grep -qi "not exist\|warning\|deleted"; then
	print_test_result "Warn when bookmark path no longer exists" "PASS"
else
	print_test_result "Warn when bookmark path no longer exists" "FAIL" "Should warn about missing path"
fi

# ============================================================================
# JSON STRUCTURE TESTS
# ============================================================================

# Test 27: JSON has correct structure
if jq -e '.bookmarks.named' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1 &&
	jq -e '.bookmarks.unnamed' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1; then
	print_test_result "JSON structure has named and unnamed sections" "PASS"
else
	print_test_result "JSON structure has named and unnamed sections" "FAIL" "Missing required sections"
fi

# Test 28: Named bookmarks have required fields
has_name=$(jq -e '.bookmarks.named[0].name' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
has_path=$(jq -e '.bookmarks.named[0].path' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
has_created=$(jq -e '.bookmarks.named[0].created' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
if [ "$has_name" = "yes" ] && [ "$has_path" = "yes" ] && [ "$has_created" = "yes" ]; then
	print_test_result "Named bookmarks have required fields (name, path, created)" "PASS"
else
	print_test_result "Named bookmarks have required fields" "FAIL" "Missing fields: name=$has_name path=$has_path created=$has_created"
fi

# Test 29: Unnamed bookmarks have required fields
has_id=$(jq -e '.bookmarks.unnamed[0].id' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
has_path=$(jq -e '.bookmarks.unnamed[0].path' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
has_created=$(jq -e '.bookmarks.unnamed[0].created' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
if [ "$has_id" = "yes" ] && [ "$has_path" = "yes" ] && [ "$has_created" = "yes" ]; then
	print_test_result "Unnamed bookmarks have required fields (id, path, created)" "PASS"
else
	print_test_result "Unnamed bookmarks have required fields" "FAIL" "Missing fields: id=$has_id path=$has_path created=$has_created"
fi

# Test 30: Config section exists
if jq -e '.config' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1; then
	print_test_result "JSON has config section" "PASS"
else
	print_test_result "JSON has config section" "FAIL" "Missing config section"
fi

# ============================================================================
# EDGE CASES
# ============================================================================

# Test 31: Special characters in path
SPECIAL_DIR=$(mktemp -d -p /tmp "test dir with spaces-XXXXXX")
cd "$SPECIAL_DIR" || exit 1
result=$(bash "$PLUGIN_SCRIPT" . -n special_path 2>&1)
if echo "$result" | grep -qi "saved"; then
	print_test_result "Bookmark path with spaces handled correctly" "PASS"
else
	print_test_result "Bookmark path with spaces handled correctly" "FAIL" "Failed to save path with spaces"
fi
cd "$TEST_DIR_1" || exit 1  # Return to valid directory before cleanup
rm -rf "$SPECIAL_DIR"

# Test 32: Very long bookmark name
LONG_NAME="this_is_a_very_long_bookmark_name_that_should_still_work_properly"
result=$(bash "$PLUGIN_SCRIPT" . -n "$LONG_NAME" 2>&1)
if echo "$result" | grep -qi "saved"; then
	print_test_result "Long bookmark name accepted" "PASS"
else
	print_test_result "Long bookmark name accepted" "FAIL" "Output: $result"
fi

# Test 33: Concurrent bookmark creation (race condition test)
# This is a basic test - in production, file locking would be needed
cd "$TEST_DIR_1" || exit 1
bash "$PLUGIN_SCRIPT" . -n concurrent1 >/dev/null 2>&1 &
bash "$PLUGIN_SCRIPT" . -n concurrent2 >/dev/null 2>&1 &
wait
# Just check that file is still valid JSON after concurrent writes
if jq empty "$TEST_BOOKMARK_FILE" 2>/dev/null; then
	print_test_result "Concurrent bookmark creation maintains JSON validity" "PASS"
else
	print_test_result "Concurrent bookmark creation maintains JSON validity" "FAIL" "JSON corrupted by concurrent writes"
fi

# ============================================================================
# CATEGORY TESTS (Phase 2)
# ============================================================================

# Test 34: Save bookmark with category
cd "$TEST_DIR_1" || exit 1
result=$(bash "$PLUGIN_SCRIPT" . -n cattest in projects/test 2>&1)
if echo "$result" | grep -qi "category.*projects/test"; then
	print_test_result "Save bookmark with category" "PASS"
else
	print_test_result "Save bookmark with category" "FAIL" "Output: $result"
fi

# Test 35: Category stored correctly in JSON
category=$(jq -r '.bookmarks.named[] | select(.name == "cattest") | .category' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$category" = "projects/test" ]; then
	print_test_result "Category stored correctly in JSON" "PASS"
else
	print_test_result "Category stored correctly in JSON" "FAIL" "Expected 'projects/test', got: $category"
fi

# Test 36: Rename bookmark with category
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1 # Create unnamed bookmark
result=$(bash "$PLUGIN_SCRIPT" 1 -n renamedcat in tools 2>&1)
if echo "$result" | grep -qi "category.*tools"; then
	print_test_result "Rename bookmark with category" "PASS"
else
	print_test_result "Rename bookmark with category" "FAIL" "Output: $result"
fi

# Test 37: List bookmarks shows categories
result=$(bash "$PLUGIN_SCRIPT" list 2>&1)
if echo "$result" | grep -qi "projects/test\|tools"; then
	print_test_result "List bookmarks shows categories" "PASS"
else
	print_test_result "List bookmarks shows categories" "FAIL" "Categories not shown in output"
fi

# Test 38: Filter bookmarks by category
bash "$PLUGIN_SCRIPT" . -n proj1 in projects/java >/dev/null 2>&1
bash "$PLUGIN_SCRIPT" . -n proj2 in projects/python >/dev/null 2>&1
bash "$PLUGIN_SCRIPT" . -n tool1 in tools >/dev/null 2>&1
result=$(bash "$PLUGIN_SCRIPT" list projects 2>&1)
if echo "$result" | grep -qi "projects/java\|projects/python" && ! echo "$result" | grep -qi "^[[:space:]]*\[tool1\]"; then
	print_test_result "Filter bookmarks by category" "PASS"
else
	print_test_result "Filter bookmarks by category" "FAIL" "Category filter not working"
fi

# Test 39: Move bookmark to different category
bash "$PLUGIN_SCRIPT" . -n moveme in oldcat >/dev/null 2>&1
result=$(bash "$PLUGIN_SCRIPT" mv moveme to newcat 2>&1)
if echo "$result" | grep -qi "moved.*newcat"; then
	print_test_result "Move bookmark to different category" "PASS"
else
	print_test_result "Move bookmark to different category" "FAIL" "Output: $result"
fi

# Test 40: Verify moved bookmark has new category
new_category=$(jq -r '.bookmarks.named[] | select(.name == "moveme") | .category' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$new_category" = "newcat" ]; then
	print_test_result "Moved bookmark has correct new category" "PASS"
else
	print_test_result "Moved bookmark has correct new category" "FAIL" "Expected 'newcat', got: $new_category"
fi

# Test 41: Move non-existent bookmark fails gracefully
result=$(bash "$PLUGIN_SCRIPT" mv nonexistent to somecat 2>&1)
if echo "$result" | grep -qi "not found\|error"; then
	print_test_result "Move non-existent bookmark fails gracefully" "PASS"
else
	print_test_result "Move non-existent bookmark fails gracefully" "FAIL" "Should show error"
fi

# ============================================================================
# OUTPUT FORMAT & INTEGRATION TESTS
# ============================================================================

# Test 42: Help output uses echo -e for ANSI codes (not raw \033)
# This ensures colors work properly when displayed
help_output=$(bash "$PLUGIN_SCRIPT" --help 2>&1)
if echo "$help_output" | grep -q '\\033'; then
	print_test_result "Help output doesn't contain raw ANSI codes" "FAIL" "Found raw \\033 codes - need echo -e"
else
	print_test_result "Help output doesn't contain raw ANSI codes" "PASS"
fi

# Test 43: Jump command outputs valid cd command for shell sourcing
cd "$TEST_DIR_1" || exit 1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1  # Create a bookmark
jump_output=$(bash "$PLUGIN_SCRIPT" 1 2>&1)
if echo "$jump_output" | grep -q '^cd "'; then
	print_test_result "Jump command outputs valid cd command" "PASS"
else
	print_test_result "Jump command outputs valid cd command" "FAIL" "Expected 'cd \"path\"' format, got: $jump_output"
fi

# Test 44: Jump command output is eval-safe (properly quoted path)
cd "$TEST_DIR_WITH_SPACES" || exit 1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1  # Save path with spaces
jump_output=$(bash "$PLUGIN_SCRIPT" 1 2>&1)
cd_line=$(echo "$jump_output" | grep '^cd ')
if [ -n "$cd_line" ]; then
	# Try to eval the cd command (should not fail even with spaces)
	if eval "$cd_line" 2>/dev/null; then
		print_test_result "Jump command handles paths with spaces correctly" "PASS"
	else
		print_test_result "Jump command handles paths with spaces correctly" "FAIL" "eval failed on: $cd_line"
	fi
else
	print_test_result "Jump command handles paths with spaces correctly" "FAIL" "No cd command in output"
fi

# Test 45: Named bookmark jump also outputs cd command
bash "$PLUGIN_SCRIPT" . -n testjump >/dev/null 2>&1
jump_output=$(bash "$PLUGIN_SCRIPT" testjump 2>&1)
if echo "$jump_output" | grep -q '^cd "'; then
	print_test_result "Named bookmark jump outputs cd command" "PASS"
else
	print_test_result "Named bookmark jump outputs cd command" "FAIL" "Expected 'cd \"path\"', got: $jump_output"
fi

# Test 46: List command output uses echo -e for colors
bash "$PLUGIN_SCRIPT" . -n colortest in testcat >/dev/null 2>&1
list_output=$(bash "$PLUGIN_SCRIPT" list 2>&1)
if echo "$list_output" | grep -q '\\033'; then
	print_test_result "List output doesn't contain raw ANSI codes" "FAIL" "Found raw \\033 codes"
else
	print_test_result "List output doesn't contain raw ANSI codes" "PASS"
fi

# Test 47: Error messages use echo -e for colored output
error_output=$(bash "$PLUGIN_SCRIPT" nonexistent 2>&1)
if echo "$error_output" | grep -q '\\033'; then
	print_test_result "Error messages don't contain raw ANSI codes" "FAIL" "Found raw \\033 codes"
else
	print_test_result "Error messages don't contain raw ANSI codes" "PASS"
fi

# ============================================================================
# PHASE 3: BOOKMARK MANAGEMENT (rm, clear)
# ============================================================================

# Test 48: Remove named bookmark
cd "$TEST_DIR_1" || exit 1
bash "$PLUGIN_SCRIPT" . -n rmtest >/dev/null 2>&1
result=$(bash "$PLUGIN_SCRIPT" rm rmtest 2>&1)
if echo "$result" | grep -qi "removed.*rmtest"; then
	print_test_result "Remove named bookmark" "PASS"
else
	print_test_result "Remove named bookmark" "FAIL" "Output: $result"
fi

# Test 49: Verify bookmark was removed from JSON
if jq -e '.bookmarks.named[] | select(.name == "rmtest")' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1; then
	print_test_result "Named bookmark removed from JSON" "FAIL" "Bookmark still exists in JSON"
else
	print_test_result "Named bookmark removed from JSON" "PASS"
fi

# Test 50: Remove numbered bookmark
cd "$TEST_DIR_1" || exit 1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1  # Create bookmark 1
result=$(bash "$PLUGIN_SCRIPT" rm 1 2>&1)
if echo "$result" | grep -qi "removed.*#1"; then
	print_test_result "Remove numbered bookmark" "PASS"
else
	print_test_result "Remove numbered bookmark" "FAIL" "Output: $result"
fi

# Test 51: Verify numbered bookmark was removed
if jq -e '.bookmarks.unnamed[] | select(.id == 1)' "$TEST_BOOKMARK_FILE" >/dev/null 2>&1; then
	print_test_result "Numbered bookmark removed from JSON" "FAIL" "Bookmark still exists"
else
	print_test_result "Numbered bookmark removed from JSON" "PASS"
fi

# Test 52: Remove non-existent bookmark fails gracefully
result=$(bash "$PLUGIN_SCRIPT" rm nonexistent 2>&1)
if echo "$result" | grep -qi "not found\|error"; then
	print_test_result "Remove non-existent bookmark fails gracefully" "PASS"
else
	print_test_result "Remove non-existent bookmark fails gracefully" "FAIL" "Should show error"
fi

# Test 53: Clear command with no unnamed bookmarks
jq '.bookmarks.unnamed = []' "$TEST_BOOKMARK_FILE" > "$TEST_BOOKMARK_FILE.tmp" && mv "$TEST_BOOKMARK_FILE.tmp" "$TEST_BOOKMARK_FILE"
result=$(echo "n" | bash "$PLUGIN_SCRIPT" clear 2>&1)
if echo "$result" | grep -qi "no unnamed bookmarks"; then
	print_test_result "Clear command with no unnamed bookmarks" "PASS"
else
	print_test_result "Clear command with no unnamed bookmarks" "FAIL" "Output: $result"
fi

# Test 54: Clear unnamed bookmarks (with confirmation)
cd "$TEST_DIR_1" || exit 1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1
# Confirm with 'y'
result=$(echo "y" | bash "$PLUGIN_SCRIPT" clear 2>&1)
if echo "$result" | grep -qi "cleared.*3.*unnamed"; then
	print_test_result "Clear unnamed bookmarks with confirmation" "PASS"
else
	print_test_result "Clear unnamed bookmarks with confirmation" "FAIL" "Output: $result"
fi

# Test 55: Verify unnamed bookmarks were cleared
count=$(jq '.bookmarks.unnamed | length' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$count" -eq 0 ]; then
	print_test_result "Unnamed bookmarks cleared from JSON" "PASS"
else
	print_test_result "Unnamed bookmarks cleared from JSON" "FAIL" "Expected 0, got: $count"
fi

# Test 56: Clear cancelled by user
cd "$TEST_DIR_1" || exit 1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1
bash "$PLUGIN_SCRIPT" . >/dev/null 2>&1
# Cancel with 'n'
result=$(echo "n" | bash "$PLUGIN_SCRIPT" clear 2>&1)
if echo "$result" | grep -qi "cancelled"; then
	print_test_result "Clear cancelled by user" "PASS"
else
	print_test_result "Clear cancelled by user" "FAIL" "Should show 'Cancelled'"
fi

# Test 57: Verify bookmarks not cleared after cancellation
count=$(jq '.bookmarks.unnamed | length' "$TEST_BOOKMARK_FILE" 2>/dev/null)
if [ "$count" -eq 2 ]; then
	print_test_result "Bookmarks preserved after cancel" "PASS"
else
	print_test_result "Bookmarks preserved after cancel" "FAIL" "Expected 2, got: $count"
fi

# Cleanup
cleanup_bookmark_tests
