#!/usr/bin/env bash
#
# setup-dev02.sh - Configuração completa da máquina DEV02
#
# IP: 192.168.13.204
# Função: Desenvolvimento Frontend
#
# Uso: sudo ./setup-dev02.sh
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.204"
NETMASK="255.255.255.0"
GW_IP="192.168.13.101"
OP_IP="192.168.13.151"
DEV01_IP="192.168.13.203"
DEV02_IP="192.168.13.204"
HOMOLOGACAO_IP="192.168.13.150"
DNS_IP="192.168.13.53"
GITLAB_IP="192.168.13.202"
WEBSERVER_IP="192.168.13.140"
DBSERVER_IP="192.168.13.201"
DOMAIN="techcorp.com.br"
ADMIN="sysadmin"
DNS1="10.119.50.7"

# Versões das ferramentas de frontend
NODE_MAJOR="20"   # Node.js LTS
NVM_VERSION="v0.39.7"

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

# ================== Instalação robusta do Docker ==================
# Instala via repositório oficial (determinístico), com fallback, sem
# suprimir a saída, e VERIFICA ao final (falha alto se não instalar).
install_docker() {
  if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker; then
    ok "Docker já instalado: $(docker --version)"
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  log "  Preparando repositório oficial do Docker..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release

  install -m 0755 -d /etc/apt/keyrings
  . /etc/os-release
  local distro="${ID:-debian}"
  local codename="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null)}"

  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL "https://download.docker.com/linux/${distro}/gpg" \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${distro} ${codename} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y

  if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    warn "  Repositório oficial falhou; tentando pacote docker.io da distro..."
    if ! apt-get install -y docker.io; then
      warn "  Tentando script get.docker.com como último recurso..."
      curl -fsSL https://get.docker.com | sh
    fi
  fi

  systemctl enable --now docker
  usermod -aG docker "$ADMIN" 2>/dev/null || true

  if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker; then
    ok "Docker instalado: $(docker --version)"
  else
    die "Falha ao instalar o Docker. Rode 'sudo dpkg --configure -a && sudo apt-get install -f' e execute o script novamente."
  fi
}

# ================== Verificar root ==================
if [[ "$(id -u)" -ne 0 ]]; then
  die "Execute como root: sudo ./setup-dev02.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup DEV02"
echo "  IP: $IP"
echo "  Função: Desenvolvimento Frontend"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/9 - Configurando rede..."

LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)

cat > /etc/network/interfaces << EOF
# TechCorp Dev02 - Configuração de Rede
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
echo "dev02" > /etc/hostname
hostnamectl set-hostname dev02 2>/dev/null || hostname dev02

# ================== 3. /etc/hosts ==================
log "3/9 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${IP}       dev02.${DOMAIN}     dev02
${GW_IP}    gateway.${DOMAIN}   gateway
${OP_IP}    operacao.${DOMAIN}  operacao
${DEV01_IP} dev01.${DOMAIN}     dev01
${HOMOLOGACAO_IP} homologacao.${DOMAIN} homologacao
${DNS_IP}   dns.${DOMAIN}         dns
${GITLAB_IP} gitlab.${DOMAIN}     gitlab
${WEBSERVER_IP} webserver.${DOMAIN} webserver
${DBSERVER_IP} dbserver.${DOMAIN} dbserver
EOF

ok "/etc/hosts configurado"

# ================== 4. DNS ==================
log "4/9 - Configurando DNS..."
cat > /etc/resolv.conf << EOF
nameserver ${DNS1}
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
  ssh-keygen -t rsa -b 4096 -C "dev02@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi
chown -R "${ADMIN}:${ADMIN}" "$SSH_DIR"

ok "SSH configurado"

# ================== 7. Docker ==================
log "7/9 - Instalando Docker..."
# O frontend é empacotado em uma imagem nginx:alpine (ver app-homologacao/frontend)
install_docker

# ================== 8. Node.js + gerenciadores de pacotes ==================
log "8/9 - Instalando Node.js ${NODE_MAJOR} LTS + npm/Yarn/pnpm/nvm..."

# Runtime principal via NodeSource (traz npm junto)
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - >/dev/null 2>&1
  apt-get install -y nodejs >/dev/null 2>&1
fi

# Gerenciadores de pacotes usados em projetos frontend
if command -v npm >/dev/null 2>&1; then
  npm install -g yarn pnpm >/dev/null 2>&1
fi

# nvm para o usuário (troca de versões de Node por projeto)
NVM_DIR="/home/${ADMIN}/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
  sudo -u "$ADMIN" bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash" >/dev/null 2>&1
fi

ok "Node.js e gerenciadores de pacotes instalados"

# ================== 9. Ferramentas de Frontend + Git + VS Code ==================
log "9/9 - Instalando CLIs de frontend, Git e VS Code..."

# CLIs de frameworks/build tools de frontend
if command -v npm >/dev/null 2>&1; then
  npm install -g \
    @angular/cli \
    @vue/cli \
    create-vite \
    serve \
    typescript \
    eslint \
    prettier >/dev/null 2>&1
fi

# nginx para servir/testar builds estáticos localmente (mesmo runtime da imagem de deploy)
apt-get install -y nginx >/dev/null 2>&1
systemctl enable --now nginx 2>/dev/null || true

# Git
apt-get install -y git >/dev/null 2>&1
sudo -u "$ADMIN" git config --global user.name "Dev02 TechCorp"
sudo -u "$ADMIN" git config --global user.email "dev02@techcorp.com.br"

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

# Extensões essenciais para frontend
if command -v code >/dev/null 2>&1; then
  for ext in \
    dbaeumer.vscode-eslint \
    esbenp.prettier-vscode \
    dsznajder.es7-react-js-snippets \
    Vue.volar \
    Angular.ng-template \
    bradlc.vscode-tailwindcss \
    ms-azuretools.vscode-docker \
    eamodio.gitlens; do
    sudo -u "$ADMIN" code --install-extension "$ext" --force >/dev/null 2>&1 || true
  done
fi

ok "Ferramentas de frontend, Git e VS Code instalados"

# ================== Verificação ==================
echo
echo "=========================================="
echo "  DEV02 CONFIGURADO!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  Gateway: $GW_IP"
echo
echo "Serviços:"
echo "  SSH: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)"
echo "  Docker: $(systemctl is-active docker)"
echo "  nginx: $(systemctl is-active nginx 2>/dev/null)"
echo
echo "Ferramentas de Frontend:"
echo "  Node:  $(node --version 2>/dev/null || echo 'n/d')"
echo "  npm:   $(npm --version 2>/dev/null || echo 'n/d')"
echo "  Yarn:  $(yarn --version 2>/dev/null || echo 'n/d')"
echo "  pnpm:  $(pnpm --version 2>/dev/null || echo 'n/d')"
echo "  Angular CLI: $(ng version 2>/dev/null | grep -i 'Angular CLI' | head -1 || echo 'n/d')"
echo "  Git:   $(git --version)"
echo
echo "Chave pública (adicione no GitLab):"
cat "/home/${ADMIN}/.ssh/id_ed25519.pub" 2>/dev/null || cat "/home/${ADMIN}/.ssh/id_rsa.pub" 2>/dev/null
echo
echo "Próximos passos:"
echo "  1. Copie a chave pública e adicione no GitLab"
echo "  2. Execute setup-homologacao.sh na máquina de Homologação"
echo "  3. Volte para a Operação e teste a conexão"
echo
