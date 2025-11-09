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

readonly VERSION="1.5.1"
# shellcheck disable=SC2034
readonly VERSION_DATE="09.11.2025"
# shellcheck disable=SC2034
readonly FIRST_RELEASE_DATE="11.10.2025"
readonly GITHUB_REPO="melihcelenk/MyLinuxHelper"
readonly INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/get-mlh.sh"
readonly CONFIG_DIR="${HOME}/.mylinuxhelper"
readonly UPDATE_CONFIG="${CONFIG_DIR}/.update-config"
readonly BASHRC="${HOME}/.bashrc"
readonly PROFILE="${HOME}/.profile"
readonly LOCAL_BIN="${HOME}/.local/bin"
readonly USR_LOCAL_BIN="/usr/local/bin"

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
  mlh --version uninstall    Uninstall MyLinuxHelper

Examples:
  mlh --version              # Display: MyLinuxHelper v1.3.0
  mlh --version update       # Update to latest version from GitHub
  mlh update -p              # Configure automatic periodic updates
  mlh --version uninstall    # Uninstall MyLinuxHelper (with confirmation)
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

uninstall_mlh() {
	echo "MyLinuxHelper Uninstall"
	echo "======================="
	echo ""
	echo "This will remove:"
	echo "  - ~/.mylinuxhelper directory"
	echo "  - Symlinks in ~/.local/bin (bookmark, bm, i, isjsonvalid, ll, linux, mlh, search)"
	echo "  - Symlinks in /usr/local/bin (if installed there)"
	echo "  - MyLinuxHelper entries from ~/.bashrc"
	echo "  - MyLinuxHelper entries from ~/.profile"
	echo ""
	echo "⚠️  WARNING: This action cannot be undone!"
	echo ""

	read -rp "Are you sure you want to uninstall MyLinuxHelper? (type 'yes' to confirm): " CONFIRM
	echo ""

	if [ "$CONFIRM" != "yes" ]; then
		echo "Uninstall cancelled."
		return 0
	fi

	echo "Uninstalling MyLinuxHelper..."
	echo ""

	# Remove symlinks from ~/.local/bin
	local symlinks=("bookmark" "i" "isjsonvalid" "ll" "linux" "mlh" "search")
	local bookmark_alias=""

	# Check if bookmark alias exists in config
	if [ -f "${CONFIG_DIR}/mlh.conf" ]; then
		# shellcheck source=/dev/null
		source "${CONFIG_DIR}/mlh.conf" 2>/dev/null || true
		if [ -n "${BOOKMARK_ALIAS:-}" ]; then
			bookmark_alias="$BOOKMARK_ALIAS"
		fi
	fi

	# Remove symlinks
	for link in "${symlinks[@]}"; do
		local link_path="${LOCAL_BIN}/${link}"
		if [ -L "$link_path" ] || [ -f "$link_path" ]; then
			rm -f "$link_path"
			echo "  Removed: $link_path"
		fi
	done

	# Remove bookmark alias symlink if exists
	if [ -n "$bookmark_alias" ]; then
		local alias_path="${LOCAL_BIN}/${bookmark_alias}"
		if [ -L "$alias_path" ] || [ -f "$alias_path" ]; then
			rm -f "$alias_path"
			echo "  Removed: $alias_path"
		fi
	fi

	# Remove symlinks from /usr/local/bin (if they exist and point to our plugins)
	if [ -d "$USR_LOCAL_BIN" ] && command -v sudo >/dev/null 2>&1; then
		for link in "${symlinks[@]}"; do
			local link_path="${USR_LOCAL_BIN}/${link}"
			if [ -L "$link_path" ]; then
				local target
				target="$(readlink -f "$link_path" 2>/dev/null || readlink "$link_path" 2>/dev/null || echo "")"
				if echo "$target" | grep -q "MyLinuxHelper\|mylinuxhelper"; then
					# shellcheck disable=SC2024
					if sudo rm -f "$link_path" 2>/dev/null; then
						echo "  Removed: $link_path"
					fi
				fi
			fi
		done

		# Remove bookmark alias from /usr/local/bin if exists
		if [ -n "$bookmark_alias" ]; then
			local alias_path="${USR_LOCAL_BIN}/${bookmark_alias}"
			if [ -L "$alias_path" ]; then
				local target
				target="$(readlink -f "$alias_path" 2>/dev/null || readlink "$alias_path" 2>/dev/null || echo "")"
				if echo "$target" | grep -q "MyLinuxHelper\|mylinuxhelper"; then
					# shellcheck disable=SC2024
					if sudo rm -f "$alias_path" 2>/dev/null; then
						echo "  Removed: $alias_path"
					fi
				fi
			fi
		fi
	fi

	# Remove entries from ~/.bashrc
	if [ -f "$BASHRC" ]; then
		local bashrc_backup
		bashrc_backup="${BASHRC}.mlh-backup-$(date +%s)"
		cp "$BASHRC" "$bashrc_backup"
		local temp_bashrc
		temp_bashrc="$(mktemp)"

		# Remove PATH export line
		# shellcheck disable=SC2016
		local path_line='export PATH="$HOME/.local/bin:$PATH"'
		if grep -Fq "$path_line" "$BASHRC" 2>/dev/null; then
			# Check if this is the only PATH modification (safe to remove)
			local path_count
			path_count=$(grep -c 'export PATH=.*\.local/bin' "$BASHRC" 2>/dev/null || echo "0")
			if [ "$path_count" -eq 1 ]; then
				grep -vF "$path_line" "$BASHRC" >"$temp_bashrc" 2>/dev/null || cp "$BASHRC" "$temp_bashrc"
				mv "$temp_bashrc" "$BASHRC"
				echo "  Removed PATH export from ~/.bashrc"
			else
				echo "  Note: Multiple PATH entries found, not removing (manual cleanup may be needed)"
			fi
		fi

		# Remove mlh wrapper function (using Python for reliable multiline removal)
		local mlh_marker="# MyLinuxHelper - mlh wrapper function"
		if grep -Fq "$mlh_marker" "$BASHRC" 2>/dev/null; then
			if command -v python3 >/dev/null 2>&1; then
				python3 - "$BASHRC" "$mlh_marker" <<'PYEOF'
import sys

bashrc_file = sys.argv[1]
marker = sys.argv[2]

with open(bashrc_file, 'r') as f:
    lines = f.readlines()

output = []
in_block = False
brace_count = 0
skip_next_empty = False

for i, line in enumerate(lines):
    if not in_block:
        if marker in line:
            in_block = True
            brace_count = 0
            skip_next_empty = (i > 0 and lines[i-1].strip() == '')
            continue
        else:
            output.append(line)
    else:
        brace_count += line.count('{') - line.count('}')
        if line.strip() == '}' and brace_count <= 0:
            in_block = False
            if skip_next_empty and output and output[-1].strip() == '':
                output.pop()
            continue

with open(bashrc_file, 'w') as f:
    f.writelines(output)
PYEOF
				echo "  Removed mlh wrapper function from ~/.bashrc"
			else
				# Fallback: simple sed (may not work perfectly for nested braces)
				sed -i.bak "/${mlh_marker}/,/^}$/d" "$BASHRC" 2>/dev/null || true
				echo "  Removed mlh wrapper function from ~/.bashrc (fallback method)"
			fi
		fi

		# Remove bookmark wrapper function
		local bookmark_marker="# MyLinuxHelper - bookmark wrapper function"
		if grep -Fq "$bookmark_marker" "$BASHRC" 2>/dev/null; then
			if command -v python3 >/dev/null 2>&1; then
				python3 - "$BASHRC" "$bookmark_marker" <<'PYEOF'
import sys

bashrc_file = sys.argv[1]
marker = sys.argv[2]

with open(bashrc_file, 'r') as f:
    lines = f.readlines()

output = []
in_block = False
brace_count = 0
skip_next_empty = False

for i, line in enumerate(lines):
    if not in_block:
        if marker in line:
            in_block = True
            brace_count = 0
            skip_next_empty = (i > 0 and lines[i-1].strip() == '')
            continue
        else:
            output.append(line)
    else:
        brace_count += line.count('{') - line.count('}')
        if line.strip() == '}' and brace_count <= 0:
            in_block = False
            if skip_next_empty and output and output[-1].strip() == '':
                output.pop()
            continue

with open(bashrc_file, 'w') as f:
    f.writelines(output)
PYEOF
				echo "  Removed bookmark wrapper function from ~/.bashrc"
			else
				sed -i.bak "/${bookmark_marker}/,/^}$/d" "$BASHRC" 2>/dev/null || true
				echo "  Removed bookmark wrapper function from ~/.bashrc (fallback method)"
			fi
		fi

		# Remove bookmark alias wrapper function if exists
		if [ -n "$bookmark_alias" ]; then
			local alias_marker="# MyLinuxHelper - ${bookmark_alias} alias wrapper"
			if grep -Fq "$alias_marker" "$BASHRC" 2>/dev/null; then
				if command -v python3 >/dev/null 2>&1; then
					python3 - "$BASHRC" "$alias_marker" <<'PYEOF'
import sys

bashrc_file = sys.argv[1]
marker = sys.argv[2]

with open(bashrc_file, 'r') as f:
    lines = f.readlines()

output = []
in_block = False
brace_count = 0
skip_next_empty = False

for i, line in enumerate(lines):
    if not in_block:
        if marker in line:
            in_block = True
            brace_count = 0
            skip_next_empty = (i > 0 and lines[i-1].strip() == '')
            continue
        else:
            output.append(line)
    else:
        brace_count += line.count('{') - line.count('}')
        if line.strip() == '}' and brace_count <= 0:
            in_block = False
            if skip_next_empty and output and output[-1].strip() == '':
                output.pop()
            continue

with open(bashrc_file, 'w') as f:
    f.writelines(output)
PYEOF
					echo "  Removed ${bookmark_alias} alias wrapper from ~/.bashrc"
				else
					sed -i.bak "/${alias_marker}/,/^}$/d" "$BASHRC" 2>/dev/null || true
					echo "  Removed ${bookmark_alias} alias wrapper from ~/.bashrc (fallback method)"
				fi
			fi
		fi

		# Remove auto-update hook
		local update_marker="# MyLinuxHelper auto-update check"
		if grep -Fq "$update_marker" "$BASHRC" 2>/dev/null; then
			if command -v python3 >/dev/null 2>&1; then
				python3 - "$BASHRC" "$update_marker" <<'PYEOF'
import sys

bashrc_file = sys.argv[1]
marker = sys.argv[2]

with open(bashrc_file, 'r') as f:
    lines = f.readlines()

output = []
in_block = False
skip_next_empty = False

for i, line in enumerate(lines):
    if not in_block:
        if marker in line:
            in_block = True
            skip_next_empty = (i > 0 and lines[i-1].strip() == '')
            continue
        else:
            output.append(line)
    else:
        if line.strip() == 'fi':
            in_block = False
            if skip_next_empty and output and output[-1].strip() == '':
                output.pop()
            continue

with open(bashrc_file, 'w') as f:
    f.writelines(output)
PYEOF
				echo "  Removed auto-update hook from ~/.bashrc"
			else
				sed -i.bak "/${update_marker}/,/^fi$/d" "$BASHRC" 2>/dev/null || true
				echo "  Removed auto-update hook from ~/.bashrc (fallback method)"
			fi
		fi

		# Clean up temp and backup files
		rm -f "$temp_bashrc" 2>/dev/null || true
		rm -f "${BASHRC}.bak" 2>/dev/null || true
		rm -f "$bashrc_backup" 2>/dev/null || true
	fi

	# Remove entries from ~/.profile
	if [ -f "$PROFILE" ]; then
		# shellcheck disable=SC2016
		local path_line='export PATH="$HOME/.local/bin:$PATH"'
		if grep -Fq "$path_line" "$PROFILE" 2>/dev/null; then
			# Check if this is the only PATH modification (safe to remove)
			local path_count
			path_count=$(grep -c 'export PATH=.*\.local/bin' "$PROFILE" 2>/dev/null || echo "0")
			if [ "$path_count" -eq 1 ]; then
				sed -i.bak "\|${path_line}|d" "$PROFILE" 2>/dev/null || true
				echo "  Removed PATH export from ~/.profile"
				rm -f "${PROFILE}.bak" 2>/dev/null || true
			else
				echo "  Note: Multiple PATH entries found in ~/.profile, not removing (manual cleanup may be needed)"
			fi
		fi
	fi

	# Remove ~/.mylinuxhelper directory
	if [ -d "$CONFIG_DIR" ]; then
		rm -rf "$CONFIG_DIR"
		echo "  Removed: ~/.mylinuxhelper"
	fi

	echo ""
	echo "✅ Uninstall completed successfully!"
	echo ""
	echo "Note: You may need to restart your terminal or run 'source ~/.bashrc' to apply changes."
	echo ""
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
	uninstall)
		uninstall_mlh
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
