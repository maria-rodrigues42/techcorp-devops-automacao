#!/usr/bin/env bash
#
# setup-gitlab.sh - Configuração completa da máquina GITLAB
#
# IP: 192.168.13.202
# Função: Servidor GitLab CE (código, CI, registry)
#
# Uso: sudo ./setup-gitlab.sh
#
# ATENÇÃO: o GitLab é pesado. Reserve pelo menos 4 GB de RAM para esta VM.
#          O primeiro boot leva alguns minutos até ficar acessível.
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.202"
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
  die "Execute como root: sudo ./setup-gitlab.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup GITLAB"
echo "  IP: $IP"
echo "  Função: GitLab CE (Docker)"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/8 - Configurando rede..."

LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)

cat > /etc/network/interfaces << EOF
# TechCorp GitLab - Configuração de Rede
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
echo "gitlab" > /etc/hostname
hostnamectl set-hostname gitlab 2>/dev/null || hostname gitlab

# ================== 3. /etc/hosts ==================
log "3/8 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${GITLAB_IP} gitlab.${DOMAIN}     gitlab
${GW_IP}    gateway.${DOMAIN}     gateway
${OP_IP}    operacao.${DOMAIN}    operacao
${DEV01_IP} dev01.${DOMAIN}       dev01
${DEV02_IP} dev02.${DOMAIN}       dev02
${HOMOLOGACAO_IP} homologacao.${DOMAIN} homologacao
${DNS_IP}   dns.${DOMAIN}         dns
${WEBSERVER_IP} webserver.${DOMAIN} webserver
${DBSERVER_IP} dbserver.${DOMAIN} dbserver
EOF

ok "/etc/hosts configurado"

# ================== 4. DNS ==================
log "4/8 - Configurando DNS..."
cat > /etc/resolv.conf << EOF
nameserver ${DNS1}
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
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openssh-server
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null

SSH_DIR="/home/${ADMIN}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
  ssh-keygen -t rsa -b 4096 -C "gitlab@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi
chown -R "${ADMIN}:${ADMIN}" "$SSH_DIR"
ok "SSH configurado"

# ================== 7. Docker ==================
log "7/8 - Instalando Docker..."
install_docker

# ================== 8. GitLab CE ==================
log "8/8 - Subindo GitLab CE (Docker)..."
# Observação: o GitLab usa a porta 22 do container mapeada em 2222 no host,
# para não conflitar com o SSH do próprio servidor (porta 22).
GITLAB_DIR="/srv/gitlab"
mkdir -p "$GITLAB_DIR"

cat > "$GITLAB_DIR/docker-compose.yml" << 'YAML'
services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab
    restart: always
    hostname: gitlab.techcorp.com.br
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://gitlab.techcorp.com.br'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        # Perfil enxuto para caber numa VM de laboratório:
        puma['worker_processes'] = 2
        prometheus_monitoring['enable'] = false
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"
    volumes:
      - /srv/gitlab/config:/etc/gitlab
      - /srv/gitlab/logs:/var/log/gitlab
      - /srv/gitlab/data:/var/opt/gitlab
    shm_size: '256m'
YAML

cd "$GITLAB_DIR"
docker compose up -d || die "Falha ao subir o GitLab via docker compose"
ok "GitLab iniciado (o primeiro boot leva alguns minutos)"

# ================== Verificação ==================
echo
echo "=========================================="
echo "  GITLAB CONFIGURADO!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  Gateway: $GW_IP"
echo
echo "Serviços:"
echo "  SSH: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)"
echo "  Docker: $(systemctl is-active docker)"
echo "  Container GitLab: $(docker ps --filter name=gitlab --format '{{.Status}}' 2>/dev/null || echo 'iniciando')"
echo
echo "Acesso (aguarde alguns minutos no primeiro boot):"
echo "  Web:   http://${IP}   (ou http://gitlab.${DOMAIN} se o DNS estiver ativo)"
echo "  SSH Git: porta 2222"
echo
echo "Senha inicial do usuário 'root' (válida por 24h após o primeiro boot):"
echo "  sudo docker exec gitlab cat /etc/gitlab/initial_root_password"
echo
echo "Próximos passos:"
echo "  1. Aguarde o container ficar 'healthy': docker ps"
echo "  2. Acesse a web e troque a senha do root"
echo "  3. Cadastre as chaves SSH das VMs dev01/dev02"
echo
