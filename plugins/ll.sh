#!/bin/bash
# ll.sh — Simple ls -la shortcut.

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: ll [path]"
  echo "Lists files with 'ls -la'."
  exit 0
fi

ls -la "$@"
