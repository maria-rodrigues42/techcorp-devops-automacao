#!/usr/bin/env bash
#
# master-setup.sh - Script MESTRE que configura todas as VMs automaticamente
#
# Uso: ./master-setup.sh
#
# Este script roda no HOST e configura todas as máquinas virtuais
# usando a pasta compartilhada do VirtualBox.
#
set -uo pipefail

# ================== Cores ==================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[AVISO]${NC} $*"; }
err()   { echo -e "${RED}[ERRO]${NC} $*" >&2; }

# ================== Verificar se é root ==================
if [[ "$(id -u)" -ne 0 ]]; then
  err "Execute como root: sudo ./master-setup.sh"
  exit 1
fi

# ================== Diretório dos scripts ==================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  TechCorp - Setup Mestre de Automação${NC}"
echo -e "${CYAN}  Configura todas as VMs automaticamente${NC}"
echo -e "${CYAN}============================================${NC}"
echo

# ================== Verificar VMs ==================
log "Verificando máquinas virtuais..."
VM_LIST=$(VBoxManage list runningvms 2>/dev/null | awk -F'"' '{print $2}')

for VM in gateway dns dbserver gitlab operacao webserver dev01 dev02; do
  if echo "$VM_LIST" | grep -q "^${VM}$"; then
    ok "VM ${VM} está rodando"
  else
    warn "VM ${VM} não está rodando (será pulada)"
  fi
done

echo

# ================== Criar pasta compartilhada ==================
log "Preparando pasta compartilhada..."

# Criar pasta temporária para compartilhar
SHARED_DIR="/tmp/techcorp-shared"
rm -rf "$SHARED_DIR"
mkdir -p "$SHARED_DIR"

