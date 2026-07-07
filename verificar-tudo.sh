#!/usr/bin/env bash
#
# verificar-tudo.sh - Verifica se todas as máquinas estão conectadas e funcionando
#
# Uso: ./verificar-tudo.sh
#
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo
echo "=========================================="
echo "  TechCorp - Verificação Geral"
echo "=========================================="
echo

# ================== Máquinas ==================
declare -A MAQUINAS=(
  ["gateway"]="192.168.13.101"
  ["dns"]="192.168.13.53"
  ["dbserver"]="192.168.13.130"
  ["gitlab"]="192.168.13.100"
  ["operacao"]="192.168.13.151"
  ["webserver"]="192.168.13.140"
  ["dev01"]="192.168.13.201"
  ["dev02"]="192.168.13.202"
  ["homologacao"]="192.168.13.150"
)

# ================== 1. Ping ==================
echo -e "${BLUE}1. Teste de rede (ping)${NC}"
echo

TOTAL=0
OK=0

for nome in gateway dns dbserver gitlab operacao webserver dev01 dev02 homologacao; do
  ip="${MAQUINAS[$nome]}"
  TOTAL=$((TOTAL + 1))
  if ping -c1 -W2 "$ip" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} ${nome} (${ip})"
    OK=$((OK + 1))
  else
    echo -e "  ${RED}✗${NC} ${nome} (${ip}) - sem resposta"
  fi
done

echo

# ================== 2. SSH ==================
echo -e "${BLUE}2. Teste SSH (de esta máquina)${NC}"
echo

for nome in gateway dns dbserver gitlab operacao webserver dev01 dev02 homologacao; do
  ip="${MAQUINAS[$nome]}"
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
    "sysadmin@${ip}" hostname >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} SSH para ${nome}"
  else
    echo -e "  ${YELLOW}○${NC} SSH para ${nome} (sem acesso - pode precisar copiar chave)"
  fi
done

echo

# ================== 3. Serviços ==================
echo -e "${BLUE}3. Serviços rodando (nesta máquina)${NC}"
echo

# Docker
if command -v docker >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} Docker: $(docker --version | awk '{print $3}')"
  CONTAINERS=$(docker ps -q 2>/dev/null | wc -l)
  echo "    Containers rodando: $CONTAINERS"
else
  echo -e "  ${YELLOW}○${NC} Docker: não instalado"
fi

# Ansible
if command -v ansible >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} Ansible: $(ansible --version 2>/dev/null | head -1)"
else
  echo -e "  ${YELLOW}○${NC} Ansible: não instalado"
fi

# Java
if command -v java >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} Java: $(java --version 2>&1 | head -1)"
else
  echo -e "  ${YELLOW}○${NC} Java: não instalado"
fi

# Git
if command -v git >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} Git: $(git --version | awk '{print $3}')"
else
  echo -e "  ${YELLOW}○${NC} Git: não instalado"
fi

echo

# ================== 4. Aplicação Homologação ==================
echo -e "${BLUE}4. Aplicação de Homologação${NC}"
echo

HEALTH=$(curl -s --connect-timeout 3 "http://192.168.13.150:8080/api/health" 2>/dev/null)
if echo "$HEALTH" | grep -q "healthy"; then
  VERSAO=$(echo "$HEALTH" | jq -r .version 2>/dev/null)
  echo -e "  ${GREEN}✓${NC} Backend respondendo (v${VERSAO})"
else
  echo -e "  ${RED}✗${NC} Backend não respondeu"
fi

FRONTEND=$(curl -s --connect-timeout 3 "http://192.168.13.150" 2>/dev/null)
if echo "$FRONTEND" | grep -q "TechCorp"; then
  echo -e "  ${GREEN}✓${NC} Frontend acessível"
else
  echo -e "  ${RED}✗${NC} Frontend não respondeu"
fi

WEB=$(curl -s --connect-timeout 3 "http://192.168.13.140" 2>/dev/null)
if echo "$WEB" | grep -q "TechCorp"; then
  echo -e "  ${GREEN}✓${NC} Webserver (nginx) acessível"
else
  echo -e "  ${RED}✗${NC} Webserver não respondeu"
fi

echo

# ================== Resumo ==================
echo "=========================================="
echo "  RESUMO"
echo "=========================================="
echo
echo "  Máquinas respondendo: ${OK}/${TOTAL}"
echo
echo "  Mapa da rede:"
echo "  ┌──────────────┬───────────────────┬────────────────┐"
echo "  │ Máquina      │ IP                │ Status         │"
echo "  ├──────────────┼───────────────────┼────────────────┤"
for nome in gateway dns dbserver gitlab operacao webserver dev01 dev02 homologacao; do
  ip="${MAQUINAS[$nome]}"
  if ping -c1 -W2 "$ip" >/dev/null 2>&1; then
    STATUS="${GREEN}Online${NC}"
  else
    STATUS="${RED}Offline${NC}"
  fi
  printf "  │ %-12s │ %-17s │ " "$nome" "$ip"
  echo -e "$STATUS"
done
echo "  └──────────────┴───────────────────┴────────────────┘"
echo
