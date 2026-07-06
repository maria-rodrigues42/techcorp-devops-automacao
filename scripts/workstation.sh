#!/usr/bin/env bash
#
# workstation.sh - Setup da Estação de Desenvolvimento
#
# Instala: VS Code, editores, linguagens (Node.js, Python, Java),
#          terminais, Git, utilitários de produtividade
#
set -uo pipefail

log()  { echo -e "\033[1;34m[workstation]\033[0m $*"; }
ok()   { echo -e "  \033[1;32m✓\033[0m $*"; }
warn() { echo -e "  \033[1;33m⚠\033[0m $*"; }

apt_update()  { apt-get update -y >/dev/null 2>&1 || true; }
apt_install() { DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null 2>&1; }

# ================== Pacotes base ==================
log "Instalando pacotes base do sistema..."
apt_update
apt_install \
  curl wget git unzip zip software-properties-common \
  apt-transport-https ca-certificates gnupg2 lsb-release \
  htop tmux tree jq ripgrep fd-find bat \
  build-essential python3-pip python3-venv \
  net-tools nmap \
  chromium-browser || apt_install chromium || true

ok "Pacotes base instalados"

# ================== Git ==================
log "Configurando Git..."
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global pull.rebase false
git config --global color.ui auto
git config --global user.name "Dev TechCorp"
git config --global user.email "dev@techcorp.com.br"

# Git Credential Manager
if ! command_exists git-credential-manager; then
  wget -q "https://github.com/git-ecosystem/git-credential-manager/releases/download/v2.4.1/gcm-linux_amd64.2.4.1.deb" -O /tmp/gcm.deb 2>/dev/null
  dpkg -i /tmp/gcm.deb 2>/dev/null || true
  rm -f /tmp/gcm.deb
fi
ok "Git configurado"

# ================== Visual Studio Code ==================
log "Instalando Visual Studio Code..."
if ! command_exists code; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg 2>/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list
  apt_update
  apt_install code
fi

# Extensões VS Code
log "Instalando extensões VS Code..."
EXTENSIONS=(
  # Core
  "ms-python.python"
  "ms-python.vscode-pylance"
  "ms-python.black-formatter"
  "ms-python.isort"
  "ms-java.java-pack"
  # TypeScript/JavaScript
  "dbaeumer.vscode-eslint"
  "esbenp.prettier-vscode"
  "bradlc.vscode-tailwindcss"
  # Docker
  "ms-azuretools.vscode-docker"
  # Remote
  "ms-vscode-remote.remote-ssh"
  "ms-vscode-remote.remote-containers"
  # Git
  "eamodio.gitlens"
  # Database
  "cweijan.vscode-database-client2"
  # Utilities
  "christian-kohler.path-intellisense"
  "streetsidesoftware.code-spell-checker"
  # Theme
  "github.github-vscode-theme"
)

for ext in "${EXTENSIONS[@]}"; do
  code --install-extension "$ext" --force 2>/dev/null || true
done
ok "VS Code + extensões instalados"

# ================== Node.js (via NVM) ==================
log "Instalando Node.js (via NVM)..."
if [[ ! -d "/home/${SUDO_USER:-$USER}/.nvm" ]]; then
  NVM_VERSION="0.39.7"
  sudo -u "${SUDO_USER:-$USER}" bash -c "
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash
  "
fi

# Instalar Node.js LTS
sudo -u "${SUDO_USER:-$USER}" bash -c '
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
  npm install -g yarn pnpm tsx nodemon
'
ok "Node.js LTS + yarn/pnpm instalados"

# ================== Python ==================
log "Configurando Python..."
apt_install python3-dev python3-pip python3-venv
pip3 install --break-system-packages \
  black flake8 mypy pytest \
  httpie yq \
  ansible-lint 2>/dev/null || true

# Pyenv (gerenciador de versão)
if [[ ! -d "/home/${SUDO_USER:-$USER}/.pyenv" ]]; then
  sudo -u "${SUDO_USER:-$USER}" bash -c '
    curl https://pyenv.run | bash
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init -)"
    pyenv install 3.12.0
    pyenv global 3.12.0
  '
fi
ok "Python 3.12 + ferramentas instaladas"

# ================== Java (via SDKMAN) ==================
log "Instalando Java (via SDKMAN)..."
if [[ ! -d "/home/${SUDO_USER:-$USER}/.sdkman" ]]; then
  sudo -u "${SUDO_USER:-$USER}" bash -c '
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk install java 21.0.2-tem
    sdk install maven
    sdk install gradle
  '
fi
ok "Java 21 + Maven + Gradle instalados"

# ================== Terminais ==================
log "Instalando terminais e utilitários..."
apt_install \
  kitty || apt_install \
  alacritty || true

# Oh My Zsh (se Zsh estiver disponível)
if command_exists zsh; then
  sudo -u "${SUDO_USER:-$USER}" bash -c '
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  '
  ok "Oh My Zsh instalado"
fi

# ================== Utilitários de produtividade ==================
log "Instalando utilitários..."
apt_install \
  jq yq \
  httpie \
  tree \
  ncdu \
  duf \
  lazygit 2>/dev/null || true

# duf (replacement for df)
if ! command_exists duf; then
  wget -q "https://github.com/muesli/duf/releases/latest/download/duf_0.8.1_linux_amd64.deb" -O /tmp/duf.deb 2>/dev/null
  dpkg -i /tmp/duf.deb 2>/dev/null || true
  rm -f /tmp/duf.deb
fi

ok "Utilitários instalados"

# ================== Configurações finais ==================
log "Aplicando configurações de desenvolvimento..."

# SSH config para GitLab
mkdir -p "/home/${SUDO_USER:-$USER}/.ssh"
chmod 700 "/home/${SUDO_USER:-$USER}/.ssh"

cat > "/home/${SUDO_USER:-$USER}/.ssh/config" <<'SSHCONF'
Host gitlab.techcorp.com.br
    HostName gitlab.techcorp.com.br
    User git
    IdentityFile ~/.ssh/id_ed25519
    PreferredAuthentications publickey

Host *
    AddKeysToAgent yes
    UseKeychain yes
SSHCONF

chmod 600 "/home/${SUDO_USER:-$USER}/.ssh/config"

# Gerar chave SSH se não existir
if [[ ! -f "/home/${SUDO_USER:-$USER}/.ssh/id_ed25519" ]]; then
  sudo -u "${SUDO_USER:-$USER}" ssh-keygen -t ed25519 -C "dev@techcorp.com.br" -f "/home/${SUDO_USER:-$USER}/.ssh/id_ed25519" -N ""
fi

ok "Estação de desenvolvimento configurada!"
echo
