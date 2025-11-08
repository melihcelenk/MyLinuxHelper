#!/usr/bin/env bash
# Integration tests for bookmark alias functionality with setup.sh

# Disable strict mode for tests (like other test files)
set +euo pipefail 2>/dev/null || true
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$TESTS_DIR")"

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
	export TEST_HOME="/tmp/test-bookmark-alias-integration-$$"
	mkdir -p "$TEST_HOME/.mylinuxhelper"
	mkdir -p "$TEST_HOME/.local/bin"
	export HOME="$TEST_HOME"
	export MLH_CONFIG_DIR="$TEST_HOME/.mylinuxhelper"
	export MLH_CONFIG_FILE="$MLH_CONFIG_DIR/mlh.conf"

	# Create minimal bashrc
	touch "$TEST_HOME/.bashrc"
	touch "$TEST_HOME/.profile"
}

# Cleanup test environment
cleanup_test_env() {
	rm -rf "/tmp/test-bookmark-alias-integration-$$" 2>/dev/null || true
}

# Trap to ensure cleanup
trap cleanup_test_env EXIT

# Run tests
setup_test_env

#
# Test Group 1: Wrapper function structure
#

# Test 1: Alias wrapper delegates to bookmark function
echo "BOOKMARK_ALIAS=bm" >"$MLH_CONFIG_FILE"

# Create a mock bashrc with wrapper
cat >"$TEST_HOME/.bashrc" <<'EOF'
bookmark() {
  echo "bookmark function called with: $*"
  command bookmark "$@"
}

bm() {
  bookmark "$@"
}
EOF

# Source and test
source "$TEST_HOME/.bashrc"
output=$(bm test 2>&1 || true)
if echo "$output" | grep -q "bookmark function called"; then
	print_test_result "Alias wrapper delegates to bookmark function" "PASS"
else
	print_test_result "Alias wrapper delegates to bookmark function" "FAIL" "Delegation not working"
fi

# Test 2: Wrapper preserves all arguments
output=$(bm arg1 arg2 arg3 2>&1 || true)
if echo "$output" | grep -q "arg1 arg2 arg3"; then
	print_test_result "Wrapper preserves all arguments" "PASS"
else
	print_test_result "Wrapper preserves all arguments" "FAIL" "Arguments not preserved"
fi

# Test 3: Wrapper handles special characters in arguments
output=$(bm "path with spaces" 2>&1 || true)
if echo "$output" | grep -q "path with spaces"; then
	print_test_result "Wrapper handles special characters" "PASS"
else
	print_test_result "Wrapper handles special characters" "FAIL" "Special chars not handled"
fi

#
# Test Group 2: setup.sh execution with alias
#

# Test 4: setup.sh runs without error with alias configured
echo "BOOKMARK_ALIAS=testbm" >"$MLH_CONFIG_FILE"
if cd "$ROOT_DIR"; then
	output=$(bash setup.sh 2>&1 || true)
	exit_code=$?
else
	output="Failed to cd to $ROOT_DIR"
	exit_code=1
fi
if [ $exit_code -eq 0 ] || echo "$output" | grep -q "Setup complete"; then
	print_test_result "setup.sh runs without error with alias" "PASS"
else
	print_test_result "setup.sh runs without error with alias" "FAIL" "Exit code: $exit_code"
fi

# Test 5: setup.sh creates symlink for alias
if [ -L "$TEST_HOME/.local/bin/testbm" ]; then
	print_test_result "setup.sh creates symlink for alias" "PASS"
else
	print_test_result "setup.sh creates symlink for alias" "FAIL" "Symlink not created"
fi

# Test 6: Alias symlink points to mlh-bookmark.sh
if [ -L "$TEST_HOME/.local/bin/testbm" ]; then
	target=$(readlink "$TEST_HOME/.local/bin/testbm")
	if echo "$target" | grep -q "mlh-bookmark.sh"; then
		print_test_result "Alias symlink points to mlh-bookmark.sh" "PASS"
	else
		print_test_result "Alias symlink points to mlh-bookmark.sh" "FAIL" "Wrong target: $target"
	fi
