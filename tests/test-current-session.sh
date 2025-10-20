#!/usr/bin/env bash
# test-current-session.sh - Test that mlh history reads current session commands

set +e

echo "Testing current session history..."
echo ""

# Enable HISTTIMEFORMAT
export HISTTIMEFORMAT='%F %T  '

# Create a test history file with old and new commands
TEST_HISTFILE=$(mktemp)
current_ts=$(date +%s)

# Write some old commands
cat >"$TEST_HISTFILE" <<EOF
#$((current_ts - 7200))
old command 1
#$((current_ts - 3600))
old command 2
EOF

echo "Initial history file (2 old commands):"
cat "$TEST_HISTFILE"
echo ""

# Start a new bash session with this history file and add new commands
export HISTFILE="$TEST_HISTFILE"

# Simulate adding commands to current session (these would normally be in memory)
# We'll append them to simulate what history -a does
cat >>"$TEST_HISTFILE" <<EOF
#$current_ts
new command from session
EOF

echo "After simulating 'history -a' (added 1 new command):"
cat "$TEST_HISTFILE"
echo ""

# Now test that mlh history can read all commands including the new one
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Running: mlh history 3"
result=$(bash "$ROOT_DIR/plugins/mlh-history.sh" 3 2>&1)
echo "$result"
echo ""

# Check if the new command appears
if echo "$result" | grep -q "new command from session"; then
	echo "✓ PASS: mlh history shows current session command"
else
	echo "✗ FAIL: mlh history does NOT show current session command"
fi

# Cleanup
rm -f "$TEST_HISTFILE"
