#!/bin/bash
# ll.sh — Simple ls -la shortcut.

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	cat <<'EOF'
Usage: ll [path]

Enhanced directory listing - shortcut for 'ls -la'.

Examples:
  ll                          # List current directory
  ll /var/log                 # List specific directory
  ll *.json                   # List with pattern
EOF
	exit 0
fi

ls -la "$@"
