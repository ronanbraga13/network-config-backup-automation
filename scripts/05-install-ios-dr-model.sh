#!/usr/bin/env bash
set -euo pipefail

MODEL_URL="https://raw.githubusercontent.com/ronanbraga13/network-config-backup-automation/main/models/ios.rb"

if [[ $EUID -ne 0 ]]; then
  echo "Execute como root ou com sudo."
  exit 1
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "Ruby não encontrado. Execute primeiro o script 01-install-oxidized.sh."
  exit 1
fi

if ! ruby -e 'Gem::Specification.find_by_name("oxidized")' >/dev/null 2>&1; then
  echo "Oxidized não encontrado. Execute primeiro o script 01-install-oxidized.sh."
  exit 1
fi

OXIDIZED_GEM_PATH="$(ruby -e 'puts Gem::Specification.find_by_name("oxidized").full_gem_path')"
MODEL_DIR="\${OXIDIZED_GEM_PATH}/lib/oxidized/model"
IOS_MODEL="\${MODEL_DIR}/ios.rb"
BACKUP_MODEL="\${MODEL_DIR}/ios.rb.original"

echo "[1/6] Oxidized detectado em: \${OXIDIZED_GEM_PATH}"

if [[ ! -f "\${IOS_MODEL}" ]]; then
  echo "Modelo IOS original não encontrado em \${IOS_MODEL}"
  exit 1
fi

echo "[2/6] Criando backup do modelo IOS original..."
if [[ ! -f "\${BACKUP_MODEL}" ]]; then
  cp "\${IOS_MODEL}" "\${BACKUP_MODEL}"
  echo "Backup criado em: \${BACKUP_MODEL}"
else
  echo "Backup já existe em: \${BACKUP_MODEL}"
fi

TMP_MODEL="$(mktemp)"
trap 'rm -f "\${TMP_MODEL}"' EXIT

echo "[3/6] Baixando modelo IOS DR-ready..."
curl -fsSL "\${MODEL_URL}" -o "\${TMP_MODEL}"

echo "[4/6] Validando sintaxe Ruby..."
ruby -c "\${TMP_MODEL}"

echo "[5/6] Instalando modelo como ios.rb padrão..."
install -m 0644 "\${TMP_MODEL}" "\${IOS_MODEL}"

echo "[6/6] Reiniciando Oxidized..."
systemctl restart oxidized
systemctl status oxidized --no-pager

echo
echo "Modelo IOS DR-ready instalado com sucesso."
echo "Os nodes que usam model 'ios' passam a utilizar automaticamente o modelo customizado."
echo
echo "Para rollback:"
echo "  cp '\${BACKUP_MODEL}' '\${IOS_MODEL}'"
echo "  systemctl restart oxidized"
