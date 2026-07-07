#!/usr/bin/env bash
#
# setup-gateway.sh - Configuração completa da máquina GATEWAY
#
# IP: 192.168.13.101
# Função: Roteador/NAT + Load Balancer
#
# Uso: sudo ./setup-gateway.sh
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.101"
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
  die "Execute como root: sudo ./setup-gateway.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup GATEWAY"
echo "  IP: $IP"
echo "  Função: NAT + Load Balancer"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/7 - Configurando rede..."

# Detectar interfaces
WAN_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | grep -v "$WAN_IFACE" | head -1)

if [[ -z "$LAN_IFACE" ]]; then
  LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)
fi

log "  WAN: ${WAN_IFACE:-auto} | LAN: ${LAN_IFACE:-auto}"

# Configurar /etc/network/interfaces
cat > /etc/network/interfaces << EOF
# TechCorp Gateway - Configuração de Rede
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

# WAN - Internet real (DHCP)
auto ${WAN_IFACE:-enp0s3}
iface ${WAN_IFACE:-enp0s3} inet dhcp

# LAN - Rede interna
auto ${LAN_IFACE:-enp0s8}
iface ${LAN_IFACE:-enp0s8} inet static
    address ${IP}
    netmask ${NETMASK}
EOF

ok "Rede configurada"

# ================== 2. Hostname ==================
log "2/7 - Configurando hostname..."
echo "gateway" > /etc/hostname
hostnamectl set-hostname gateway 2>/dev/null || hostname gateway

# ================== 3. /etc/hosts ==================
log "3/7 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${IP}       gateway.${DOMAIN}   gateway
${OP_IP}    operacao.${DOMAIN}  operacao
${DEV01_IP} dev01.${DOMAIN}     dev01
${DEV02_IP} dev02.${DOMAIN}     dev02
${HOMOLOGACAO_IP} homologacao.${DOMAIN} homologacao
${DNS_IP}   dns.${DOMAIN}         dns
${GITLAB_IP} gitlab.${DOMAIN}     gitlab
${WEBSERVER_IP} webserver.${DOMAIN} webserver
${DBSERVER_IP} dbserver.${DOMAIN} dbserver
EOF

ok "/etc/hosts configurado"

# ================== 4. Usuário ==================
log "4/7 - Criando usuário ${ADMIN}..."
if ! id "$ADMIN" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$ADMIN"
fi
echo "${ADMIN} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${ADMIN}"
chmod 440 "/etc/sudoers.d/${ADMIN}"
ok "Usuário ${ADMIN} criado"

# ================== 5. SSH ==================
log "5/7 - Configurando SSH..."
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server curl iptables >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null

# Gerar chave SSH
SSH_DIR="/home/${ADMIN}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
  ssh-keygen -t rsa -b 4096 -C "gateway@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi
ok "SSH configurado"

# ================== 6. NAT/Internet ==================
log "6/7 - Configurando NAT (internet para as outras máquinas)..."

cat > /etc/firewall/internet.sh << 'FIREWALL'
#!/bin/bash
ETH=$(ip route | grep default | awk '{print $5}' | head -1)
LAN="192.168.13.0/24"

for TABLE in filter nat mangle; do iptables -t $TABLE -F; done
iptables -Z

case $1 in
  start)
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -s $LAN -o $ETH -j MASQUERADE
    echo "Internet liberada para a rede local ($LAN via $ETH)"
    ;;
  stop)
    echo 0 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -D POSTROUTING -s $LAN -o $ETH -j MASQUERADE 2>/dev/null
    echo "Internet bloqueada"
    ;;
  *) echo "Uso: $0 start | stop" ;;
esac
FIREWALL

chmod +x /etc/firewall/internet.sh
ln -sf /etc/firewall/internet.sh /usr/local/sbin/internet

# Habilitar forward
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-techcorp.conf
sysctl -p /etc/sysctl.d/99-techcorp.conf >/dev/null 2>&1

# NAT no boot
cat > /etc/systemd/system/internet-nat.service << 'UNIT'
[Unit]
Description=TechCorp - NAT/roteamento da rede
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/internet start
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload 2>/dev/null
systemctl enable internet-nat.service >/dev/null 2>&1
/usr/local/sbin/internet start >/dev/null 2>&1

ok "NAT configurado"

# ================== 7. Nginx (Load Balancer) ==================
log "7/7 - Configurando Nginx (Load Balancer)..."
apt-get install -y nginx >/dev/null 2>&1

cat > /etc/nginx/sites-available/techcorp-lb << 'NGINX'
upstream backends {
    # Servidor web dedicado (webserver.techcorp.com.br)
    server 192.168.13.140:80;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://backends;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/techcorp-lb /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
ok "Nginx (Load Balancer) configurado"

# ================== Verificação ==================
echo
echo "=========================================="
echo "  GATEWAY CONFIGURADO!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  NAT: $(internet start 2>&1 | head -1)"
echo
echo "Serviços:"
echo "  SSH: rodando"
echo "  Nginx: $(systemctl is-active nginx)"
echo "  NAT: $(systemctl is-active internet-nat)"
echo
echo "Próximo: Execute setup-operacao.sh na máquina de operação"
echo
