#!/usr/bin/env bash
#
# setup.sh - Automação unificada: Estação de Desenvolvimento + DevOps + Banco de Dados
#
#   Uso:  sudo ./setup.sh [--all | --workstation | --devops | --database]
#
#   --all         Instala tudo (padrão)
#   --workstation Ferramentas de desenvolvimento (VS Code, editores, linguagens)
#   --devops      Ferramentas DevOps (Docker, GitLab Runner, Helm, Terraform, Ansible)
#   --database    Banco de dados MySQL/MariaDB + Redis via Docker
#
#   Empresa: TechCorp Soluções (hipotética)
#   SO alvo: Ubuntu/Debian (22.04+)
#
set -uo pipefail

# ================== Configuração da Empresa ==================
COMPANY="TechCorp"
DOMAIN="techcorp.com.br"
GITLAB_URL="https://gitlab.techcorp.com.br"
GITLAB_TOKEN=""  # Preencher para GitLab Runner

# ================== Cores e Log ==================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
ok()    { echo -e "${GREEN}  ✓${NC} $*"; }
warn()  { echo -e "${YELLOW}  ⚠${NC} $*"; }
err()   { echo -e "${RED}  ✗${NC} $*" >&2; }
header(){ echo -e "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"; }

# ================== Helpers ==================
apt_update()  { apt-get update -y >/dev/null 2>&1 || true; }
apt_install() { DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null 2>&1; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }

# ================== Parse args ==================
INSTALL_ALL=true
INSTALL_WORKSTATION=false
INSTALL_DEVOPS=false
INSTALL_DATABASE=false

for arg in "$@"; do
  case "$arg" in
    --all)         INSTALL_ALL=true ;;
    --workstation) INSTALL_ALL=false; INSTALL_WORKSTATION=true ;;
    --devops)      INSTALL_ALL=false; INSTALL_DEVOPS=true ;;
    --database)    INSTALL_ALL=false; INSTALL_DATABASE=true ;;
    -h|--help)
      echo "Uso: sudo ./setup.sh [--all | --workstation | --devops | --database]"
      exit 0 ;;
    *) echo "Arg desconhecido: $arg"; exit 1 ;;
  esac
done

if $INSTALL_ALL; then
  INSTALL_WORKSTATION=true
  INSTALL_DEVOPS=true
  INSTALL_DATABASE=true
fi

# ================== Verifica root ==================
if [[ "$(id -u)" -ne 0 ]]; then
  err "Execute como root: sudo ./setup.sh"
  exit 1
fi

# ================== INÍCIO ==================
header "🚀 TechCorp - Automação de Ambiente de Desenvolvimento"
log "Sistema: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY | cut -d= -f2)"
log "Data: $(date +'%d/%m/%Y %H:%M')"
echo

# ================== MÓDULO 1: ESTAÇÃO DE TRABALHO ==================
if $INSTALL_WORKSTATION; then
  header "📦 MÓDULO 1: Estação de Desenvolvimento"
  bash "$(dirname "$0")/scripts/workstation.sh"
fi

# ================== MÓDULO 2: DEVOPS ==================
if $INSTALL_DEVOPS; then
  header "🔧 MÓDULO 2: Ferramentas DevOps"
  bash "$(dirname "$0")/scripts/devops.sh"
fi

# ================== MÓDULO 3: BANCO DE DADOS ==================
if $INSTALL_DATABASE; then
  header "🗄️  MÓDULO 3: Banco de Dados"
  bash "$(dirname "$0")/scripts/database.sh"
fi

# ================== RELATÓRIO FINAL ==================
header "📊 Relatório de Instalação"
log "Verificando componentes instalados..."
echo

check_component() {
  local name="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    ok "$name"
  else
    warn "$name (não encontrado)"
  fi
}

check_component "Git"              "git --version"
check_component "VS Code"          "code --version"
check_component "Docker"           "docker --version"
check_component "Docker Compose"   "docker compose version"
check_component "Node.js"          "node --version"
check_component "Python 3"         "python3 --version"
check_component "Java"             "java --version"
check_component "Ansible"          "ansible --version"
check_component "Terraform"        "terraform --version"
check_component "Helm"             "helm version --short"
check_component "kubectl"          "kubectl version --client"
check_component "MySQL (Docker)"   "docker ps | grep -q mysql"
check_component "Redis (Docker)"   "docker ps | grep -q redis"
check_component "Portainer"        "docker ps | grep -q portainer"

echo
header "✅ Instalação Concluída!"
log "Próximos passos:"
echo "  1. Abra o VS Code: code"
echo "  2. Acesse o GitLab: $GITLAB_URL"
echo "  3. Portainer (gerenciador Docker): http://localhost:9000"
echo "  4. MySQL Workbench: conecte em localhost:3306"
echo "  5. Redis Insight: http://localhost:5540"
echo
