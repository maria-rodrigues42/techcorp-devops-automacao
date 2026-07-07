#!/usr/bin/env bash
#
# setup-dns.sh - Configuração completa da máquina DNS
#
# IP: 192.168.13.53
# Função: Servidor DNS (bind9) autoritativo de techcorp.com.br
#
# Uso: sudo ./setup-dns.sh
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.53"
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
  die "Execute como root: sudo ./setup-dns.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup DNS"
echo "  IP: $IP"
echo "  Função: Servidor DNS (bind9)"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/7 - Configurando rede..."

LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)

cat > /etc/network/interfaces << EOF
# TechCorp DNS - Configuração de Rede
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
echo "dns" > /etc/hostname
hostnamectl set-hostname dns 2>/dev/null || hostname dns

# ================== 3. /etc/hosts ==================
log "3/7 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${DNS_IP}   dns.${DOMAIN}         dns
${GW_IP}    gateway.${DOMAIN}     gateway
${OP_IP}    operacao.${DOMAIN}    operacao
${DEV01_IP} dev01.${DOMAIN}       dev01
${DEV02_IP} dev02.${DOMAIN}       dev02
${HOMOLOGACAO_IP} homologacao.${DOMAIN} homologacao
${GITLAB_IP} gitlab.${DOMAIN}     gitlab
${WEBSERVER_IP} webserver.${DOMAIN} webserver
${DBSERVER_IP} dbserver.${DOMAIN} dbserver
EOF

ok "/etc/hosts configurado"

# ================== 4. DNS (resolvedor temporário) ==================
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
  ssh-keygen -t rsa -b 4096 -C "dns@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi
chown -R "${ADMIN}:${ADMIN}" "$SSH_DIR"
ok "SSH configurado"

# ================== 7. bind9 (DNS autoritativo) ==================
log "7/7 - Instalando e configurando bind9..."
apt-get install -y bind9 dnsutils
apt-get install -y bind9utils 2>/dev/null || apt-get install -y bind9-utils 2>/dev/null || true

SERIAL="$(date +%Y%m%d)01"

# Opções globais: recursivo + forwarders para a internet
cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";

    recursion yes;
    allow-query { any; };

    forwarders {
        ${DNS1};
        ${DNS2};
    };
    forward only;

    dnssec-validation auto;

    listen-on { any; };
    listen-on-v6 { any; };
};
EOF

# Zonas: direta (techcorp.com.br) e reversa (192.168.13.0/24)
cat > /etc/bind/named.conf.local << EOF
zone "${DOMAIN}" {
    type master;
    file "/etc/bind/db.${DOMAIN}";
};

zone "13.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.13";
};
EOF

# Zona direta
cat > "/etc/bind/db.${DOMAIN}" << EOF
\$TTL    604800
@       IN      SOA     dns.${DOMAIN}. admin.${DOMAIN}. (
                        ${SERIAL}     ; Serial
                        604800         ; Refresh
                        86400          ; Retry
                        2419200        ; Expire
                        604800 )       ; Negative Cache TTL
;
@       IN      NS      dns.${DOMAIN}.

dns          IN     A      ${DNS_IP}
gateway      IN     A      ${GW_IP}
operacao     IN     A      ${OP_IP}
dev01        IN     A      ${DEV01_IP}
dev02        IN     A      ${DEV02_IP}
homologacao  IN     A      ${HOMOLOGACAO_IP}
gitlab       IN     A      ${GITLAB_IP}
webserver    IN     A      ${WEBSERVER_IP}
dbserver     IN     A      ${DBSERVER_IP}
EOF

# Zona reversa
cat > /etc/bind/db.192.168.13 << EOF
\$TTL    604800
@       IN      SOA     dns.${DOMAIN}. admin.${DOMAIN}. (
                        ${SERIAL}     ; Serial
                        604800         ; Refresh
                        86400          ; Retry
                        2419200        ; Expire
                        604800 )       ; Negative Cache TTL
;
@       IN      NS      dns.${DOMAIN}.

53      IN      PTR     dns.${DOMAIN}.
101     IN      PTR     gateway.${DOMAIN}.
151     IN      PTR     operacao.${DOMAIN}.
201     IN      PTR     dev01.${DOMAIN}.
202     IN      PTR     dev02.${DOMAIN}.
150     IN      PTR     homologacao.${DOMAIN}.
100     IN      PTR     gitlab.${DOMAIN}.
140     IN      PTR     webserver.${DOMAIN}.
130     IN      PTR     dbserver.${DOMAIN}.
EOF

# Validar configuração e zonas
named-checkconf || die "Erro na configuração do bind (named.conf)"
named-checkzone "${DOMAIN}" "/etc/bind/db.${DOMAIN}" || die "Erro na zona direta"
named-checkzone "13.168.192.in-addr.arpa" "/etc/bind/db.192.168.13" || die "Erro na zona reversa"

systemctl enable --now named 2>/dev/null || systemctl enable --now bind9 2>/dev/null
systemctl restart named 2>/dev/null || systemctl restart bind9 2>/dev/null

# O próprio servidor DNS passa a usar a si mesmo
cat > /etc/resolv.conf << EOF
nameserver 127.0.0.1
nameserver ${DNS1}
EOF

ok "bind9 configurado"

# ================== Verificação ==================
echo
echo "=========================================="
echo "  DNS CONFIGURADO!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  Gateway: $GW_IP"
echo
echo "Serviços:"
echo "  SSH: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)"
echo "  bind9: $(systemctl is-active named 2>/dev/null || systemctl is-active bind9 2>/dev/null)"
echo
echo "Teste de resolução (via este servidor):"
dig +short @127.0.0.1 gateway.${DOMAIN}    | sed 's/^/  gateway    → /'
dig +short @127.0.0.1 homologacao.${DOMAIN} | sed 's/^/  homologacao → /'
dig +short @127.0.0.1 gitlab.${DOMAIN}     | sed 's/^/  gitlab     → /'
echo
echo "Para as outras VMs usarem este DNS, aponte /etc/resolv.conf delas para:"
echo "  nameserver ${DNS_IP}"
echo
echo "Próximos passos:"
echo "  1. (Opcional) Ajuste o resolv.conf das outras VMs para ${DNS_IP}"
echo "  2. Continue provisionando as demais máquinas"
echo
