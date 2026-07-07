# TechCorp - Automação DevOps com Ansible

Automação completa para ambiente de desenvolvimento corporativo, cobrindo dois cenários reais de uso do Ansible, agora com infraestrutura dividida em máquinas de propósito único.

## 🖥️ Máquinas do ambiente (VMs no VirtualBox)

Rede interna: `192.168.13.0/24` — domínio `techcorp.com.br`.

| Máquina | IP | Função (responsabilidade única) |
|---------|-----|---------------------------------|
| **gateway** | 192.168.13.101 | Roteador/NAT (dá internet para a LAN) + load balancer nginx |
| **dns** | 192.168.13.53 | Servidor DNS (bind9) autoritativo de `techcorp.com.br` |
| **gitlab** | 192.168.13.202 | GitLab CE (código, CI, registry) — via Docker |
| **operacao** | 192.168.13.151 | Control node Ansible (provisiona e faz deploy de tudo) |
| **webserver** | 192.168.13.140 | Servidor web nginx dedicado |
| **dbserver** | 192.168.13.201 | Servidor de banco MariaDB |
| **homologacao** | 192.168.13.150 | Ambiente de homologação **all-in-one** (frontend + backend + banco em containers) |
| **dev01** | 192.168.13.203 | Estação de desenvolvimento **backend** (Java 17 / Spring Boot) |
| **dev02** | 192.168.13.204 | Estação de desenvolvimento **frontend** (Node.js) |

> **Sem ambiente de produção.** Este projeto vai até a homologação. A homologação continua completa (all-in-one); as máquinas `dns`, `gitlab`, `webserver` e `dbserver` são serviços dedicados adicionados à rede, cada um com uma responsabilidade.

```
                         ┌───────────────────────────┐
       Internet ────────▶│   gateway  (.101)         │  NAT + Load Balancer
                         │   NAT / nginx LB ──────────┼────────▶ webserver (.140)
                         └─────────────┬─────────────┘
                                       │  rede interna 192.168.13.0/24
   ┌──────────────┬───────────────┬────┴─────┬───────────────┬──────────────┐
   ▼              ▼               ▼          ▼               ▼              ▼
 dns (.53)   gitlab (.100)   operacao    dbserver      homologacao      dev01 (.201)
 bind9       GitLab CE      (.151)        (.130)         (.150)         dev02 (.202)
                            Ansible       MariaDB     app all-in-one    workstations
```

---

## 🎯 Cenário 1: Provisionamento Padronizado de Máquinas Dev

### O problema
"Síndrome da minha máquina funciona" - cada desenvolvedor tem um ambiente diferente.

### A solução
Ansible provisiona **automaticamente** as máquinas Dev01 e Dev02. Cada uma recebe o stack do seu perfil: **dev01 = backend** (JDK 17 + Maven + Gradle) e **dev02 = frontend** (Node.js + npm), além das ferramentas comuns.

### O que o Ansible faz:

| Etapa | O que instala/configura |
|-------|------------------------|
| 1.1 | Dependências de sistema (git, curl, build-essential, etc.) |
| 2.1-2.7 | Docker Engine + Docker Compose + permissões |
| 3.1-3.6 | JDK 17 + Maven + Gradle (perfil backend / dev01) |
| 3.7 | Node.js LTS + npm (perfil frontend / dev02) |
| 4.1-4.5 | Chave SSH + cadastro automático no GitLab |
| 5.1-5.3 | VS Code + extensões essenciais |
| 6.1-6.2 | Script de verificação final |

### Como rodar:

```bash
cd ansible-playbooks

# Provisionar DEV01 e DEV02
ansible-playbook -i inventories/hosts.yml cenario1-provisioning.yml --ask-become-pass

# Ou provisionar apenas uma máquina específica
ansible-playbook -i inventories/hosts.yml cenario1-provisioning.yml --limit dev01
```

### Resultado esperado:

```
✅ Git instalado
✅ Docker Engine rodando
✅ Usuário adicionado ao grupo docker
✅ dev01: JDK 17 configurado  |  dev02: Node.js configurado
✅ Chave SSH gerada e cadastrada no GitLab
✅ VS Code com extensões
✅ Ambiente pronto para desenvolvimento!
```

---

## 🚀 Cenário 2: Deploy Automatizado no Ambiente de Homologação

### O problema
Deploy manual é lento, propenso a erros e difícil de reproduzir.

### A solução
Ansible faz **pull do código → build → deploy → verificação** automaticamente no servidor de homologação (all-in-one).

### O que o Ansible faz:

| Etapa | O que faz |
|-------|-----------|
| 1.1-1.3 | Verifica pré-requisitos (Git, Docker) |
| 2.1-2.5 | Clone/pull do repositório no GitLab |
| 3.1-3.2 | Para e remove containers antigos |
| 4.1-4.7 | Build das imagens + sobe novos containers |
| 5.1-5.6 | Verifica status + health check + conectividade DB |

### Como rodar:

```bash
cd ansible-playbooks

# Deploy da versão latest
ansible-playbook -i inventories/hosts.yml cenario2-deploy-staging.yml

# Deploy de uma versão específica
ansible-playbook -i inventories/hosts.yml cenario2-deploy-staging.yml --extra-vars "app_version=v1.2.0"
```

