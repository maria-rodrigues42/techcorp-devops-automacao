#!/usr/bin/env bash
#
# devops.sh - Setup de Ferramentas DevOps
#
# Instala: Docker, Docker Compose, GitLab Runner, Helm, kubectl,
#          Terraform, Ansible, Portainer
#
set -uo pipefail

log()  { echo -e "\033[1;34m[devops]\033[0m $*"; }
ok()   { echo -e "  \033[1;32m✓\033[0m $*"; }
warn() { echo -e "  \033[1;33m⚠\033[0m $*"; }

apt_update()  { apt-get update -y >/dev/null 2>&1 || true; }
apt_install() { DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null 2>&1; }

# ================== Docker ==================
log "Instalando Docker..."
if ! command_exists docker; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  # Adicionar usuário ao grupo docker
  usermod -aG docker "${SUDO_USER:-$USER}" 2>/dev/null || true
fi

# Docker Compose (plugin)
if ! docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
  curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# Configuração Docker daemon
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'DOCKERCONF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-address-pools": [
    {"base": "172.20.0.0/16", "size": 24}
  ]
}
DOCKERCONF

systemctl restart docker
ok "Docker + Docker Compose instalados"

# ================== Portainer (UI Docker) ==================
log "Instalando Portainer (gerenciador Docker)..."
if ! docker ps | grep -q portainer; then
  docker volume create portainer_data
  docker run -d \
    --name portainer \
    --restart=always \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
fi
ok "Portainer rodando em http://localhost:9000"

# ================== GitLab Runner ==================
log "Instalando GitLab Runner..."
if ! command_exists gitlab-runner; then
  curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
  apt_update
  apt_install gitlab-runner
fi

# Runner registrado (exemplo - empresa hipotética)
# Para registrar: sudo gitlab-runner register --url https://gitlab.techcorp.com.br --token <TOKEN>
mkdir -p /etc/gitlab-runner
cat > /etc/gitlab-runner/config.toml <<'RUNNERCONF'
concurrent = 4
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "techcorp-runner"
  url = "https://gitlab.techcorp.com.br"
  token = "REGISTRATION_TOKEN_HERE"
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "docker:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/certs/client"]
    shm_size = 0
    network_mtu = 0
  [runners.cache]
    MaxUploadedArchiveSize = 0
RUNNERCONF

systemctl enable gitlab-runner
ok "GitLab Runner instalado (precisa registrar com token)"

# ================== Helm (Kubernetes) ==================
log "Instalando Helm..."
if ! command_exists helm; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
ok "Helm $(helm version --short 2>/dev/null) instalado"

# ================== kubectl ==================
log "Instalando kubectl..."
if ! command_exists kubectl; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
fi

# kubectl completion
kubectl completion bash > /etc/bash_completion.d/kubectl 2>/dev/null || true
ok "kubectl instalado"

# ================== Terraform ==================
log "Instalando Terraform..."
if ! command_exists terraform; then
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg 2>/dev/null
  echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list
  apt_update
  apt_install terraform
fi

# Terraform providers
mkdir -p "/home/${SUDO_USER:-$USER}/.terraform.d/plugin-cache"
ok "Terraform $(terraform version -json 2>/dev/null | jq -r .terraform_version 2>/dev/null || terraform --version | head -1) instalado"

# ================== Ansible ==================
log "Instalando Ansible..."
if ! command_exists ansible; then
  apt_install ansible ansible-lint
fi

# Ansible collections
sudo -u "${SUDO_USER:-$USER}" ansible-galaxy collection install \
  community.docker \
  community.general \
  ansible.posix \
  2>/dev/null || true

# Ansible config para o usuário
ANSIBLE_CFG="/home/${SUDO_USER:-$USER}/.ansible.cfg"
if [[ ! -f "$ANSIBLE_CFG" ]]; then
  cat > "$ANSIBLE_CFG" <<'ANSCFG'
[defaults]
inventory = ./inventory
roles_path = ./roles
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml

[privilege_escalation]
become = True
become_method = sudo
ANSCFG
  chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$ANSIBLE_CFG"
fi
ok "Ansible + collections instalados"

# ================== Kubernetes Local (Minikube) ==================
log "Instalando Minikube (Kubernetes local)..."
if ! command_exists minikube; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  install minikube /usr/local/bin/minikube
  rm -f minikube-linux-amd64
fi
ok "Minikube instalado"

# ================== ArgoCD CLI ==================
log "Instalando ArgoCD CLI..."
if ! command_exists argocd; then
  curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  install -m 555 argocd /usr/local/bin/argocd
  rm -f argocd
fi
ok "ArgoCD CLI instalado"

echo
ok "Ferramentas DevOps instaladas!"
echo