# Copiar todos os scripts para a pasta compartilhada
cp "$SCRIPT_DIR"/setup-*.sh "$SHARED_DIR/"
cp "$SCRIPT_DIR"/verificar-tudo.sh "$SHARED_DIR/"
cp "$SCRIPT_DIR"/atualizar-app.sh "$SHARED_DIR/"
chmod +x "$SHARED_DIR"/*.sh

ok "Scripts copiados para pasta compartilhada"

# ================== Função para executar comando na VM ==================
run_in_vm() {
  local vm_name="$1"
  local command="$2"
  local timeout="${3:-60}"

  # Encontrar o UUID da VM
  local vm_uuid=$(VBoxManage list vms 2>/dev/null | grep "\"${vm_name}\"" | awk '{print $2}' | tr -d '{}')

  if [[ -z "$vm_uuid" ]]; then
    err "VM ${vm_name} não encontrada"
    return 1
  fi

  # Tentar via SSH (se disponível)
  # Primeiro, tentar com a chave SSH que já existe
  local vm_ip=""
  case "$vm_name" in
    gateway)     vm_ip="192.168.13.101" ;;
    dns)         vm_ip="192.168.13.53"  ;;
    dbserver)    vm_ip="192.168.13.130" ;;
    gitlab)      vm_ip="192.168.13.100" ;;
    operacao)    vm_ip="192.168.13.151" ;;
    webserver)   vm_ip="192.168.13.140" ;;
    dev01)       vm_ip="192.168.13.201" ;;
    dev02)       vm_ip="192.168.13.202" ;;
  esac

  # Tentar SSH
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    "sysadmin@${vm_ip}" "$command" 2>/dev/null; then
    return 0
  fi

  return 1
}

# ================== Função para copiar e executar ==================
setup_vm() {
  local vm_name="$1"
  local script_name="$2"
  local vm_ip="$3"

  log "Configurando ${vm_name}..."

  # Tentar copiar script via SSH
  if scp -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    "$SHARED_DIR/${script_name}" "sysadmin@${vm_ip}:~/" 2>/dev/null; then

    # Executar o script
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      "sysadmin@${vm_ip}" "chmod +x ~/${script_name} && sudo ./${script_name}" 2>/dev/null; then
      ok "${vm_name} configurado com sucesso!"
      return 0
    fi
  fi

  # Se SSH não funcionar, avisar
  warn "Não foi possível acessar ${vm_name} via SSH"
  echo "    Execute manualmente: sudo ./${script_name}"
  return 1
}

# ================== Verificar conectividade ==================
log "Testando conectividade com as VMs..."
echo

CONNECTED=0
for VM in gateway dns dbserver gitlab operacao webserver dev01 dev02; do
  case "$VM" in
    gateway)   IP="192.168.13.101" ;;
    dns)       IP="192.168.13.53"  ;;
    dbserver)  IP="192.168.13.130" ;;
    gitlab)    IP="192.168.13.100" ;;
    operacao)  IP="192.168.13.151" ;;
    webserver) IP="192.168.13.140" ;;
    dev01)     IP="192.168.13.201" ;;
    dev02)     IP="192.168.13.202" ;;
  esac

  if ping -c1 -W2 "$IP" >/dev/null 2>&1; then
    ok "${VM} (${IP}) responde ao ping"
    CONNECTED=$((CONNECTED + 1))
  else
    warn "${VM} (${IP}) não responde ao ping"
  fi
done

echo

if [[ $CONNECTED -eq 0 ]]; then
  err "Nenhuma VM está respondendo na rede interna!"
  echo
  echo "Possíveis soluções:"
  echo "  1. Verifique se as VMs estão na mesma rede interna (intnet)"
  echo "  2. Execute o setup-rede-host.sh primeiro"
  echo "  3. Configure a rede dentro de cada VM manualmente"
  echo
  echo "Scripts copiados para: ${SHARED_DIR}"
  echo "Copie-os para dentro de cada VM e execute manualmente."
  echo
  exit 1
fi

# ================== Configurar VMs ==================
echo
log "Iniciando configuração das VMs..."
echo

# Ordem: Gateway → DNS → DB Server → GitLab → Webserver → Operação → Dev01 → Dev02

# 1. Gateway
if ping -c1 -W2 192.168.13.101 >/dev/null 2>&1; then
  setup_vm "gateway" "setup-gateway.sh" "192.168.13.101"
else
  warn "Pulando Gateway (offline)"
fi

echo

# DNS
if ping -c1 -W2 192.168.13.53 >/dev/null 2>&1; then
  setup_vm "dns" "setup-dns.sh" "192.168.13.53"
else
  warn "Pulando DNS (offline)"
fi

echo

# DB Server
if ping -c1 -W2 192.168.13.130 >/dev/null 2>&1; then
  setup_vm "dbserver" "setup-dbserver.sh" "192.168.13.130"
else
  warn "Pulando DB Server (offline)"
fi

echo

# GitLab
if ping -c1 -W2 192.168.13.100 >/dev/null 2>&1; then
  setup_vm "gitlab" "setup-gitlab.sh" "192.168.13.100"
else
  warn "Pulando GitLab (offline)"
fi

echo

# Webserver
if ping -c1 -W2 192.168.13.140 >/dev/null 2>&1; then
  setup_vm "webserver" "setup-webserver.sh" "192.168.13.140"
else
  warn "Pulando Webserver (offline)"
fi

echo

# 2. Operação
if ping -c1 -W2 192.168.13.151 >/dev/null 2>&1; then
  setup_vm "operacao" "setup-operacao.sh" "192.168.13.151"
else
  warn "Pulando Operação (offline)"
fi

echo

# 3. Dev01
if ping -c1 -W2 192.168.13.201 >/dev/null 2>&1; then
  setup_vm "dev01" "setup-dev01.sh" "192.168.13.201"
else
  warn "Pulando Dev01 (offline)"
fi

echo

# 4. Dev02
if ping -c1 -W2 192.168.13.202 >/dev/null 2>&1; then
  setup_vm "dev02" "setup-dev02.sh" "192.168.13.202"
else
  warn "Pulando Dev02 (offline)"
fi

echo

# ================== Resultado ==================
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  CONFIGURAÇÃO CONCLUÍDA!${NC}"
echo -e "${CYAN}============================================${NC}"
echo
echo "Scripts copiados para: ${SHARED_DIR}"
echo
echo "Se alguma VM não foi configurada automaticamente:"
echo "  1. Acesse a VM (via VirtualBox)"
echo "  2. Copie o script da pasta compartilhada"
echo "  3. Execute: sudo ./{script}"
echo
echo "Para verificar se tudo está funcionando:"
echo "  ./verificar-tudo.sh"
echo
