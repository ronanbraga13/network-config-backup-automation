#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/oxidized-groups-configure.log"
OX_USER="oxidized"
OX_HOME="/home/$OX_USER"
OX_DIR="$OX_HOME/.config/oxidized"
OX_CONFIG="$OX_DIR/config"
ROUTER_DB="$OX_DIR/router.db"
CONFIGS_DIR="$OX_DIR/configs"
DEFAULT_DIR="$CONFIGS_DIR/default"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\\033[1;32m[OK]\\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\\033[1;33m[WARN]\\033[0m $*" | tee -a "$LOG_FILE"; }
fail() { echo -e "\\033[1;31m[ERROR]\\033[0m $*" | tee -a "$LOG_FILE"; exit 1; }

trap 'fail "Unexpected failure at line $LINENO. Check $LOG_FILE"' ERR

[[ $EUID -eq 0 ]] || fail "Run this script as root or with sudo."
[[ -f "$OX_CONFIG" ]] || fail "Oxidized config not found: $OX_CONFIG"
[[ -f "$ROUTER_DB" ]] || fail "Oxidized inventory not found: $ROUTER_DB"

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_DIR="$OX_DIR/backup-before-groups-$STAMP"

log "Creating backup before grouped configuration"
mkdir -p "$BACKUP_DIR"
cp -a "$OX_CONFIG" "$ROUTER_DB" "$BACKUP_DIR/"
ok "Backup created: $BACKUP_DIR"

echo
echo "Oxidized grouped inventory configuration"
echo "Format: NAME:IP:MODEL:INPUT:GROUP"
echo

TMP_DB="$(mktemp)"
trap 'rm -f "$TMP_DB"' EXIT

while IFS=: read -r NAME IP MODEL INPUT CURRENT_GROUP EXTRA; do
  [[ -z "${NAME:-}" ]] && continue
  [[ "$NAME" =~ ^[[:space:]]*# ]] && { echo "$NAME" >> "$TMP_DB"; continue; }

  if [[ -n "${CURRENT_GROUP:-}" ]]; then
    read -rp "Group for $NAME [$CURRENT_GROUP]: " GROUP
    GROUP="${GROUP:-$CURRENT_GROUP}"
  else
    while true; do
      read -rp "Group for $NAME: " GROUP
      [[ -n "$GROUP" ]] && break
      echo "Group cannot be empty."
    done
  fi

  GROUP="${GROUP// /_}"
  echo "${NAME}:${IP}:${MODEL}:${INPUT}:${GROUP}" >> "$TMP_DB"
done < "$ROUTER_DB"

install -m 600 -o "$OX_USER" -g "$OX_USER" "$TMP_DB" "$ROUTER_DB"
ok "router.db updated with group field"

install -d -m 700 -o "$OX_USER" -g "$OX_USER" "$DEFAULT_DIR"

DEVICE_USER="$(awk -F': ' '/^username:/ {print $2; exit}' "$OX_CONFIG")"
DEVICE_PASS="$(awk -F': ' '/^password:/ {print $2; exit}' "$OX_CONFIG")"
OX_INTERVAL="$(awk -F': ' '/^interval:/ {print $2; exit}' "$OX_CONFIG")"

DEVICE_USER="${DEVICE_USER:-oxidized_backup}"
DEVICE_PASS="${DEVICE_PASS:-CHANGE_ME}"
OX_INTERVAL="${OX_INTERVAL:-86400}"

cat > "$OX_CONFIG" <<EOF
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
models: {}
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
  default: file
  file:
    directory: "${DEFAULT_DIR}"

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
EOF

chmod 600 "$OX_CONFIG"
chown "$OX_USER:$OX_USER" "$OX_CONFIG"
ok "Oxidized config updated for grouped file output"

systemctl restart oxidized
sleep 5

if systemctl is-active --quiet oxidized; then
  ok "Oxidized service is active"
else
  systemctl status oxidized --no-pager -l | tee -a "$LOG_FILE" || true
  fail "Oxidized service failed after grouped configuration."
fi

echo
echo "Grouped configuration completed."
echo "Inventory : $ROUTER_DB"
echo "Output    : $CONFIGS_DIR/<GROUP>/<NODE>"
echo "Backup    : $BACKUP_DIR"
echo "Web UI    : http://SERVER_IP:8888"
echo
echo "Example inventory:"
echo "  FGT-SITE-A:10.0.20.1:fortigate:ssh:CLIENT_A"
echo "  SW-SITE-A:10.0.20.10:ios:telnet:CLIENT_A"
echo
echo "Note:"
echo "  file output keeps the current configuration for each node."
echo "  Each new collection overwrites that node's previous file."
echo "  Use Git output later if version history and diff are required."