### Resultado esperado:

```
✅ Código atualizado do GitLab
✅ Containers antigos removidos
✅ Imagens rebuildadas
✅ Banco rodando e respondendo
✅ Backend conectado ao banco
✅ Frontend acessível
✅ Health check OK
✅ Deploy concluído com sucesso!
```

---

## 📁 Estrutura do Projeto

```
techcorp-devops-automacao/
├── ansible-playbooks/
│   ├── cenario1-provisioning.yml      # Cenário 1: Provisionamento (dev01/dev02)
│   ├── cenario2-deploy-staging.yml    # Cenário 2: Deploy na homologação
│   ├── inventories/
│   │   └── hosts.yml                  # Inventário (todos os grupos de máquinas)
│   └── group_vars/
│       └── all.yml                    # Variáveis globais (IPs das máquinas)
│
├── app-homologacao/                   # Aplicação de exemplo (all-in-one)
│   ├── backend/                       # API Node.js/Express
│   ├── frontend/                      # Frontend HTML/JS (nginx)
│   ├── docker-compose.yml
│   └── init.sql                       # Schema do banco
│
├── setup-gateway.sh                   # Gateway   (.101) - NAT + Load Balancer
├── setup-dns.sh                       # DNS       (.53)  - bind9
├── setup-gitlab.sh                    # GitLab    (.100) - GitLab CE (Docker)
├── setup-operacao.sh                  # Operação  (.151) - Ansible control node
├── setup-webserver.sh                 # Webserver (.140) - nginx
├── setup-dbserver.sh                  # DB Server (.130) - MariaDB
├── setup-homologacao.sh               # Homolog.  (.150) - app all-in-one
├── setup-dev01.sh                     # Dev01     (.201) - backend (Java 17)
├── setup-dev02.sh                     # Dev02     (.202) - frontend (Node.js)
│
├── master-setup.sh                    # Configura todas as VMs (a partir do host)
├── verificar-tudo.sh                  # Verificação geral da rede/serviços
├── atualizar-app.sh                   # Simula deploy de nova versão (homologação)
└── README.md                          # Este arquivo
```

---

## 🔧 Pré-requisitos

### Para os Cenários (Ansible):

1. **Máquina de Operação** com Ansible instalado
2. **Chave SSH** compartilhada entre as máquinas
3. **Acesso SSH** para o usuário `sysadmin` em todas as máquinas
4. **Docker** já instalado nas máquinas (ou instale via Cenário 1)

### Para a Aplicação:

1. **GitLab** com o repositório `app-homologacao` (VM `gitlab`, .100)
2. **Token de acesso** ao GitLab API (para cadastro de chaves SSH)

> **Java 17** (não 21): o Java 21 não estava disponível no ambiente-alvo, então os scripts usam `openjdk-17-jdk`.

---

## 🖥️ Endereços dos Serviços

| Serviço | URL | Porta |
|---------|-----|-------|
| Load Balancer (gateway) | http://192.168.13.101 | 80 |
| Webserver (nginx) | http://192.168.13.140 | 80 |
| GitLab | http://192.168.13.202 | 80 |
| Frontend (homologação) | http://192.168.13.150 | 80 |
| Backend API (homologação) | http://192.168.13.150:8080 | 8080 |
| Banco homologação (MySQL) | 192.168.13.150:3306 | 3306 |
| DB Server (MariaDB) | 192.168.13.201:3306 | 3306 |
| DNS (bind9) | 192.168.13.53 | 53 |
| Health Check | http://192.168.13.150:8080/api/health | - |

---

## 📊 Comandos Úteis

```bash
# Verificar status dos containers (homologação)
docker ps

# Ver logs do backend
docker logs techcorp-backend -f

# Testar API
curl http://192.168.13.150:8080/api/health | jq .

# Resolver nomes pelo DNS interno
dig @192.168.13.53 homologacao.techcorp.com.br

# Conectar no servidor de banco MariaDB
mysql -h 192.168.13.201 -u app_user -p techcorp_homologacao

# Reiniciar apenas o backend
docker restart techcorp-backend

# Parar tudo (na homologação)
cd /opt/app-homologacao && docker compose down
```

---

## 🎓 Conceitos Demonstrados

| Conceito | Onde é usado |
|----------|--------------|
| **Idempotência** | Playbooks podem ser rodados várias vezes sem efeitos colaterais |
| **Inventory** | Gerenciamento de múltiplas máquinas por grupo |
| **Separação de responsabilidades** | Uma VM por função (DNS, GitLab, web, banco, etc.) |
| **Roles / Variables** | Perfil por máquina (dev01 backend, dev02 frontend) |
| **Handlers** | Reiniciar serviços quando necessário |
| **Health Checks** | Verificação de saúde dos serviços |

---

## 🏢 Empresa (Simulação)

**TechCorp Soluções** (hipotética)
- Segmento: Tecnologia da Informação
- Stack: Node.js + MySQL/MariaDB + Docker
- Metodologia: Agile/Scrum
- CI/CD: GitLab CI + Ansible
- Infraestrutura: VMs no VirtualBox (rede interna)

---

## 👥 Créditos

Projeto desenvolvido para a disciplina de DevOps - Prof. Robson
