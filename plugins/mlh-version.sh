#!/usr/bin/env bash
# mlh-version.sh — Version management for MyLinuxHelper
#
# Usage:
#   mlh-version.sh [--version|-v]
#   mlh-version.sh update [-p]
#   mlh --version update
#   mlh -v update
#
# Commands:
#   (no args)     Display current version
#   update        Update to the latest version from GitHub
#   update -p     Configure periodic update schedule

set -euo pipefail

readonly VERSION="1.4.1"
# shellcheck disable=SC2034
readonly VERSION_DATE="20.10.2025"
# shellcheck disable=SC2034
readonly FIRST_RELEASE_DATE="11.10.2025"
readonly GITHUB_REPO="melihcelenk/MyLinuxHelper"
readonly INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/get-mlh.sh"
readonly CONFIG_DIR="${HOME}/.mylinuxhelper"
readonly UPDATE_CONFIG="${CONFIG_DIR}/.update-config"
readonly BASHRC="${HOME}/.bashrc"

print_version() {
	echo "MyLinuxHelper v${VERSION}"
}

print_help() {
	cat <<EOF
mlh version - Version management (v${VERSION})

Usage:
  mlh --version              Show current version
  mlh -v                     Show current version
  mlh --version update       Update to latest version
  mlh -v update              Update to latest version
  mlh update                 Update to latest version
  mlh update -p              Configure periodic updates

Examples:
  mlh --version              # Display: MyLinuxHelper v1.3.0
  mlh --version update       # Update to latest version from GitHub
  mlh update -p              # Configure automatic periodic updates
EOF
}

get_config_value() {
	local key="$1"
	if [ -f "${UPDATE_CONFIG}" ]; then
		grep "^${key}=" "${UPDATE_CONFIG}" 2>/dev/null | cut -d'=' -f2
	fi
}

set_config_value() {
	local key="$1"
	local value="$2"
	mkdir -p "${CONFIG_DIR}"

	if [ -f "${UPDATE_CONFIG}" ]; then
		sed -i.bak "/^${key}=/d" "${UPDATE_CONFIG}" 2>/dev/null || true
	fi

	echo "${key}=${value}" >>"${UPDATE_CONFIG}"
}

should_update_now() {
	local schedule
	schedule="$(get_config_value "SCHEDULE")"

	if [ -z "$schedule" ] || [ "$schedule" = "disabled" ]; then
		return 1
	fi

	local last_update
	last_update="$(get_config_value "LAST_UPDATE")"

	if [ -z "$last_update" ]; then
		return 0
	fi

	local current_epoch
	current_epoch="$(date +%s)"
	local last_epoch="$last_update"
	local diff_days=$(((current_epoch - last_epoch) / 86400))

	case "$schedule" in
	daily)
		[ "$diff_days" -ge 1 ]
		;;
	weekly)
		[ "$diff_days" -ge 7 ]
		;;
	monthly)
		[ "$diff_days" -ge 30 ]
		;;
	*)
		return 1
		;;
	esac
}

configure_periodic_updates() {
	cat <<'EOF'
MyLinuxHelper - Periodic Update Configuration
==============================================

Configure automatic updates to keep MyLinuxHelper up to date.

1. Daily    - Update every day
2. Weekly   - Update every week
3. Monthly  - Update every month
4. Disable  - Turn off automatic updates

EOF

	local current_schedule
	current_schedule="$(get_config_value "SCHEDULE")"

	if [ -n "$current_schedule" ] && [ "$current_schedule" != "disabled" ]; then
		echo "Current setting: $current_schedule"
		echo ""
	fi

	read -rp "Select [1-4]: " SELECTION
	echo ""

	case "$SELECTION" in
	1)
		set_config_value "SCHEDULE" "daily"
		set_config_value "LAST_UPDATE" "$(date +%s)"
		echo "✓ Periodic updates enabled: Daily"
		setup_auto_update_hook
		;;
	2)
		set_config_value "SCHEDULE" "weekly"
		set_config_value "LAST_UPDATE" "$(date +%s)"
		echo "✓ Periodic updates enabled: Weekly"
		setup_auto_update_hook
		;;
	3)
		set_config_value "SCHEDULE" "monthly"
		set_config_value "LAST_UPDATE" "$(date +%s)"
		echo "✓ Periodic updates enabled: Monthly"
		setup_auto_update_hook
		;;
	4)
		set_config_value "SCHEDULE" "disabled"
		echo "✓ Periodic updates disabled"
		;;
	*)
		echo "Invalid selection: $SELECTION"
		exit 1
		;;
	esac

	echo ""
	echo "Configuration saved to: ${UPDATE_CONFIG}"
}

setup_auto_update_hook() {
	local hook_marker="# MyLinuxHelper auto-update check"
	local hook_code="${hook_marker}
if [ -f \"\${HOME}/.mylinuxhelper/plugins/mlh-version.sh\" ]; then
  \"\${HOME}/.mylinuxhelper/plugins/mlh-version.sh\" --check-update 2>/dev/null || true
fi"

	if ! grep -Fq "$hook_marker" "$BASHRC" 2>/dev/null; then
		echo "" >>"$BASHRC"
		echo "$hook_code" >>"$BASHRC"
		echo "✓ Auto-update hook installed in ~/.bashrc"
	fi
}

check_and_update() {
	if should_update_now; then
		echo "Updating MyLinuxHelper..."
		update_to_latest
		set_config_value "LAST_UPDATE" "$(date +%s)"
	fi
}

update_to_latest() {
	echo "Checking for updates from GitHub..."
	echo ""

	if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
		echo "Error: Neither curl nor wget is available. Please install one of them." >&2
		exit 1
	fi

	echo "Current version: ${VERSION}"
	echo "Downloading latest version from GitHub..."
	echo ""

	local temp_script
	temp_script="$(mktemp)"

	if command -v curl &>/dev/null; then
		if ! curl -fsSL "${INSTALL_SCRIPT_URL}" -o "${temp_script}"; then
			echo "Error: Failed to download installation script." >&2
			rm -f "${temp_script}"
			exit 1
		fi
	else
		if ! wget -qO "${temp_script}" "${INSTALL_SCRIPT_URL}"; then
			echo "Error: Failed to download installation script." >&2
			rm -f "${temp_script}"
			exit 1
		fi
	fi

	echo "Running installation script..."
	echo ""

	if bash "${temp_script}"; then
		rm -f "${temp_script}"
		echo ""
		echo "✅ Update completed successfully!"
		echo ""
		echo "Reloading shell to apply changes..."
		echo ""
		
		# Reload the shell to apply new functions and updates
		exec bash -l
	else
		rm -f "${temp_script}"
		echo "Error: Update failed." >&2
		exit 1
	fi
}

main() {
	if [ $# -eq 0 ]; then
		print_version
		exit 0
	fi

	case "$1" in
	-h | --help)
		print_help
		exit 0
		;;
	update | latest)
		# Check for help flag first
		if [ $# -gt 1 ] && [[ "$2" == "-h" || "$2" == "--help" ]]; then
			print_help
		elif [ $# -gt 1 ] && [ "$2" = "-p" ]; then
			configure_periodic_updates
		else
			update_to_latest
			set_config_value "LAST_UPDATE" "$(date +%s)"
		fi
		exit 0
		;;
	-p | --periodic)
		configure_periodic_updates
		exit 0
		;;
	--check-update)
		check_and_update
		exit 0
		;;
	*)
		echo "Error: Unknown command '$1'" >&2
		echo "Run 'mlh --version --help' for usage information." >&2
		exit 1
		;;
	esac
}

main "$@"