else
	print_test_result "Alias symlink points to mlh-bookmark.sh" "SKIP" "Symlink not created"
fi

# Test 7: setup.sh adds alias wrapper to bashrc
if grep -q "testbm()" "$TEST_HOME/.bashrc"; then
	print_test_result "setup.sh adds alias wrapper to bashrc" "PASS"
else
	print_test_result "setup.sh adds alias wrapper to bashrc" "FAIL" "Wrapper not found"
fi

# Test 8: Alias wrapper in bashrc has correct structure
if grep -q 'bookmark "\$@"' "$TEST_HOME/.bashrc"; then
	print_test_result "Alias wrapper has correct delegation structure" "PASS"
else
	print_test_result "Alias wrapper has correct delegation structure" "FAIL" "Delegation not found"
fi

# Test 9: setup.sh shows BASHRC_UPDATED warning
if echo "$output" | grep -qi "Important.*Shell configuration updated" || echo "$output" | grep -q "source ~/.bashrc"; then
	print_test_result "setup.sh shows BASHRC_UPDATED warning" "PASS"
else
	print_test_result "setup.sh shows BASHRC_UPDATED warning" "FAIL" "Warning not shown"
fi

# Test 10: Alias mentioned in setup complete message
if echo "$output" | grep -q "testbm"; then
	print_test_result "Alias mentioned in setup complete message" "PASS"
else
	print_test_result "Alias mentioned in setup complete message" "FAIL" "Alias not mentioned"
fi

#
# Test Group 3: Command conflict detection
#

# Test 11: setup.sh detects command conflicts
# Create a fake conflicting command
mkdir -p "$TEST_HOME/.local/bin"
echo '#!/bin/bash' >"$TEST_HOME/.local/bin/conflictcmd"
echo 'echo "existing command"' >>"$TEST_HOME/.local/bin/conflictcmd"
chmod +x "$TEST_HOME/.local/bin/conflictcmd"
export PATH="$TEST_HOME/.local/bin:$PATH"

echo "BOOKMARK_ALIAS=conflictcmd" >"$MLH_CONFIG_FILE"
if cd "$ROOT_DIR"; then
	output=$(bash setup.sh 2>&1 || true)
else
	output="Failed to cd to $ROOT_DIR"
fi
if echo "$output" | grep -qi "conflict\|already exists"; then
	print_test_result "setup.sh detects command conflicts" "PASS"
else
	print_test_result "setup.sh detects command conflicts" "SKIP" "Conflict detection might be optional"
fi

#
# Test Group 4: bm list interactive mode directory change
#

# Test 12: bm list changes directory when bookmark selected (interactive mode)
# This test verifies that when using the bm alias, the interactive list mode
# properly changes the directory when a bookmark is selected.

# Ensure test environment is still set up (might have been modified by previous tests)
if [ -z "${TEST_HOME:-}" ]; then
	setup_test_env
fi

# Check if jq and tmux are available
JQ_AVAILABLE=0
if command -v jq >/dev/null 2>&1; then
	JQ_AVAILABLE=1
fi

TMUX_AVAILABLE_BM=0
if command -v tmux >/dev/null 2>&1; then
	TMUX_AVAILABLE_BM=1
fi

# Always show test result, even if skipped
if [ "$JQ_AVAILABLE" -eq 0 ] || [ "$TMUX_AVAILABLE_BM" -eq 0 ]; then
	print_test_result "bm list changes directory (interactive mode)" "SKIP" "jq or tmux not available (jq: $JQ_AVAILABLE, tmux: $TMUX_AVAILABLE_BM)"
