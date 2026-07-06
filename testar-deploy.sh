#!/usr/bin/env bash
#
# testar-deploy.sh - Testa se o deploy está funcionando
#
# Uso: ./testar-deploy.sh [versao]
#      ./testar-deploy.sh              # usa versão atual
#      ./testar-deploy.sh v2.0.0       # testa com versão específica
#
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NOVA_VERSAO="${1:-}"
APP_DIR="/opt/app-homologacao"

echo
echo "=========================================="
echo "  TechCorp - Teste de Deploy"
echo "=========================================="
echo

# ================== 1. Backup da versão atual ==================
echo -e "${BLUE}[1/5]${NC} Salvando versão atual..."
VERSAO_ATUAL=$(grep APP_VERSION "$APP_DIR/docker-compose.yml" | head -1 | cut -d'"' -f2)
echo "  Versão atual: $VERSAO_ATUAL"

# ================== 2. Alterar versão ==================
if [[ -n "$NOVA_VERSAO" ]]; then
  echo -e "${BLUE}[2/5]${NC} Atualizando para versão $NOVA_VERSAO..."

  # Alterar no docker-compose.yml
  sed -i "s/APP_VERSION: \"$VERSAO_ATUAL\"/APP_VERSION: \"$NOVA_VERSAO\"/" "$APP_DIR/docker-compose.yml"

  # Alterar no HTML do frontend
  sed -i "s/v$VERSAO_ATUAL/v$NOVA_VERSAO/g" "$APP_DIR/frontend/index.html"

  echo "  Versão atualizada: $NOVA_VERSAO"
else
  echo -e "${BLUE}[2/5]${NC} Usando versão atual: $VERSAO_ATUAL"
  NOVA_VERSAO="$VERSAO_ATUAL"
fi

# ================== 3. Reiniciar containers ==================
echo -e "${BLUE}[3/5]${NC} Reiniciando containers..."
cd "$APP_DIR"
docker compose up -d --build >/dev/null 2>&1
echo "  Containers reiniciados"

# ================== 4. Aguardar ficar pronto ==================
echo -e "${BLUE}[4/5]${NC} Aguardando aplicação..."
for i in $(seq 20); do
  if curl -s "http://localhost:8080/api/health" | grep -q "healthy"; then
    echo "  Aplicação pronta!"
    break
  fi
  sleep 2
done

# ================== 5. Verificar ==================
echo -e "${BLUE}[5/5]${NC} Verificando..."
echo

# Teste 1: Health check
echo -e "${YELLOW}Teste 1: Health Check${NC}"
HEALTH=$(curl -s "http://localhost:8080/api/health")
if echo "$HEALTH" | grep -q "healthy"; then
  echo -e "  ${GREEN}✓${NC} Backend respondendo"
  echo "    Versão: $(echo $HEALTH | jq -r .version)"
  echo "    Deploy: $(echo $HEALTH | jq -r .deployTime)"
else
  echo -e "  ${RED}✗${NC} Backend não respondeu"
fi

echo

# Teste 2: Projetos
echo -e "${YELLOW}Teste 2: Projetos no Banco${NC}"
PROJECTS=$(curl -s "http://localhost:8080/api/projects")
if echo "$PROJECTS" | grep -q "projects"; then
  echo -e "  ${GREEN}✓${NC} Conexão com banco OK"
  echo "$PROJECTS" | jq -r '.projects[] | "    - \(.name) [\(.status)]"'
else
  echo -e "  ${RED}✗${NC} Erro ao buscar projetos"
fi

echo

# Teste 3: Containers
echo -e "${YELLOW}Teste 3: Status dos Containers${NC}"
docker ps --filter "name=techcorp" --format "  {{.Names}}: {{.Status}}" 2>/dev/null

echo

# Teste 4: Frontend
echo -e "${YELLOW}Teste 4: Frontend${NC}"
if curl -s "http://localhost:80" | grep -q "TechCorp"; then
  echo -e "  ${GREEN}✓${NC} Frontend acessível"
  echo "    URL: http://$(hostname -I | awk '{print $1}')"
else
  echo -e "  ${RED}✗${NC} Frontend não respondeu"
fi

echo

# ================== Resumo ==================
echo "=========================================="
if [[ "$VERSAO_ATUAL" != "$NOVA_VERSAO" ]]; then
  echo -e "  ${GREEN}DEPLOY DE $VERSAO_ATUAL → $NOVA_VERSAO CONCLUÍDO!${NC}"
else
  echo -e "  ${GREEN}VERSÃO $NOVA_VERSAO FUNCIONANDO!${NC}"
fi
echo "=========================================="
echo
