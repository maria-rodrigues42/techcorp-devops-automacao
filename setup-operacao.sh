#!/usr/bin/env bash
#
# setup-operacao.sh - Configuração completa da máquina de OPERAÇÃO
#
# IP: 192.168.13.151
# Função: Control node Ansible (provisiona e faz deploy de tudo)
#
# Uso: sudo ./setup-operacao.sh
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.151"
NETMASK="255.255.255.0"
GW_IP="192.168.13.101"
OP_IP="192.168.13.151"
DEV01_IP="192.168.13.201"
DEV02_IP="192.168.13.202"
HOMOLOGACAO_IP="192.168.13.150"
DOMAIN="techcorp.com.br"
ADMIN="sysadmin"
DNS1="8.8.8.8"
DNS2="1.1.1.1"

# ================== Cores ==================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[AVISO]${NC} $*"; }
err()   { echo -e "${RED}[ERRO]${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

# ================== Verificar root ==================
if [[ "$(id -u)" -ne 0 ]]; then
  die "Execute como root: sudo ./setup-operacao.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup OPERAÇÃO"
echo "  IP: $IP"
echo "  Função: Control Node Ansible"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/8 - Configurando rede..."

LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)

cat > /etc/network/interfaces << EOF
# TechCorp Operacao - Configuração de Rede
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

# LAN - Rede interna
auto ${LAN_IFACE}
iface ${LAN_IFACE} inet static
    address ${IP}
    netmask ${NETMASK}
    gateway ${GW_IP}
EOF

ok "Rede configurada"

# ================== 2. Hostname ==================
log "2/8 - Configurando hostname..."
echo "operacao" > /etc/hostname
hostnamectl set-hostname operacao 2>/dev/null || hostname operacao

# ================== 3. /etc/hosts ==================
log "3/8 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${IP}       operacao.${DOMAIN}  operacao
${GW_IP}    gateway.${DOMAIN}   gateway
${DEV01_IP} dev01.${DOMAIN}     dev01
${DEV02_IP} dev02.${DOMAIN}     dev02
${HOMOLOGACAO_IP} homologacao.${DOMAIN} homologacao
EOF

ok "/etc/hosts configurado"

# ================== 4. DNS ==================
log "4/8 - Configurando DNS..."
cat > /etc/resolv.conf << EOF
nameserver ${DNS1}
nameserver ${DNS2}
EOF

ok "DNS configurado"

# ================== 5. Usuário ==================
log "5/8 - Criando usuário ${ADMIN}..."
if ! id "$ADMIN" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$ADMIN"
fi
echo "${ADMIN} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${ADMIN}"
chmod 440 "/etc/sudoers.d/${ADMIN}"
ok "Usuário ${ADMIN} criado"

# ================== 6. SSH ==================
log "6/8 - Configurando SSH..."
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server curl git >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null

SSH_DIR="/home/${ADMIN}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Gerar chave se não existir
if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
  ssh-keygen -t rsa -b 4096 -C "operacao@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi

# Copiar chave para as outras máquinas (quando elas estiverem no ar)
for HOST in "$DEV01_IP" "$DEV02_IP" "$HOMOLOGACAO_IP"; do
  log "  Copiando chave para ${HOST}..."
  ssh-copy-id -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${ADMIN}@${HOST}" 2>/dev/null && \
    ok "  Chave copiada para ${HOST}" || \
    warn "  Não foi possível copiar chave para ${HOST} (máquina pode não estar no ar)"
done

ok "SSH configurado"

# ================== 7. Docker ==================
log "7/8 - Instalando Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
  systemctl enable --now docker
  usermod -aG docker "$ADMIN"
fi
ok "Docker instalado"

# ================== 8. Ansible ==================
log "8/8 - Instalando Ansible..."
if ! command -v ansible >/dev/null 2>&1; then
  apt-get install -y ansible >/dev/null 2>&1
fi

# Criar inventário
mkdir -p "/home/${ADMIN}/ansible"
cat > "/home/${ADMIN}/ansible/inventory" << EOF
[dev_machines]
dev01 ansible_host=${DEV01_IP} ansible_user=${ADMIN}
dev02 ansible_host=${DEV02_IP} ansible_user=${ADMIN}

[homologacao]
homologacao ansible_host=${HOMOLOGACAO_IP} ansible_user=${ADMIN}

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=/home/${ADMIN}/.ssh/id_rsa
EOF

chown -R "${ADMIN}:${ADMIN}" "/home/${ADMIN}/ansible"
ok "Ansible instalado"

# ================== Verificação ==================
echo
echo "=========================================="
echo "  OPERAÇÃO CONFIGURADA!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  Gateway: $GW_IP"
echo
echo "Serviços:"
echo "  SSH: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)"
echo "  Docker: $(systemctl is-active docker)"
echo "  Ansible: $(ansible --version 2>/dev/null | head -1)"
echo
echo "Máquinas no /etc/hosts:"
grep -E "dev0|operacao|gateway|homologacao" /etc/hosts | awk '{print "  " $1 " → " $2}'
echo
echo "Inventário Ansible: /home/${ADMIN}/ansible/inventory"
echo
echo "Próximos passos:"
echo "  1. Execute setup-dev01.sh na máquina Dev01"
echo "  2. Execute setup-dev02.sh na máquina Dev02"
echo "  3. Execute setup-homologacao.sh na máquina de Homologação"
echo "  4. Depois, volte aqui e rode os playbooks Ansible"
echo