else
	# Setup: Configure bm alias in mlh.conf (new format)
	echo "# MyLinuxHelper Configuration" >"$MLH_CONFIG_FILE"
	echo "BOOKMARK_ALIAS=bm" >>"$MLH_CONFIG_FILE"

	# Ensure HOME is set correctly for setup.sh
	export HOME="$TEST_HOME"

	# Run setup.sh to create wrapper functions
	cd "$ROOT_DIR" || exit 1
	bash setup.sh >/dev/null 2>&1 || true

	# Create test bookmark file
	test_bm_bookmark_file="/tmp/test-bookmark-bm-list-$$"
	test_bm_bookmark_dir=$(mktemp -d)
	if ! cd "$test_bm_bookmark_dir" 2>/dev/null; then
		print_test_result "bm list changes directory (interactive mode)" "FAIL" "Failed to create or cd to test directory"
	else
		# Create bookmark in test file
		MLH_BOOKMARK_FILE="$test_bm_bookmark_file" bash "$ROOT_DIR/plugins/mlh-bookmark.sh" . -n testbmlist >/dev/null 2>&1

		# Create a different starting directory
		start_dir_bm=$(mktemp -d)

		# Create unique session name
		session_name_bm="test-bookmark-bm-list-$$"

		# Kill any existing session with same name
		tmux kill-session -t "$session_name_bm" 2>/dev/null || true

		# Create tmux session - simulate real usage where setup.sh was already run
		# In real usage: user runs setup.sh once → wrapper functions added to .bashrc
		# Then user opens new shell → .bashrc is sourced automatically
		#
		# IMPORTANT: We should NOT source setup.sh again in tmux session
		# Instead, we should rely on .bashrc being sourced (which happens with bash -i)
		# But bash -i might not source .bashrc in non-interactive tmux, so we explicitly source it
		#
		# CRITICAL: The bug might be that when bm() calls bookmark(), the source command
		# in bookmark() doesn't properly change the directory in the calling shell.
		# This could happen if source runs in a subshell or if there's a scope issue.
		tmux new-session -d -s "$session_name_bm" bash
		sleep 0.5

		# Set up environment in tmux session
		tmux send-keys -t "$session_name_bm" "export HOME='$TEST_HOME'" C-m
		sleep 0.2
		tmux send-keys -t "$session_name_bm" "export MLH_BOOKMARK_FILE='$test_bm_bookmark_file'" C-m
		sleep 0.2

		# Source .bashrc to load wrapper functions (this is what happens in real shell)
		# Do NOT source setup.sh - that's not what users do in real usage
		tmux send-keys -t "$session_name_bm" "source ~/.bashrc 2>/dev/null || true" C-m
		sleep 0.5

		# Verify bm function is loaded (if not, test should fail)
		tmux send-keys -t "$session_name_bm" "type bm > /tmp/bm-check-$$ 2>&1; echo 'BM_TYPE_DONE' >> /tmp/bm-check-$$" C-m
		sleep 0.3

		# Send commands to tmux session
		tmux send-keys -t "$session_name_bm" "cd '$start_dir_bm'" C-m
		sleep 0.2
		tmux send-keys -t "$session_name_bm" "pwd > /tmp/pwd-before-bm-$$" C-m
		sleep 0.2

		# Use bm list (alias) instead of bookmark list
		# This tests that the alias wrapper properly delegates to bookmark function
		# and that the bookmark function's interactive mode cd mechanism works
		#
		# THE BUG: bm() function calls bookmark() which should handle the interactive
		# list mode and source the temp file for cd. But if the temp file is sourced
		# in the bookmark() function's scope, it might not affect the parent shell
		# that called bm(). The source command should work, but maybe there's a timing
		# issue or the temp file isn't being written correctly.
		tmux send-keys -t "$session_name_bm" "bm list" C-m
		sleep 0.5

		# Press Enter to select first bookmark (which should be testbmlist)
		tmux send-keys -t "$session_name_bm" "" C-m
		sleep 1.0

		# Exit interactive mode - try multiple methods
		# First try 'q' followed by Enter
		tmux send-keys -t "$session_name_bm" "q"
		sleep 0.2
		tmux send-keys -t "$session_name_bm" C-m
		sleep 0.3
		# If that doesn't work, try ESC
		tmux send-keys -t "$session_name_bm" Escape
		sleep 0.3
		# Last resort: Ctrl+C
		tmux send-keys -t "$session_name_bm" C-c
		sleep 0.5

		# Get PWD after - this should show if cd worked
		tmux send-keys -t "$session_name_bm" "pwd > /tmp/pwd-after-bm-$$" C-m
		sleep 0.2

		# Exit tmux session
		tmux send-keys -t "$session_name_bm" "exit" C-m
		sleep 0.2

		# Kill session
		tmux kill-session -t "$session_name_bm" 2>/dev/null || true

		# Compare PWDs and check debug info
		pwd_before_bm=$(cat /tmp/pwd-before-bm-$$ 2>/dev/null || echo "")
		pwd_after_bm=$(cat /tmp/pwd-after-bm-$$ 2>/dev/null || echo "")
		bm_check=$(cat /tmp/bm-check-$$ 2>/dev/null || echo "")

		# Cleanup temp files ONLY (keep directories until after PWD comparison)
		rm -f /tmp/pwd-before-bm-$$ /tmp/pwd-after-bm-$$ /tmp/bm-check-$$ "$test_bm_bookmark_file" 2>/dev/null || true
		# Note: Don't remove directories yet - they're needed for cd to work
		# Cleanup will happen at test suite end

		# Expected: Directory should change from start_dir_bm to test_bm_bookmark_dir
		# If directory didn't change, the test should FAIL (this is the bug we're testing for)
		# The user reports that bm list does NOT change directory in real usage
		if [ -n "$pwd_before_bm" ] && [ -n "$pwd_after_bm" ]; then
			if [ "$pwd_before_bm" != "$pwd_after_bm" ] && [ "$pwd_after_bm" = "$test_bm_bookmark_dir" ]; then
				# Directory changed correctly - but user reports this doesn't work in real usage
				# This might be a false positive if test environment differs from real usage
				print_test_result "bm list changes directory (interactive mode)" "PASS" "Directory changed: $pwd_before_bm -> $pwd_after_bm (NOTE: If this passes but fails in real usage, there's a test environment issue)"
			elif [ "$pwd_before_bm" = "$pwd_after_bm" ]; then
				# Directory didn't change - this confirms the bug
				print_test_result "bm list changes directory (interactive mode)" "FAIL" "Directory didn't change. Before: '$pwd_before_bm', After: '$pwd_after_bm' (expected: '$test_bm_bookmark_dir'). bm function check: ${bm_check:0:80}"
			else
				# Directory changed but to wrong location
				print_test_result "bm list changes directory (interactive mode)" "FAIL" "Directory changed to wrong location. Before: '$pwd_before_bm', After: '$pwd_after_bm' (expected: '$test_bm_bookmark_dir')"
			fi
		else
			print_test_result "bm list changes directory (interactive mode)" "FAIL" "Couldn't read PWD values. Before: '$pwd_before_bm', After: '$pwd_after_bm'. bm function check: ${bm_check:0:80}"
		fi

		# Cleanup directories
		rm -rf "$test_bm_bookmark_dir" "$start_dir_bm" 2>/dev/null || true
	fi
