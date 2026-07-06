#!/usr/bin/env bash
#
# setup-staging.sh - Configura o servidor de Homologação
#
# Uso: sudo ./setup-staging.sh
#
# O que este script faz:
#   1. Instala Docker
#   2. Cria a aplicação (backend + frontend + banco)
#   3. Sobe os containers
#   4. Verifica se está funcionando
#
set -uo pipefail

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

# ================== Verificar root ==================
if [[ "$(id -u)" -ne 0 ]]; then
  err "Execute como root: sudo ./setup-staging.sh"
  exit 1
fi

echo
echo "=========================================="
echo "  TechCorp - Setup Homologação"
echo "=========================================="
echo

# ================== 1. Docker ==================
log "1/4 - Instalando Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
  systemctl enable --now docker
  ok "Docker instalado"
else
  ok "Docker já instalado"
fi

# ================== 2. Criar aplicação ==================
log "2/4 - Criando aplicação..."
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
    setInterval(load, 10000);
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

# Init SQL
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

# ================== 3. Subir containers ==================
log "3/4 - Subindo containers..."
cd "$APP_DIR"
docker compose up -d --build >/dev/null 2>&1
ok "Containers iniciados"

# ================== 4. Verificação ==================
log "4/4 - Verificando..."
echo

for i in $(seq 30); do
  if docker exec techcorp-db mysqladmin ping -h localhost -u root -proot_password_2024 2>/dev/null | grep -q alive; then
    ok "MySQL pronto"
    break
  fi
  sleep 2
done

echo
echo "=========================================="
echo "  STATUS DOS CONTAINERS"
echo "=========================================="
docker ps --filter "name=techcorp" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

echo "=========================================="
echo "  SERVIÇOS DISPONÍVEIS"
echo "=========================================="
echo "  Frontend:  http://$(hostname -I | awk '{print $1}'):80"
echo "  Backend:   http://$(hostname -I | awk '{print $1}'):8080/api/health"
echo "  MySQL:     $(hostname -I | awk '{print $1}'):3306"
echo "=========================================="
echo
