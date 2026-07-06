#!/usr/bin/env bash
#
# atualizar-app.sh - Atualiza o código da aplicação (simula pull do GitLab)
#
# Uso: ./atualizar-app.sh [versao]
#
# Exemplo:
#   ./atualizar-app.sh v2.0.0    # Atualiza para versão 2.0.0
#
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC} $*"; }

NOVA_VERSAO="${1:-v$(date +%Y%m%d-%H%M%S)}"
APP_DIR="/opt/app-homologacao"

echo
echo "=========================================="
echo "  TechCorp - Atualizar Aplicação"
echo "  Nova versão: $NOVA_VERSAO"
echo "=========================================="
echo

# ================== 1. Simular pull do GitLab ==================
log "1/4 - Simulando pull do GitLab..."
echo "  (Em produção, seria: git pull origin main)"

# ================== 2. Alterar o código ==================
log "2/4 - Atualizando código..."

# Atualizar backend - adicionar rota de versão
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

app.get('/api/version', (req, res) => {
  res.json({ version: APP_VERSION, message: 'Versão atualizada com sucesso!' });
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

# Atualizar frontend
cat > "$APP_DIR/frontend/index.html" << HTMLEOF
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
    .badge { background: #4CAF50; color: white; padding: 4px 8px; border-radius: 4px; font-size: 0.8em; margin-left: 10px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🏢 TechCorp</h1>
    <p>Ambiente de Homologação</p>
    <div class="version" id="version">v$NOVA_VERSAO</div>
    <div class="status" id="status">● Online <span class="badge">NOVO!</span></div>
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

ok "Código atualizado"

# ================== 3. Build e deploy ==================
log "3/4 - Fazendo build e deploy..."
cd "$APP_DIR"
docker compose up -d --build >/dev/null 2>&1
ok "Deploy concluído"

# ================== 4. Verificar ==================
log "4/4 - Verificando..."
sleep 3

HEALTH=$(curl -s "http://localhost:8080/api/health" 2>/dev/null)
if echo "$HEALTH" | grep -q "healthy"; then
  echo
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  DEPLOY $NOVA_VERSAO CONCLUÍDO!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo
  echo "  Versão: $(echo $HEALTH | jq -r .version)"
  echo "  Frontend: http://$(hostname -I | awk '{print $1}')"
  echo "  API: http://$(hostname -I | awk '{print $1}'):8080/api/health"
  echo
else
  echo -e "${RED}  Deploy com problemas - verifique os logs${NC}"
fi
