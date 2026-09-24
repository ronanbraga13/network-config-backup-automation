#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/oxidized-groups-git-files-configure.log"

OX_USER="oxidized"
OX_HOME="/home/$OX_USER"
OX_DIR="$OX_HOME/.config/oxidized"
OX_CONFIG="$OX_DIR/config"
ROUTER_DB="$OX_DIR/router.db"
SERVICE_FILE="/etc/systemd/system/oxidized.service"

GIT_DIR="$OX_DIR/git-repos"
DEFAULT_GIT_REPO="$GIT_DIR/default.git"

CONFIGS_DIR="$OX_DIR/configs"
EXPORT_SCRIPT="$OX_DIR/export-current-file.sh"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
fail() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; exit 1; }

trap 'fail "Unexpected failure at line $LINENO. Check $LOG_FILE"' ERR

[[ $EUID -eq 0 ]] || fail "Run this script as root or with sudo."

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

command -v oxidized >/dev/null 2>&1 ||   fail "Oxidized is not installed. Run 01-install-oxidized.sh first."

gem list -i oxidized-web >/dev/null 2>&1 ||   fail "oxidized-web is not installed. Run 01-install-oxidized.sh first."

command -v git >/dev/null 2>&1 || fail "Git is not installed."

echo
echo "Oxidized grouped Git + Files configuration"
echo
echo "This script is independent from 02 and 03."
echo "Required flow: 01-install-oxidized.sh -> this script"
echo

read -rp "Default device username [oxidized_backup]: " DEVICE_USER
DEVICE_USER="${DEVICE_USER:-oxidized_backup}"

while true; do
  read -rsp "Default device password: " DEVICE_PASS
  echo
  [[ -n "$DEVICE_PASS" ]] && break
  echo "Password cannot be empty."
done

read -rp "Collection interval in seconds [86400]: " OX_INTERVAL
OX_INTERVAL="${OX_INTERVAL:-86400}"
[[ "$OX_INTERVAL" =~ ^[0-9]+$ ]] || fail "Interval must be numeric."

if id "$OX_USER" >/dev/null 2>&1; then
  ok "Service user $OX_USER already exists"
else
  useradd -m -s /bin/bash "$OX_USER"
  ok "Service user $OX_USER created"
fi

install -d -m 700 -o "$OX_USER" -g "$OX_USER"   "$OX_DIR"   "$OX_DIR/crashes"   "$OX_DIR/logs"   "$GIT_DIR"   "$CONFIGS_DIR"

STAMP="$(date '+%Y%m%d-%H%M%S')"

[[ -f "$OX_CONFIG" ]] && cp -a "$OX_CONFIG" "${OX_CONFIG}.bak-${STAMP}"
[[ -f "$ROUTER_DB" ]] && cp -a "$ROUTER_DB" "${ROUTER_DB}.bak-${STAMP}"
[[ -f "$EXPORT_SCRIPT" ]] && cp -a "$EXPORT_SCRIPT" "${EXPORT_SCRIPT}.bak-${STAMP}"

cat >"$EXPORT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/oxidized/.config/oxidized"
CONFIGS_DIR="$BASE/configs"

NODE="${OX_NODE_NAME:-}"
GROUP="${OX_NODE_GROUP:-default}"
REPO="${OX_REPO_NAME:-}"
COMMIT="${OX_REPO_COMMITREF:-}"

[[ -n "$NODE" ]] || exit 1
[[ -n "$GROUP" ]] || GROUP="default"
[[ -n "$REPO" ]] || exit 1
[[ -n "$COMMIT" ]] || exit 1

DEST_DIR="$CONFIGS_DIR/$GROUP"
TMP_FILE="$DEST_DIR/.${NODE}.tmp"
DEST_FILE="$DEST_DIR/$NODE"

mkdir -p "$DEST_DIR"

git --bare --git-dir="$REPO"   show --pretty='' --no-color "$COMMIT:$NODE" > "$TMP_FILE"

mv "$TMP_FILE" "$DEST_FILE"
EOF

chmod 700 "$EXPORT_SCRIPT"
chown "$OX_USER:$OX_USER" "$EXPORT_SCRIPT"

cat >"$OX_CONFIG" <<EOF
---
username: ${DEVICE_USER}
password: ${DEVICE_PASS}
resolve_dns: false
interval: ${OX_INTERVAL}
debug: false
run_once: false
threads: 30
use_max_threads: false
timeout: 20
timelimit: 300
retries: 3
next_adds_job: false
vars: {}
groups: {}
group_map: {}

models:
  fortigate:
    vars:
      fullconfig: true

pid: "${OX_DIR}/pid"

extensions:
  oxidized-web:
    load: true
    listen: 0.0.0.0
    port: 8888

