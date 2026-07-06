# TechCorp - Automação DevOps com Ansible

Automação completa para ambiente de desenvolvimento corporativo, cobrindo dois cenários reais de uso do Ansible.

## 📋 Visão Geral dos Cenários

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         OPERAÇÃO (Control Node)                            │
│                              192.168.13.151                                 │
│                    ┌─────────────────────────────┐                         │
│                    │      ansible-playbook       │                         │
│                    └──────────┬──────────────────┘                         │
│                               │                                            │
│            ┌──────────────────┼──────────────────┐                         │
│            │                  │                  │                          │
│            ▼                  ▼                  ▼                          │
│   ┌────────────────┐ ┌────────────────┐ ┌────────────────┐                │
│   │    DEV01       │ │    DEV02       │ │ HOMOLOGAÇÃO    │                │
│   │  192.168.13.201│ │  192.168.13.202│ │ 192.168.13.150 │                │
│   │                │ │                │ │                │                 │
│   │ Cenário 1:     │ │ Cenário 1:     │ │ Cenário 2:     │                │
│   │ Provisionamento│ │ Provisionamento│ │ Deploy         │                │
│   └────────────────┘ └────────────────┘ └────────────────┘                │
│            │                  │                  │                          │
│            └──────────────────┼──────────────────┘                         │
│                               ▼                                            │
│                    ┌─────────────────────────────┐                         │
│                    │      GitLab Server          │                         │
│                    │   192.168.13.100 (exemplo)  │                         │
│                    └─────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Cenário 1: Provisionamento Padronizado de Máquinas Dev

### O problema
"Síndrome da minha máquina funciona" - cada desenvolvedor tem um ambiente diferente.

### A solução
Ansible provisiona **automaticamente** as máquinas Dev01 e Dev02 com exatamente as mesmas ferramentas.

### O que o Ansible faz:

| Etapa | O que instala/configura |
|-------|------------------------|
| 1.1 | Dependências de sistema (git, curl, build-essential, etc.) |
| 2.1-2.7 | Docker Engine + Docker Compose + permissões |
| 3.1-3.6 | JDK 21 + Maven + Gradle (para Spring Boot) |
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
✅ JDK 21 configurado
✅ Chave SSH gerada e cadastrada no GitLab
✅ VS Code com extensões
✅ Ambiente pronto para desenvolvimento!
```

---

## 🚀 Cenário 2: Deploy Automatizado no Ambiente de Homologação

### O problema
Deploy manual é lento, propenso a erros e difícil de reproduzir.

### A solução
Ansible faz **pull do código → build → deploy → verificação** automaticamente.

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
✅ MySQL rodando e respondendo
✅ Backend conectado ao banco
✅ Frontend acessível
✅ Health check OK
✅ Deploy concluído com sucesso!
```

---

## 📁 Estrutura do Projeto

```
devops-workstation/
├── ansible-playbooks/
│   ├── cenario1-provisioning.yml      # Cenário 1: Provisionamento
│   ├── cenario2-deploy-staging.yml    # Cenário 2: Deploy
│   ├── inventories/
│   │   └── hosts.yml                  # Inventário de máquinas
│   └── group_vars/
│       └── all.yml                    # Variáveis globais
│
├── app-homologacao/                   # Aplicação de exemplo
│   ├── backend/                       # API Node.js/Express
│   │   ├── server.js
│   │   ├── package.json
│   │   └── Dockerfile
│   ├── frontend/                      # Frontend HTML/JS
│   │   ├── index.html
│   │   └── Dockerfile
│   ├── docker-compose.yml
│   └── init.sql                       # Schema do banco
│
├── setup.sh                           # Instalação local (estação dev)
├── scripts/
│   ├── workstation.sh                 # Módulo: Estação de trabalho
│   ├── devops.sh                      # Módulo: Ferramentas DevOps
│   └── database.sh                    # Módulo: Bancos de dados
│
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

1. **GitLab** com o repositório `app-homologacao`
2. **Token de acesso** ao GitLab API (para cadastro de chaves SSH)

---

## 🖥️ Endereços dos Serviços

| Serviço | URL | Porta |
|---------|-----|-------|
| Frontend | http://192.168.13.150 | 80 |
| Backend API | http://192.168.13.150:8080 | 8080 |
| MySQL | 192.168.13.150:3306 | 3306 |
| Health Check | http://192.168.13.150:8080/api/health | - |

---

## 📊 Comandos Úteis

```bash
# Verificar status dos containers
docker ps

# Ver logs do backend
docker logs techcorp-backend -f

# Ver logs do banco
docker logs techcorp-db -f

# Testar API
curl http://localhost:8080/api/health | jq .

# Listar projetos via API
curl http://localhost:8080/api/projects | jq .

# Listar deploys via API
curl http://localhost:8080/api/deploys | jq .

# Reiniciar apenas o backend
docker restart techcorp-backend

# Parar tudo
docker-compose down

# Limpar volumes (cuidado!)
docker-compose down -v
```

---

## 🎓 Conceitos Demonstrados

| Conceito | Onde é usado |
|----------|--------------|
| **Idempotência** | Playbooks podem ser rodados várias vezes sem efeitos colaterais |
| **Inventory** | Gerenciamento de múltiplas máquinas |
| **Roles** | Organização do código |
| **Handlers** | Reiniciar serviços quando necessário |
| **Variables** | Configuração parametrizada |
| **Templates** | Configurações dinâmicas |
| **Health Checks** | Verificação de saúde dos serviços |
| **Zero-downtime** | Deploy sem interrupção do serviço |

---

## 🏢 Empresa (Simulação)

**TechCorp Soluções** (hipotética)
- Segmento: Tecnologia da Informação
- Stack: Node.js + MySQL + Docker
- Metodologia: Agile/Scrum
- CI/CD: GitLab CI + Ansible
- Infraestrutura: Docker + Kubernetes (produção)

---

## 👥 Créditos

Projeto desenvolvido para a disciplina de DevOps - Prof. Robson
