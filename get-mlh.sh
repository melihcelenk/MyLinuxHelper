#!/usr/bin/env bash
set -euo pipefail

# ====== Your repo ======
REPO_OWNER="melihcelenk"
REPO_NAME="MyLinuxHelper"
REPO_BRANCH="main"
# =======================

REPO_TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REPO_BRANCH}"
REPO_GIT_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

INSTALL_DIR="${HOME}/.mylinuxhelper"
LOCAL_BIN="${HOME}/.local/bin"
BASHRC="${HOME}/.bashrc"
PROFILE="${HOME}/.profile"

green() { printf "\033[1;32m%s\033[0m\n" "$*"; }

ensure_downloader() {
  if command -v curl >/dev/null 2>&1; then echo curl; return; fi
  if command -v wget >/dev/null 2>&1; then echo wget; return; fi

  echo "No curl/wget found. Trying to install curl..."
  if command -v apt >/dev/null 2>&1; then sudo apt update -y && sudo apt install -y curl
  elif command -v apt-get >/dev/null 2>&1; then sudo apt-get update -y && sudo apt-get install -y curl
  elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y curl
  elif command -v yum >/dev/null 2>&1; then sudo yum install -y curl
  elif command -v zypper >/dev/null 2>&1; then sudo zypper install -y curl
  elif command -v pacman >/dev/null 2>&1; then sudo pacman -Sy --noconfirm curl
  elif command -v apk >/dev/null 2>&1; then sudo apk add curl
  else
    echo "Error: no downloader and no supported package manager. Install curl or wget manually."
    exit 1
  fi

  command -v curl >/dev/null 2>&1 && { echo curl; return; }
  command -v wget >/dev/null 2>&1 && { echo wget; return; }
  echo "Error: failed to install a downloader."; exit 1
}

download_repo() {
  mkdir -p "${INSTALL_DIR}"
  if command -v git >/dev/null 2>&1; then
    if [ -d "${INSTALL_DIR}/.git" ]; then
      green "Updating repo (git pull)…"
      git -C "${INSTALL_DIR}" fetch --all --depth=1
      git -C "${INSTALL_DIR}" checkout "${REPO_BRANCH}"
      git -C "${INSTALL_DIR}" reset --hard "origin/${REPO_BRANCH}"
    else
      green "Cloning repo (git)…"
      git clone --depth=1 --branch "${REPO_BRANCH}" "${REPO_GIT_URL}" "${INSTALL_DIR}"
    fi
  else
    green "Downloading repo (tarball)…"
    rm -rf "${INSTALL_DIR}.tmp"
    mkdir -p "${INSTALL_DIR}.tmp"
    local dlr; dlr="$(ensure_downloader)"
    if [ "$dlr" = "curl" ]; then
      curl -fsSL "${REPO_TARBALL_URL}" | tar -xz -C "${INSTALL_DIR}.tmp"
    else
      wget -qO- "${REPO_TARBALL_URL}" | tar -xz -C "${INSTALL_DIR}.tmp"
    fi
    rm -rf "${INSTALL_DIR}"
    mv "${INSTALL_DIR}.tmp/${REPO_NAME}-${REPO_BRANCH}" "${INSTALL_DIR}"
    rm -rf "${INSTALL_DIR}.tmp"
  fi
}

ensure_local_bin_on_path() {
  mkdir -p "${LOCAL_BIN}"
  local line='export PATH="$HOME/.local/bin:$PATH"'
  grep -Fq "$line" "$BASHRC" 2>/dev/null || echo "$line" >> "$BASHRC"
  grep -Fq "$line" "$PROFILE" 2>/dev/null || echo "$line" >> "$PROFILE"
}

run_repo_setup() {
  green "Running repository setup…"
  chmod +x "${INSTALL_DIR}/setup.sh" || true
  bash "${INSTALL_DIR}/setup.sh"
}

main() {
  green "Installing ${REPO_NAME} into ${INSTALL_DIR}"
  download_repo
  ensure_local_bin_on_path
  run_repo_setup
  green "Done. Try:"
  echo "  i --help"
  echo "  isjsonvalid --help"
  echo "  ll /etc"
}
main "$@"
