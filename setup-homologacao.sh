#!/usr/bin/env bash
#
# setup-homologacao.sh - Configuração completa da máquina de HOMOLOGAÇÃO
#
# IP: 192.168.13.150
# Função: Servidor de Homologação (deploy da aplicação)
#
# Uso: sudo ./setup-homologacao.sh
#
set -uo pipefail

# ================== Configurações Fixas ==================
IP="192.168.13.150"
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
  die "Execute como root: sudo ./setup-homologacao.sh"
fi

echo
echo "=========================================="
echo "  TechCorp - Setup HOMOLOGAÇÃO"
echo "  IP: $IP"
echo "  Função: Servidor de Deploy"
echo "=========================================="
echo

# ================== 1. Rede ==================
log "1/8 - Configurando rede..."

LAN_IFACE=$(ip -4 addr show | grep -oP 'en\w+|eth\w+' | head -1)

cat > /etc/network/interfaces << EOF
# TechCorp Homologacao - Configuração de Rede
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
echo "homologacao" > /etc/hostname
hostnamectl set-hostname homologacao 2>/dev/null || hostname homologacao

# ================== 3. /etc/hosts ==================
log "3/8 - Configurando /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost
${IP}       homologacao.${DOMAIN} homologacao
${GW_IP}    gateway.${DOMAIN}   gateway
${OP_IP}    operacao.${DOMAIN}  operacao
${DEV01_IP} dev01.${DOMAIN}     dev01
${DEV02_IP} dev02.${DOMAIN}     dev02
${DNS_IP}   dns.${DOMAIN}         dns
${GITLAB_IP} gitlab.${DOMAIN}     gitlab
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
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server git curl >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null

SSH_DIR="/home/${ADMIN}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
  ssh-keygen -t rsa -b 4096 -C "homologacao@techcorp.com.br" -f "$SSH_DIR/id_rsa" -N ""
fi

# Aceitar chave da operação
ok "SSH configurado"

# ================== 7. Docker ==================
log "7/8 - Instalando Docker..."
install_docker

# ================== 8. Aplicação ==================
log "8/8 - Criando aplicação de homologação..."
APP_DIR="/opt/app-homologacao"
mkdir -p "$APP_DIR"/{backend,frontend}

# Backend
cat > "$APP_DIR/backend/package.json" << 'EOF'
{
  "name": "techcorp-backend",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0"
  }
}
EOF

cat > "$APP_DIR/backend/server.js" << 'JSEOF'
const express = require('express');
const mysql = require('mysql2/promise');
const app = express();
const PORT = 8080;

const dbConfig = {
  host: process.env.DB_HOST || 'db',
  port: 3306,
  user: process.env.DB_USER || 'app_user',
  password: process.env.DB_PASSWORD || 'secure_password_2024',
  database: process.env.DB_NAME || 'techcorp_homologacao'
};

const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const DEPLOY_TIME = new Date().toISOString();

app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy', version: APP_VERSION, deployTime: DEPLOY_TIME });
});

