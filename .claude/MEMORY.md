# Project Memory

## Repository: techcorp-devops-automacao

Clone path: `/home/maria-rodrigues/Documents/prova-robson/techcorp-devops-automacao`
Source: `https://github.com/maria-rodrigues42/techcorp-devops-automacao.git`
Purpose: DevOps automation project for a discipline (Prof. Robson) - simulated company "TechCorp Soluções"

## Architecture

- **5 VMs**: Gateway (192.168.13.101), Operação (192.168.13.151), Dev01 (192.168.13.201), Dev02 (192.168.13.202), Homologação (192.168.13.150)
- **Stack**: Node.js + Express + MySQL 8 + Docker + Nginx + Ansible
- **User**: `sysadmin` (NOPASSWD sudo) on all VMs

## Key Files

| File | Purpose |
|------|---------|
| `ansible-playbooks/cenario1-provisioning.yml` | Cenário 1: Provisionamento de Dev01/Dev02 (Docker, JDK21, SSH, GitLab, VS Code) |
| `ansible-playbooks/cenario2-deploy-staging.yml` | Cenário 2: Deploy automatizado no Homologação (clone→build→deploy→healthcheck) |
| `ansible-playbooks/inventories/hosts.yml` | Inventory YAML (dev_machines, staging_server, operacao groups) |
| `ansible-playbooks/group_vars/all.yml` | Global vars: company, domain, gitlab_url, lan_prefix |
| `ansible-playbooks/playbook.yml` | Generic workstation provisioning (NVM, Python, Java, Helm, Terraform, etc.) |
| `app-homologacao/docker-compose.yml` | 3 services: backend (Node/Express, port 8080), frontend (Nginx, port 80), db (MySQL 8, port 3306) |
| `app-homologacao/backend/server.js` | Express API: /api/health, /api/info, /api/projects, /api/users, /api/deploys |
| `app-homologacao/init.sql` | MySQL schema: users, projects, deployments tables + seed data |
| `setup-gateway.sh` | NAT + Nginx load balancer (dev01:80 + dev02:80) |
| `setup-operacao.sh` | Control node: Ansible + Docker + SSH key distribution |
| `setup-dev01.sh` / `setup-dev02.sh` | Dev machines: Docker, JDK21, Git, VS Code, SSH key |
| `setup-homologacao.sh` | Staging: Docker + full app stack (backend+frontend+MySQL) |
| `master-setup.sh` | Host script that configures all VMs via SSH (VirtualBox) |
| `verificar-tudo.sh` | Verification: ping all VMs, SSH, Docker, Java, app health |
| `atualizar-app.sh` | Simulates deploy: updates code, rebuilds containers |
| `scripts/workstation.sh` | Full workstation setup (NVM, Python/pyenv, SDKMAN/Java, VS Code extensions) |
| `scripts/devops.sh` | DevOps tools (Docker, Portainer, GitLab Runner, Helm, kubectl, Terraform, Ansible, Minikube, ArgoCD) |
| `scripts/database.sh` | Docker Compose for MySQL 8, MariaDB 11, Redis 7, Adminer, Redis Insight |

## Deployment Flow

1. Setup Gateway → Operação → Dev01 → Dev02 → Homologação (order matters)
2. Operação runs Ansible playbooks against other VMs
3. Cenario1: provisions dev machines identically
4. Cenario2: deploys app to Homologação with health checks

## App Endpoints

- `GET /api/health` → `{status, version, deployTime, hostname, uptime}`
- `GET /api/info` → app metadata
- `GET /api/projects` → MySQL query
- `GET /api/users` → MySQL query
- `GET /api/deploys` → MySQL join query
