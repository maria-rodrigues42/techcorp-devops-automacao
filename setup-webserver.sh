#!/usr/bin/env bash
#
# setup-webserver.sh - Configuração completa da máquina WEBSERVER
#
# IP: 192.168.13.140
# Função: Servidor Web (nginx)
#
# Uso: sudo ./setup-webserver.sh
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.140"
NETMASK="255.255.255.0"
GW_IP="192.168.13.101"
OP_IP="192.168.13.151"
DEV01_IP="192.168.13.201"
DEV02_IP="192.168.13.202"
HOMOLOGACAO_IP="192.168.13.150"
DNS_IP="192.168.13.53"
GITLAB_IP="192.168.13.100"
WEBSERVER_IP="192.168.13.140"
DBSERVER_IP="192.168.13.130"
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
  die "Execute como root: sudo ./setup-webserver.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup WEBSERVER"
echo "  IP: $IP"
echo "  Função: Servidor Web (nginx)"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/7 - Configurando rede..."

LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)

cat > /etc/network/interfaces << EOF
# TechCorp Webserver - Configuração de Rede
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
log "2/7 - Configurando hostname..."
echo "webserver" > /etc/hostname
hostnamectl set-hostname webserver 2>/dev/null || hostname webserver

# ================== 3. /etc/hosts ==================
log "3/7 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${WEBSERVER_IP} webserver.${DOMAIN} webserver
${GW_IP}    gateway.${DOMAIN}     gateway
${OP_IP}    operacao.${DOMAIN}    operacao
${DEV01_IP} dev01.${DOMAIN}       dev01
${DEV02_IP} dev02.${DOMAIN}       dev02
${HOMOLOGACAO_IP} homologacao.${DOMAIN} homologacao
${DNS_IP}   dns.${DOMAIN}         dns
${GITLAB_IP} gitlab.${DOMAIN}     gitlab
${DBSERVER_IP} dbserver.${DOMAIN} dbserver
EOF

ok "/etc/hosts configurado"

# ================== 4. DNS ==================
log "4/7 - Configurando DNS..."
cat > /etc/resolv.conf << EOF
nameserver ${DNS1}
nameserver ${DNS2}
EOF

ok "DNS configurado"

# ================== 5. Usuário ==================
log "5/7 - Criando usuário ${ADMIN}..."
if ! id "$ADMIN" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$ADMIN"
fi
echo "${ADMIN} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${ADMIN}"
chmod 440 "/etc/sudoers.d/${ADMIN}"
ok "Usuário ${ADMIN} criado"

# ================== 6. SSH ==================
log "6/7 - Configurando SSH..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openssh-server
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null

SSH_DIR="/home/${ADMIN}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
  ssh-keygen -t rsa -b 4096 -C "webserver@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi
chown -R "${ADMIN}:${ADMIN}" "$SSH_DIR"
ok "SSH configurado"

# ================== 7. Nginx ==================
log "7/7 - Instalando e configurando nginx..."
apt-get install -y nginx

# Página inicial do webserver
mkdir -p /var/www/techcorp
cat > /var/www/techcorp/index.html << 'HTML'
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="UTF-8">
  <title>TechCorp - Webserver</title>
  <style>
    body { font-family: Arial; background: linear-gradient(135deg, #11998e, #38ef7d); min-height: 100vh; display: flex; align-items: center; justify-content: center; margin: 0; }
    .card { background: white; padding: 40px; border-radius: 16px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); text-align: center; max-width: 500px; }
    h1 { color: #11998e; margin-bottom: 10px; }
    .badge { background: #11998e; color: white; padding: 8px 16px; border-radius: 20px; display: inline-block; margin: 10px 0; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🌐 TechCorp Webserver</h1>
    <p>Servidor web dedicado (nginx)</p>
    <div class="badge">webserver.techcorp.com.br</div>
    <p>Servidor no ar e pronto para servir conteúdo.</p>
  </div>
</body>
</html>
HTML

# Site padrão do nginx
cat > /etc/nginx/sites-available/techcorp << 'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name webserver.techcorp.com.br _;

    root /var/www/techcorp;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Exemplo (comentado) de reverse-proxy para o backend da homologação:
    # location /api/ {
    #     proxy_pass http://192.168.13.150:8080;
    #     proxy_set_header Host $host;
    #     proxy_set_header X-Real-IP $remote_addr;
    #     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    # }
}
NGINX

ln -sf /etc/nginx/sites-available/techcorp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t || die "Configuração do nginx inválida"
systemctl enable --now nginx
systemctl restart nginx
ok "nginx configurado"

# ================== Verificação ==================
echo
echo "=========================================="
echo "  WEBSERVER CONFIGURADO!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  Gateway: $GW_IP"
echo
echo "Serviços:"
echo "  SSH: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)"
echo "  nginx: $(systemctl is-active nginx)"
echo
echo "Teste local:"
curl -s -o /dev/null -w "  HTTP %{http_code} em http://localhost\n" http://localhost 2>/dev/null || echo "  (curl indisponível)"
echo
echo "Aplicação:"
echo "  Web: http://${IP}"
echo
echo "Próximos passos:"
echo "  1. Acesse http://${IP} no navegador"
echo "  2. (Opcional) Habilite o bloco de reverse-proxy /api/ em /etc/nginx/sites-available/techcorp"
echo