app.get('/api/projects', async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.execute('SELECT * FROM projects');
    await conn.end();
    res.json({ version: APP_VERSION, projects: rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Backend v${APP_VERSION} rodando na porta ${PORT}`);
});
JSEOF

cat > "$APP_DIR/backend/Dockerfile" << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
EOF

# Frontend
cat > "$APP_DIR/frontend/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="UTF-8">
  <title>TechCorp - Homologação</title>
  <style>
    body { font-family: Arial; background: linear-gradient(135deg, #667eea, #764ba2); min-height: 100vh; display: flex; align-items: center; justify-content: center; margin: 0; }
    .card { background: white; padding: 40px; border-radius: 16px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); text-align: center; max-width: 500px; }
    h1 { color: #667eea; margin-bottom: 20px; }
    .version { background: #667eea; color: white; padding: 8px 16px; border-radius: 20px; display: inline-block; margin: 10px 0; }
    .status { color: #4CAF50; font-weight: bold; margin: 20px 0; }
    #projects { text-align: left; margin-top: 20px; }
    .project { background: #f5f5f5; padding: 10px; border-radius: 8px; margin: 5px 0; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🏢 TechCorp</h1>
    <p>Ambiente de Homologação</p>
    <div class="version" id="version">Carregando...</div>
    <div class="status" id="status">● Online</div>
    <div id="projects"><p>Carregando projetos...</p></div>
  </div>
  <script>
    async function load() {
      try {
        const r = await fetch('http://'+window.location.hostname+':8080/api/health');
        const d = await r.json();
        document.getElementById('version').textContent = 'v' + d.version;
        document.title = 'TechCorp v' + d.version;
        const p = await fetch('http://'+window.location.hostname+':8080/api/projects');
        const pd = await p.json();
        if (pd.projects && pd.projects.length) {
          document.getElementById('projects').innerHTML = pd.projects.map(p =>
            '<div class="project"><strong>' + p.name + '</strong> - ' + p.status + '</div>'
          ).join('');
        }
      } catch(e) { document.getElementById('status').textContent = '● Erro de conexão'; }
    }
    load();
  </script>
</body>
</html>
HTMLEOF

cat > "$APP_DIR/frontend/Dockerfile" << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
EOF

# Docker Compose
cat > "$APP_DIR/docker-compose.yml" << 'EOF'
version: "3.9"
services:
  backend:
    build: ./backend
    container_name: techcorp-backend
    restart: always
    ports:
      - "8080:8080"
    environment:
      DB_HOST: db
      DB_USER: app_user
      DB_PASSWORD: secure_password_2024
      DB_NAME: techcorp_homologacao
      APP_VERSION: "1.0.0"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-net

  frontend:
    build: ./frontend
    container_name: techcorp-frontend
    restart: always
    ports:
      - "80:80"
    depends_on:
      - backend
    networks:
      - app-net

  db:
    image: mysql:8.0
    container_name: techcorp-db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root_password_2024
      MYSQL_DATABASE: techcorp_homologacao
      MYSQL_USER: app_user
      MYSQL_PASSWORD: secure_password_2024
    ports:
      - "3306:3306"
    volumes:
      - db-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-net

volumes:
  db-data:

networks:
  app-net:
    driver: bridge
EOF

# SQL de inicialização
cat > "$APP_DIR/init.sql" << 'SQLEOF'
CREATE DATABASE IF NOT EXISTS techcorp_homologacao;
USE techcorp_homologacao;

CREATE TABLE IF NOT EXISTS projects (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  status ENUM('active','archived','draft') DEFAULT 'draft'
);

INSERT INTO projects (name, description, status) VALUES
('Portal Clientes', 'Sistema de gestão de clientes', 'active'),
('API Gateway', 'Gateway de APIs internas', 'active'),
('Dashboard Ops', 'Painel de monitoramento', 'draft');
SQLEOF

ok "Aplicação criada em $APP_DIR"

# ================== Subir containers ==================
log "Subindo containers..."
cd "$APP_DIR"
docker compose up -d --build >/dev/null 2>&1

# Aguardar MySQL
log "Aguardando MySQL..."
for i in $(seq 30); do
  if docker exec techcorp-db mysqladmin ping -h localhost -u root -proot_password_2024 2>/dev/null | grep -q alive; then
    ok "MySQL pronto"
    break
  fi
  sleep 2
done

# ================== Verificação ==================
echo
echo "=========================================="
echo "  HOMOLOGAÇÃO CONFIGURADA!"
echo "=========================================="
echo
echo "Rede:"
echo "  IP: $IP"
echo "  Gateway: $GW_IP"
echo
echo "Serviços:"
echo "  SSH: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null)"
echo "  Docker: $(systemctl is-active docker)"
echo
echo "Containers:"
docker ps --filter "name=techcorp" --format "  {{.Names}}: {{.Status}}" 2>/dev/null
echo
echo "Aplicação:"
echo "  Frontend:  http://${IP}"
echo "  Backend:   http://${IP}:8080/api/health"
echo "  MySQL:     ${IP}:3306"
echo
echo "Próximos passos:"
echo "  1. Acesse http://${IP} no navegador"
echo "  2. Volte para a Operação e teste a conexão"
echo
