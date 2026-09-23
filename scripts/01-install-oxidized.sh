#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/oxidized-install.log"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
fail() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; exit 1; }

run_step() {
  local desc="$1"; shift
  log "$desc"
  if "$@" >>"$LOG_FILE" 2>&1; then
    ok "$desc"
  else
    fail "$desc. Check $LOG_FILE"
  fi
}

trap 'fail "Unexpected failure at line $LINENO. Check $LOG_FILE"' ERR

[[ $EUID -eq 0 ]] || fail "Run this script as root or with sudo."

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

[[ -r /etc/os-release ]] || fail "Unable to identify operating system."
source /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] || fail "Unsupported OS: ${PRETTY_NAME:-unknown}"

VERSION="${VERSION_ID:-0}"
if ! dpkg --compare-versions "$VERSION" ge "22.04"; then
  fail "Ubuntu $VERSION detected. Ubuntu Server 22.04 LTS or newer is required."
fi

ok "OS validated: ${PRETTY_NAME}"

run_step "apt update" apt-get update
run_step "apt upgrade" env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

PACKAGES=(
  ruby ruby-dev
  libsqlite3-dev libssl-dev pkg-config cmake libssh2-1-dev
  libicu-dev zlib1g-dev g++ libyaml-dev libzstd-dev
  git vim
)

run_step "Installing Oxidized dependencies"   env DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"

run_step "Installing Oxidized" gem install oxidized --no-document
run_step "Installing oxidized-web" gem install oxidized-web --no-document

command -v oxidized >/dev/null 2>&1 || fail "Oxidized binary not found."
gem list -i oxidized-web >/dev/null 2>&1 || fail "oxidized-web gem not found."

ok "Oxidized installed: $(oxidized --version 2>&1 | head -n 1)"
ok "oxidized-web installed: $(gem list '^oxidized-web$' | head -n 1)"

echo
echo "Installation completed."
echo "Log: $LOG_FILE"
echo "Next: scripts/02-configure-oxidized.sh"
