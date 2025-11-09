#!/usr/bin/env bash
# mlh.sh — Main dispatcher for MyLinuxHelper shortcut commands
#
# Usage:
#   mlh <category> <command> [args...]
#   mlh --help
#   mlh --version
#
# Categories:
#   docker    Docker shortcuts (see: mlh docker --help)
#
# Examples:
#   mlh docker in mycontainer

set -euo pipefail

# Resolve script directory (handle symlinks)
resolve_script_dir() {
	local source="$0"
	while [ -L "$source" ]; do
		local target
		target="$(readlink "$source")"
		if [[ "$target" = /* ]]; then
			source="$target"
		else
			local dir
			dir="$(cd -P "$(dirname "$source")" && pwd)"
			source="$dir/$target"
		fi
	done
	cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"

print_help() {
	cat <<EOF
mlh - MyLinuxHelper shortcut commands

Usage:
  mlh                          Show interactive menu
  mlh <category> <command>     Run category command
  mlh --help                   Show this help
  mlh --version                Show version
  mlh about                    Show project information
  mlh update                   Update to latest version

Categories:
  bookmark  Quick directory bookmarks (see: mlh bookmark --help)
  docker    Docker shortcuts (see: mlh docker --help)
  json      JSON operations (see: mlh json --help)
  history   Enhanced history formatting (see: mlh history --help)

Examples:
  mlh                          # Show interactive menu
  mlh --version                # Show current version
  mlh about                    # Show project information and credits
  mlh update                   # Update to latest version
  mlh bookmark .               # Save current directory as bookmark
  mlh bookmark list            # List all bookmarks
  mlh docker in mycontainer    # Enter a running container by name pattern
  mlh history 10               # Show last 10 commands (numbered)
EOF
}

print_version() {
	exec "$SCRIPT_DIR/mlh-version.sh" "$@"
}

show_about() {
	"$SCRIPT_DIR/mlh-about.sh"
}

show_app_settings_menu() {
	while true; do
		cat <<'EOF'

MyLinuxHelper - App Settings & Updates
=======================================

1. Show current version
2. Update to latest version
3. Configure periodic updates
4. Uninstall MyLinuxHelper
5. Back to main menu

EOF

		read -rp "Select [1-5]: " SETTING_SELECTION
		echo ""

		case "$SETTING_SELECTION" in
		1)
			"$SCRIPT_DIR/mlh-version.sh"
			echo ""
			read -rp "Press Enter to continue..."
			;;
		2)
			exec "$SCRIPT_DIR/mlh-version.sh" update
			;;
		3)
			exec "$SCRIPT_DIR/mlh-version.sh" update -p
			;;
		4)
			"$SCRIPT_DIR/mlh-version.sh" uninstall
			echo ""
			read -rp "Press Enter to continue..."
			;;
		5 | b | B)
			return 0
			;;
		*)
			echo "Invalid selection: $SETTING_SELECTION"
			echo ""
			read -rp "Press Enter to continue..."
			;;
		esac
	done
}

show_interactive_menu() {
	while true; do
		cat <<'EOF'

MyLinuxHelper - Available Commands
===================================

1. bookmark <name>           - Quick directory bookmarks
2. linux <name>              - Create and manage Linux containers
3. search <pattern>          - Fast file search in directories
4. i <package>               - Install packages (auto-detects package manager)
5. JSON operations           - Validate and search JSON files
6. ll [path]                 - Enhanced directory listing (ls -la)
7. mlh docker in <pattern>   - Enter running Docker container
8. mlh history [count]       - Enhanced command history with dates
9. About MyLinuxHelper       - Project information and credits
0. App Settings & Updates    - Version and update settings

Enter command number to see usage, or 'q' to quit.
EOF

		read -rp "Select [0-9, q]: " SELECTION

		echo ""

		case "$SELECTION" in
		1)
			"$SCRIPT_DIR/mlh-bookmark.sh" --help
			exit 0
			;;
		2)
			"$SCRIPT_DIR/linux.sh" --help
			exit 0
			;;
		3)
			"$SCRIPT_DIR/search.sh" --help
			exit 0
			;;
		4)
			"$SCRIPT_DIR/../install.sh" --help
			exit 0
			;;
		5)
			"$SCRIPT_DIR/mlh-json.sh" --help
			exit 0
			;;
		6)
			"$SCRIPT_DIR/ll.sh" --help
			exit 0
			;;
		7)
			"$SCRIPT_DIR/mlh-docker.sh" --help
			exit 0
			;;
		8)
			"$SCRIPT_DIR/mlh-history.sh" --help
			exit 0
			;;
		9)
			show_about
			;;
		0)
			show_app_settings_menu
			;;
		q | Q)
			echo "Goodbye!"
			exit 0
			;;
		*)
			echo "Invalid selection: $SELECTION"
			echo ""
			read -rp "Press Enter to continue..."
			;;
		esac
	done
}

# Parse arguments
if [ $# -eq 0 ]; then
	show_interactive_menu
	exit 0
fi

CATEGORY="$1"
shift

case "$CATEGORY" in
-h | --help)
	print_help
	exit 0
	;;
-v | --version)
	print_version "$@"
	;;
about)
	# Delegate to about script
	exec "$SCRIPT_DIR/mlh-about.sh" --no-prompt
	;;
update)
	# Delegate to version script for updates
	exec "$SCRIPT_DIR/mlh-version.sh" update "$@"
	;;
docker)
	# Delegate to mlh-docker.sh
	exec "$SCRIPT_DIR/mlh-docker.sh" "$@"
	;;
json)
	# Delegate to mlh-json.sh
	exec "$SCRIPT_DIR/mlh-json.sh" "$@"
	;;
history)
	# Delegate to mlh-history.sh
	exec "$SCRIPT_DIR/mlh-history.sh" "$@"
	;;
bookmark)
	# Delegate to mlh-bookmark.sh
	exec "$SCRIPT_DIR/mlh-bookmark.sh" "$@"
	;;
*)
	echo "Error: Unknown category '$CATEGORY'" >&2
	echo "Run 'mlh --help' for available categories." >&2
	exit 1
	;;
esac