crash:
  directory: "${OX_DIR}/crashes"
  hostnames: false

stats:
  history_size: 10

input:
  default: ssh
  debug: false
  ssh:
    secure: false
  utf8_encoded: true

output:
  default: git
  git:
    user: Oxidized
    email: oxidized@localhost
    repo: "${DEFAULT_GIT_REPO}"

source:
  default: csv
  csv:
    file: "${ROUTER_DB}"
    delimiter: !ruby/regexp /:/
    map:
      name: 0
      ip: 1
      model: 2
      input: 3
      group: 4

hooks:
  export_current_file:
    type: exec
    events: [post_store]
    cmd: "${EXPORT_SCRIPT}"
    timeout: 30
EOF

chmod 600 "$OX_CONFIG"
chown "$OX_USER:$OX_USER" "$OX_CONFIG"

echo
echo "Add grouped nodes using this format:"
echo "  NAME:IP:MODEL:INPUT:GROUP"
echo
echo "Examples:"
echo "  FGT-SITE-A:10.0.20.1:fortigate:ssh:GRP_SITE_A"
echo "  PFSENSE-SITE-B:10.20.20.1:pfsense:ssh:GRP_SITE_B"
echo "  SW-SITE-B:10.20.20.10:ios:telnet:GRP_SITE_B"
echo

: >"$ROUTER_DB"

while true; do
  read -rp "Node name: " NODE_NAME
  [[ -n "$NODE_NAME" ]] || { echo "Node name cannot be empty."; continue; }

  read -rp "Management IP: " NODE_IP
  [[ -n "$NODE_IP" ]] || { echo "IP cannot be empty."; continue; }

  read -rp "Oxidized model [fortigate]: " NODE_MODEL
  NODE_MODEL="${NODE_MODEL:-fortigate}"

  read -rp "Input protocol [ssh]: " NODE_INPUT
  NODE_INPUT="${NODE_INPUT:-ssh}"

  case "$NODE_INPUT" in
    ssh|telnet) ;;
    *) echo "Input must be ssh or telnet."; continue ;;
  esac

  read -rp "Group name: " NODE_GROUP
  [[ -n "$NODE_GROUP" ]] || { echo "Group cannot be empty."; continue; }
  NODE_GROUP="${NODE_GROUP// /_}"

  echo "${NODE_NAME}:${NODE_IP}:${NODE_MODEL}:${NODE_INPUT}:${NODE_GROUP}"     >>"$ROUTER_DB"

  ok "Added: $NODE_NAME -> $NODE_GROUP"

  read -rp "Add another node? [y/N]: " ADD_MORE
  case "$ADD_MORE" in
    y|Y|yes|YES) ;;
    *) break ;;
  esac
done

chmod 600 "$ROUTER_DB"
chown "$OX_USER:$OX_USER" "$ROUTER_DB"

cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Oxidized Network Configuration Backup
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${OX_USER}
Group=${OX_USER}
Environment=HOME=${OX_HOME}
WorkingDirectory=${OX_HOME}
ExecStart=/usr/local/bin/oxidized
Restart=on-failure
RestartSec=5
UMask=0077

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable oxidized >/dev/null 2>&1
systemctl restart oxidized

sleep 5

if systemctl is-active --quiet oxidized; then
  ok "Oxidized service is active"
else
  systemctl status oxidized --no-pager -l | tee -a "$LOG_FILE" || true
  fail "Oxidized service failed to remain active."
fi

if ss -lnt 2>/dev/null | grep -q ':8888'; then
  ok "Web UI is listening on TCP/8888"
else
  warn "TCP/8888 is not listening yet. Check journalctl -u oxidized."
fi

echo
echo "Configuration completed."
echo "Config       : $OX_CONFIG"
echo "Inventory    : $ROUTER_DB"
echo "Git history  : $GIT_DIR/<GROUP>.git"
echo "Current file : $CONFIGS_DIR/<GROUP>/<NODE>"
echo "Web          : http://SERVER_IP:8888"
echo
echo "Inventory format:"
echo "  NAME:IP:MODEL:INPUT:GROUP"
echo
echo "Important FortiGate note:"
echo "  This script enables fullconfig for the FortiGate model."
echo "  The collected configuration is still limited by the permissions"
echo "  of the account used by Oxidized."
echo "  Validate administrative visibility and restore behavior before"
echo "  treating the result as a complete disaster-recovery backup."
echo "  In production, privileged accounts must follow your security policy,"
echo "  including source restrictions/trusted hosts where applicable."
echo
echo "Vendor note:"
echo "  pfSense restore was validated in this lab."
echo "  Other vendors/models should be restore-tested before production use."
