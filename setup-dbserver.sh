#!/usr/bin/env bash
#
# setup-dbserver.sh - Configuração completa da máquina DB SERVER
#
# IP: 192.168.13.130
# Função: Servidor de Banco de Dados (MariaDB)
#
# Uso: sudo ./setup-dbserver.sh
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.130"
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

# Banco de dados
DB_NAME="techcorp_homologacao"
DB_USER="app_user"
DB_PASSWORD="secure_password_2024"

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
  die "Execute como root: sudo ./setup-dbserver.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup DB SERVER"
echo "  IP: $IP"
echo "  Função: Banco de Dados (MariaDB)"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/7 - Configurando rede..."

LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)

cat > /etc/network/interfaces << EOF
# TechCorp DB Server - Configuração de Rede
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
echo "dbserver" > /etc/hostname
hostnamectl set-hostname dbserver 2>/dev/null || hostname dbserver

# ================== 3. /etc/hosts ==================
log "3/7 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${DBSERVER_IP} dbserver.${DOMAIN} dbserver
${GW_IP}    gateway.${DOMAIN}     gateway
${OP_IP}    operacao.${DOMAIN}    operacao
${DEV01_IP} dev01.${DOMAIN}       dev01
${DEV02_IP} dev02.${DOMAIN}       dev02
${HOMOLOGACAO_IP} homologacao.${DOMAIN} homologacao
${DNS_IP}   dns.${DOMAIN}         dns
${GITLAB_IP} gitlab.${DOMAIN}     gitlab
${WEBSERVER_IP} webserver.${DOMAIN} webserver
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
  ssh-keygen -t rsa -b 4096 -C "dbserver@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi
chown -R "${ADMIN}:${ADMIN}" "$SSH_DIR"
ok "SSH configurado"

# ================== 7. MariaDB ==================
log "7/7 - Instalando e configurando MariaDB..."
apt-get install -y mariadb-server mariadb-client

# Permitir conexões da rede interna (não só localhost)
cat > /etc/mysql/mariadb.conf.d/99-techcorp.cnf << EOF
[mysqld]
bind-address = 0.0.0.0
EOF

systemctl enable --now mariadb 2>/dev/null || systemctl enable --now mysql 2>/dev/null
systemctl restart mariadb 2>/dev/null || systemctl restart mysql 2>/dev/null

# Criar database, usuário de aplicação (acessível pela LAN) e schema
# (root usa autenticação por socket local no Debian/Ubuntu)
mariadb << SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;

USE ${DB_NAME};
CREATE TABLE IF NOT EXISTS projects (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  status ENUM('active','archived','draft') DEFAULT 'draft'
);
SQL

# Seed apenas se a tabela estiver vazia (idempotente)
COUNT=$(mariadb -N -B -e "SELECT COUNT(*) FROM ${DB_NAME}.projects" 2>/dev/null || echo 0)
if [[ "${COUNT:-0}" -eq 0 ]]; then
  mariadb "${DB_NAME}" << SQL
INSERT INTO projects (name, description, status) VALUES
('Portal Clientes', 'Sistema de gestão de clientes', 'active'),
('API Gateway', 'Gateway de APIs internas', 'active'),
('Dashboard Ops', 'Painel de monitoramento', 'draft');
SQL
  ok "Dados de exemplo inseridos"
else
  ok "Tabela já populada (${COUNT} registros) - seed ignorado"
fi

if systemctl is-active --quiet mariadb || systemctl is-active --quiet mysql; then
  ok "MariaDB configurado"
else
  die "MariaDB não está ativo - verifique 'journalctl -u mariadb'"
fi

# ================== Verificação ==================
echo
echo "=========================================="
echo "  DB SERVER CONFIGURADO!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  Gateway: $GW_IP"
echo
echo "Serviços:"
echo "  SSH: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)"
echo "  MariaDB: $(systemctl is-active mariadb 2>/dev/null || systemctl is-active mysql 2>/dev/null)"
echo "  Versão: $(mariadb -N -B -e 'SELECT VERSION()' 2>/dev/null)"
echo "  Escutando: $(ss -tlnp 2>/dev/null | grep -q ':3306' && echo 'porta 3306 (LAN)' || echo 'verificar')"
echo
echo "Banco de dados:"
echo "  Database: ${DB_NAME}"
echo "  Usuário:  ${DB_USER} (acesso pela rede interna)"
echo "  Conexão:  mysql -h ${DBSERVER_IP} -u ${DB_USER} -p ${DB_NAME}"
echo
echo "Projetos cadastrados:"
mariadb -N -B -e "SELECT CONCAT('  - ', name, ' [', status, ']') FROM ${DB_NAME}.projects" 2>/dev/null
echo
echo "Próximos passos:"
echo "  1. Aponte a aplicação para DB_HOST=${DBSERVER_IP} caso queira usar este banco"
echo "  2. Continue provisionando as demais máquinas"
echo
