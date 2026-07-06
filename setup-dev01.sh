#!/usr/bin/env bash
#
# setup-dev01.sh - Configuração completa da máquina DEV01
#
# IP: 192.168.13.201
# Função: Desenvolvimento Backend
#
# Uso: sudo ./setup-dev01.sh
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.201"
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
  die "Execute como root: sudo ./setup-dev01.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup DEV01"
echo "  IP: $IP"
echo "  Função: Desenvolvimento Backend"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/9 - Configurando rede..."

LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)

cat > /etc/network/interfaces << EOF
# TechCorp Dev01 - Configuração de Rede
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
log "2/9 - Configurando hostname..."
echo "dev01" > /etc/hostname
hostnamectl set-hostname dev01 2>/dev/null || hostname dev01

# ================== 3. /etc/hosts ==================
log "3/9 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${IP}       dev01.${DOMAIN}     dev01
${GW_IP}    gateway.${DOMAIN}   gateway
${OP_IP}    operacao.${DOMAIN}  operacao
${DEV02_IP} dev02.${DOMAIN}     dev02
${HOMOLOGACAO_IP} homologacao.${DOMAIN} homologacao
EOF

ok "/etc/hosts configurado"

# ================== 4. DNS ==================
log "4/9 - Configurando DNS..."
cat > /etc/resolv.conf << EOF
nameserver ${DNS1}
nameserver ${DNS2}
EOF

ok "DNS configurado"

# ================== 5. Usuário ==================
log "5/9 - Criando usuário ${ADMIN}..."
if ! id "$ADMIN" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$ADMIN"
fi
echo "${ADMIN} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${ADMIN}"
chmod 440 "/etc/sudoers.d/${ADMIN}"
ok "Usuário ${ADMIN} criado"

# ================== 6. SSH ==================
log "6/9 - Configurando SSH..."
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null

SSH_DIR="/home/${ADMIN}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
  ssh-keygen -t rsa -b 4096 -C "dev01@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi

# Aceitar chave da operação (quando ela estiver configurada)
# Isso é feito reversamente - a operação copia a chave para cá
ok "SSH configurado"

# ================== 7. Docker ==================
log "7/9 - Instalando Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
  systemctl enable --now docker
  usermod -aG docker "$ADMIN"
fi
ok "Docker instalado"

# ================== 8. Java (JDK 21) ==================
log "8/9 - Instalando JDK 21..."
if ! java --version >/dev/null 2>&1; then
  apt-get install -y openjdk-21-jdk >/dev/null 2>&1
  echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64" >> "/home/${ADMIN}/.bashrc"
fi
ok "JDK 21 instalado"

# ================== 9. Git + VS Code ==================
log "9/9 - Instalando Git e VS Code..."
apt-get install -y git >/dev/null 2>&1

sudo -u "$ADMIN" git config --global user.name "Dev01 TechCorp"
sudo -u "$ADMIN" git config --global user.email "dev01@techcorp.com.br"

# VS Code
if ! command -v code >/dev/null 2>&1; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor \
    > /usr/share/keyrings/packages.microsoft.gpg 2>/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] \
    https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list
  apt-get update -y >/dev/null 2>&1
  apt-get install -y code >/dev/null 2>&1
fi

ok "Git e VS Code instalados"

# ================== Verificação ==================
echo
echo "=========================================="
echo "  DEV01 CONFIGURADO!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  Gateway: $GW_IP"
echo
echo "Serviços:"
echo "  SSH: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)"
echo "  Docker: $(systemctl is-active docker)"
echo "  Java: $(java --version 2>&1 | head -1)"
echo "  Git: $(git --version)"
echo
echo "Chave pública (adicione no GitLab):"
cat "/home/${ADMIN}/.ssh/id_ed25519.pub" 2>/dev/null || cat "/home/${ADMIN}/.ssh/id_rsa.pub" 2>/dev/null
echo
echo "Máquinas no /etc/hosts:"
grep -E "dev0|operacao|gateway|homologacao" /etc/hosts | awk '{print "  " $1 " → " $2}'
echo
echo "Próximos passos:"
echo "  1. Copie a chave pública e adicione no GitLab"
echo "  2. Execute setup-dev02.sh na máquina Dev02"
echo "  3. Execute setup-homologacao.sh na máquina de Homologação"
echo
