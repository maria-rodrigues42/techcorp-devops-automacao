#!/usr/bin/env bash
#
# setup-dev.sh - Configura automaticamente a máquina de desenvolvimento
#
# Uso: sudo ./setup-dev.sh
#
# O que este script faz:
#   1. Instala dependências de sistema
#   2. Instala Docker
#   3. Instala JDK 21 (para Spring Boot)
#   4. Configura Git
#   5. Gera chave SSH
#   6. Instala VS Code
#   7. Verifica se tudo está funcionando
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
  err "Execute como root: sudo ./setup-dev.sh"
  exit 1
fi

# ================== Detectar usuário ==================
DEV_USER="${SUDO_USER:-$USER}"
if [[ "$DEV_USER" == "root" ]]; then
  err "Execute com um usuário normal (não root)"
  exit 1
fi

echo
echo "=========================================="
echo "  TechCorp - Setup de Ambiente Dev"
echo "  Usuário: $DEV_USER"
echo "=========================================="
echo

# ================== 1. Dependências do Sistema ==================
log "1/6 - Instalando dependências do sistema..."
apt-get update -y >/dev/null 2>&1
apt-get install -y \
  curl wget git unzip zip \
  apt-transport-https ca-certificates gnupg2 \
  build-essential python3-pip \
  htop tmux tree jq >/dev/null 2>&1
ok "Dependências instaladas"

# ================== 2. Docker ==================
log "2/6 - Instalando Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
  systemctl enable --now docker
  usermod -aG docker "$DEV_USER"
  ok "Docker instalado"
else
  ok "Docker já instalado"
fi

# ================== 3. Java (JDK 21) ==================
log "3/6 - Instalando JDK 21..."
if ! java --version >/dev/null 2>&1; then
  apt-get install -y openjdk-21-jdk >/dev/null 2>&1
  echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64" >> "/home/$DEV_USER/.bashrc"
  ok "JDK 21 instalado"
else
  ok "Java já instalado: $(java --version 2>&1 | head -1)"
fi

# ================== 4. Git ==================
log "4/6 - Configurando Git..."
sudo -u "$DEV_USER" git config --global user.name "Dev TechCorp"
sudo -u "$DEV_USER" git config --global user.email "dev@techcorp.com.br"
sudo -u "$DEV_USER" git config --global init.defaultBranch main
ok "Git configurado"

# ================== 5. Chave SSH ==================
log "5/6 - Gerando chave SSH..."
SSH_DIR="/home/$DEV_USER/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$SSH_DIR/id_ed25519" ]]; then
  sudo -u "$DEV_USER" ssh-keygen -t ed25519 -C "dev@techcorp.com.br" \
    -f "$SSH_DIR/id_ed25519" -N ""
  ok "Chave SSH gerada"
else
  ok "Chave SSH já existe"
fi

# Mostrar chave pública (para cadastrar no GitLab)
echo
echo "=========================================="
echo "  Sua chave pública (adicione no GitLab):"
echo "=========================================="
cat "$SSH_DIR/id_ed25519.pub"
echo "=========================================="
echo

# ================== 6. VS Code ==================
log "6/6 - Instalando VS Code..."
if ! command -v code >/dev/null 2>&1; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor \
    > /usr/share/keyrings/packages.microsoft.gpg 2>/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] \
    https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list
  apt-get update -y >/dev/null 2>&1
  apt-get install -y code >/dev/null 2>&1
  ok "VS Code instalado"
else
  ok "VS Code já instalado"
fi

# ================== Verificação Final ==================
echo
echo "=========================================="
echo "  VERIFICAÇÃO DO AMBIENTE"
echo "=========================================="
echo

ERROS=0

check() {
  local nome="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    ok "$nome"
  else
    warn "$nome (não encontrado)"
    ERROS=$((ERROS + 1))
  fi
}

check "Git"           "git --version"
check "Docker"        "docker --version"
check "Docker Compose" "docker compose version"
check "Java"          "java --version"
check "VS Code"       "code --version"
check "Chave SSH"     "test -f /home/$DEV_USER/.ssh/id_ed25519"

echo
if [[ $ERROS -eq 0 ]]; then
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  AMBIENTE CONFIGURADO COM SUCESSO!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo
  echo "Próximos passos:"
  echo "  1. Copie a chave pública acima e adicione no GitLab"
  echo "  2. Faça logout e login novamente (para ativar o grupo docker)"
  echo "  3. Teste o Docker: docker run hello-world"
else
  echo -e "${YELLOW}  $ERROS item(ns) precisam de atenção${NC}"
fi

echo