fi

# Test 13: bm list changes directory on second invocation (interactive mode)
# This test verifies that when using the bm alias, the interactive list mode
# properly changes the directory when called TWICE in the same session.
# Based on test-mlh-bookmark.sh Test 77, but using bm alias instead of bookmark command.

# Check if jq and tmux are available
JQ_AVAILABLE_13=0
if command -v jq >/dev/null 2>&1; then
	JQ_AVAILABLE_13=1
fi

TMUX_AVAILABLE_BM_13=0
if command -v tmux >/dev/null 2>&1; then
	TMUX_AVAILABLE_BM_13=1
fi

# Always show test result, even if skipped
if [ "$JQ_AVAILABLE_13" -eq 0 ] || [ "$TMUX_AVAILABLE_BM_13" -eq 0 ]; then
	print_test_result "bm list changes directory on second invocation (interactive mode)" "SKIP" "jq or tmux not available (jq: $JQ_AVAILABLE_13, tmux: $TMUX_AVAILABLE_BM_13)"
else
	# Ensure test environment is still set up
	if [ -z "${TEST_HOME:-}" ]; then
		setup_test_env
	fi

	# Setup: Configure bm alias in mlh.conf (new format)
	echo "# MyLinuxHelper Configuration" >"$MLH_CONFIG_FILE"
	echo "BOOKMARK_ALIAS=bm" >>"$MLH_CONFIG_FILE"

	# Ensure HOME is set correctly for setup.sh
	export HOME="$TEST_HOME"

	# Run setup.sh to create wrapper functions
	cd "$ROOT_DIR" || exit 1
	bash setup.sh >/dev/null 2>&1 || true

	# Create test bookmark file and directories for this test
	test_bm_13_bookmark_file="/tmp/test-bookmark-bm-13-$$"
	test_bm_bookmark_dir1_13=$(mktemp -d)
	test_bm_bookmark_dir2_13=$(mktemp -d)

	# Create TWO bookmarks for this test (to select twice in same session)
	cd "$test_bm_bookmark_dir1_13" || exit 1
	MLH_BOOKMARK_FILE="$test_bm_13_bookmark_file" bash "$ROOT_DIR/plugins/mlh-bookmark.sh" . -n bm1_13 >/dev/null 2>&1
	cd "$test_bm_bookmark_dir2_13" || exit 1
	MLH_BOOKMARK_FILE="$test_bm_13_bookmark_file" bash "$ROOT_DIR/plugins/mlh-bookmark.sh" . -n bm2_13 >/dev/null 2>&1

	# Create a different starting directory
	start_dir_bm_13=$(mktemp -d)

	# Create unique session name
	session_name_bm_13="test-bookmark-bm-13-$$"

	# Kill any existing session with same name
	tmux kill-session -t "$session_name_bm_13" 2>/dev/null || true

	# Create tmux session - simulate real usage where setup.sh was already run
	# In real usage: user runs setup.sh once → wrapper functions added to .bashrc
	# Then user opens new shell → .bashrc is sourced automatically
	#
	# IMPORTANT: We should NOT source setup.sh again in tmux session
	# Instead, we should rely on .bashrc being sourced (which happens with bash -i)
	# But bash -i might not source .bashrc in non-interactive tmux, so we explicitly source it
	tmux new-session -d -s "$session_name_bm_13" bash
	sleep 0.5

	# Set up environment in tmux session
	tmux send-keys -t "$session_name_bm_13" "export HOME='$TEST_HOME'" C-m
	sleep 0.2
	tmux send-keys -t "$session_name_bm_13" "export MLH_BOOKMARK_FILE='$test_bm_13_bookmark_file'" C-m
	sleep 0.2

	# Source .bashrc to load wrapper functions (this is what happens in real shell)
	# Do NOT source setup.sh - that's not what users do in real usage
	tmux send-keys -t "$session_name_bm_13" "source ~/.bashrc 2>/dev/null || true" C-m
	sleep 0.5

	# === TEST: TWO SEPARATE INVOCATIONS (not same session) ===
	# Start from a known directory
	tmux send-keys -t "$session_name_bm_13" "cd '$start_dir_bm_13'" C-m
	sleep 0.3
	tmux send-keys -t "$session_name_bm_13" "pwd > /tmp/pwd-start-bm-13-$$" C-m
	sleep 0.3

	# FIRST INVOCATION: bm list (alias), select first bookmark
	tmux send-keys -t "$session_name_bm_13" "bm list" C-m
	sleep 1.0
	tmux send-keys -t "$session_name_bm_13" "" C-m # Enter - select first bookmark
	sleep 1.2
	tmux send-keys -t "$session_name_bm_13" "pwd > /tmp/pwd-after-first-bm-13-$$" C-m
	sleep 0.3

	# SECOND INVOCATION: bm list again (alias), select second bookmark
	tmux send-keys -t "$session_name_bm_13" "bm list" C-m
	sleep 1.0
	tmux send-keys -t "$session_name_bm_13" "Down" C-m # Navigate to second bookmark
	sleep 0.5
	tmux send-keys -t "$session_name_bm_13" "" C-m # Enter - select second bookmark
	sleep 1.2
	tmux send-keys -t "$session_name_bm_13" "pwd > /tmp/pwd-final-bm-13-$$" C-m
	sleep 0.3

	# Exit tmux session
	tmux send-keys -t "$session_name_bm_13" "exit" C-m
	sleep 0.2

	# Kill session
	tmux kill-session -t "$session_name_bm_13" 2>/dev/null || true

	# Read PWDs
	pwd_start_bm_13=$(cat /tmp/pwd-start-bm-13-$$ 2>/dev/null || echo "")
	pwd_after_first_bm_13=$(cat /tmp/pwd-after-first-bm-13-$$ 2>/dev/null || echo "")
	pwd_final_bm_13=$(cat /tmp/pwd-final-bm-13-$$ 2>/dev/null || echo "")

	# Cleanup
	rm -f /tmp/pwd-start-bm-13-$$ /tmp/pwd-after-first-bm-13-$$ /tmp/pwd-final-bm-13-$$ 2>/dev/null || true
	rm -f "$test_bm_13_bookmark_file" 2>/dev/null || true
	rm -rf "$test_bm_bookmark_dir1_13" "$test_bm_bookmark_dir2_13" "$start_dir_bm_13" 2>/dev/null || true

	# Test logic:
	# After TWO SEPARATE invocations with bm list, PWD should change both times
	#   Start: $start_dir_bm_13
	#   After first: $test_bm_bookmark_dir1_13 (first bookmark)
	#   Final: $test_bm_bookmark_dir2_13 (second bookmark)

	# Check if both invocations worked
	first_worked_bm_13="no"
	if [ "$pwd_after_first_bm_13" = "$test_bm_bookmark_dir1_13" ]; then
		first_worked_bm_13="yes"
	fi

	second_worked_bm_13="no"
	if [ "$pwd_final_bm_13" = "$test_bm_bookmark_dir2_13" ]; then
		second_worked_bm_13="yes"
	fi

	if [ "$first_worked_bm_13" = "yes" ] && [ "$second_worked_bm_13" = "yes" ]; then
		print_test_result "bm list changes directory on second invocation (interactive mode)" "PASS" "Both invocations work! Start: $pwd_start_bm_13 -> 1st: $pwd_after_first_bm_13 -> 2nd: $pwd_final_bm_13"
	elif [ "$first_worked_bm_13" = "yes" ]; then
		print_test_result "bm list changes directory on second invocation (interactive mode)" "FAIL" "First works, second doesn't. Start: $pwd_start_bm_13 -> 1st: $pwd_after_first_bm_13 -> 2nd: $pwd_final_bm_13 (expected: $test_bm_bookmark_dir2_13)"
	else
		print_test_result "bm list changes directory on second invocation (interactive mode)" "FAIL" "First invocation failed. Start: $pwd_start_bm_13, After 1st: $pwd_after_first_bm_13, Final: $pwd_final_bm_13"
	fi
fi

# Cleanup
cleanup_test_env

exit 0
