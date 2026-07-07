# GUIA COMPLETO - Automação DevOps TechCorp

**Para quem não entende nada** - vou explicar tudo passo a passo, como se você tivesse 5 anos.

---

## O QUE É ISSO TUDO?

Imagina que você trabalha numa empresa de TI chamada **TechCorp**. Essa empresa tem vários computadores (máquinas virtuais) que precisam estar configurados igualzinhos para os programadores trabalharem.

**O problema:** Se cada programador configurar sua máquina do jeito que quiser, vai dar errado. Um usa uma versão do programa, outro usa outra, e quando juntam o código não funciona.

**A solução:** Criamos uns scripts (arquivos de texto com comandos) que configuram tudo automaticamente. Você roda um comando e a máquina se configura sozinha.

---

## AS MÁQUINAS

A empresa tem 9 máquinas virtuais:

| Máquina | IP | O que ela faz |
|---------|-----|---------------|
| **Gateway** | 192.168.13.101 | É o "roteador" - dá internet para todas as outras e distribui o trabalho |
| **DNS** | 192.168.13.53 | Traduz nomes (ex.: homologacao.techcorp.com.br) em IPs |
| **GitLab** | 192.168.13.100 | Guarda o código e roda o CI (via Docker) |
| **Operação** | 192.168.13.151 | É o "chefe" - controla e configura todas as outras remotamente |
| **Webserver** | 192.168.13.140 | Servidor web dedicado (nginx) |
| **DB Server** | 192.168.13.130 | Servidor de banco de dados (MariaDB) |
| **Homologação** | 192.168.13.150 | Onde testamos o programa completo antes de entregar (tudo-em-um) |
| **Dev01** | 192.168.13.201 | Máquina do programador backend (Java 17) |
| **Dev02** | 192.168.13.202 | Máquina do programador frontend (Node.js) |

---

## O QUE CADA SCRIPT FAZ

### setup-gateway.sh (Gateway)
- Configura a rede (IP, máscara, gateway)
- Ativa o NAT (para as outras máquinas terem internet)
- Instala o Nginx (balanceador de carga - distribui o trabalho entre Dev01 e Dev02)

### setup-operacao.sh (Operação)
- Configura a rede
- Instala o Ansible (ferramenta que configura as outras máquinas remotamente)
- Instala o Docker
- Copia a chave SSH para as outras máquinas (para poder acessar sem senha)

### setup-dev01.sh (Desenvolvimento Backend)
- Configura a rede
- Instala Docker (para rodar programas em caixas isoladas)
- Instala JDK 17 (para programar em Java/Spring Boot)
- Instala Git e VS Code
- Gera chave SSH (para se conectar na operação)

### setup-dev02.sh (Desenvolvimento Frontend)
- Configura a rede
- Instala Docker
- Instala Node.js LTS + npm/Yarn/pnpm e CLIs de frontend (Vite, Angular, Vue)
- Instala Git e VS Code (com extensões de frontend)
- Gera chave SSH

### setup-homologacao.sh (Homologação)
- Configura a rede
- Instala Docker
- Cria a aplicação completa (Backend + Frontend + Banco de Dados)
- Sobe os containers (caixas com os programas rodando)

### setup-dns.sh (DNS)
- Configura a rede
- Instala o bind9 e cria a zona techcorp.com.br (traduz nomes em IPs)

### setup-gitlab.sh (GitLab)
- Configura a rede
- Instala Docker e sobe o GitLab CE (código + CI). Leva alguns minutos no 1º boot

### setup-webserver.sh (Webserver)
- Configura a rede
- Instala o nginx e sobe uma página web dedicada

### setup-dbserver.sh (DB Server)
- Configura a rede
- Instala o MariaDB, cria o banco techcorp_homologacao e libera acesso pela rede

### verificar-tudo.sh
- Testa se todas as máquinas estão respondendo (ping)
- Testa se consegue acessar via SSH
- Mostra quais serviços estão rodando

---

## PASSO A PASSO PARA EXECUTAR

### PASSO 1: Preparar as máquinas

1. **Abra o VirtualBox** no seu computador
2. **Ligue as máquinas virtuais** (gateway, dns, gitlab, operacao, webserver, dbserver, homologacao, dev01, dev02)
3. **Espere todas iniciarem** (aparecer o login)

### PASSO 2: Copiar os scripts para dentro das máquinas

Os scripts estão na pasta `devops-workstation/` do seu projeto. Você precisa copiar essa pasta para dentro de cada máquina virtual.

**Como copiar:**

1. Na máquina virtual, abra o terminal
2. Monte a pasta compartilhada:
```bash
sudo mount -t vboxsf devops-workstation /mnt
```
3. Copie os scripts:
```bash
cp -r /mnt/* ~/
```

**Repetir para cada máquina:** gateway, dns, gitlab, operacao, webserver, dbserver, homologacao, dev01, dev02

### PASSO 3: Rodar os scripts NA ORDEM

**ATENÇÃO: A ordem importa!** Execute nesta ordem exata:

#### 3.1 - Gateway PRIMEIRO
```bash
# Na máquina Gateway
cd ~
sudo ./setup-gateway.sh
```

Espere terminar. Vai aparecer "GATEWAY CONFIGURADO!" quando acabar.

#### 3.1b - DNS, DB Server, GitLab e Webserver (depois do Gateway)
```bash
# Na máquina DNS
sudo ./setup-dns.sh

# Na máquina DB Server
sudo ./setup-dbserver.sh

# Na máquina GitLab (leva alguns minutos no 1º boot)
sudo ./setup-gitlab.sh

# Na máquina Webserver
sudo ./setup-webserver.sh
```

#### 3.2 - Operação SEGUNDO
```bash
# Na máquina Operação
cd ~
sudo ./setup-operacao.sh
```

Espere terminar. Pode pedir a senha do `sysadmin` nas outras máquinas - digite a senha que você criou.

#### 3.3 - Dev01 TERCEIRO
```bash
# Na máquina Dev01
cd ~
sudo ./setup-dev01.sh
```

#### 3.4 - Dev02 QUARTO
```bash
# Na máquina Dev02
cd ~
sudo ./setup-dev02.sh
```

#### 3.5 - Homologação QUINTO
```bash
# Na máquina Homologação
cd ~
sudo ./setup-homologacao.sh
```

### PASSO 4: Verificar se tudo funcionou

Na **máquina Operação** (ou qualquer uma), rode:
```bash
cd ~
./verificar-tudo.sh
```

Vai aparecer algo assim:
```
1. Teste de rede (ping)
  ✓ gateway (192.168.13.101)
  ✓ operacao (192.168.13.151)
  ✓ dev01 (192.168.13.201)
  ✓ dev02 (192.168.13.202)
  ✓ homologacao (192.168.13.150)

2. Teste SSH
  ✓ SSH para gateway
  ✓ SSH para operacao
  ...
```

Se tiver algum ✗ (erro), significa que aquela máquina não está respondendo.

---

## COMO TESTAR SE ESTÁ FUNCIONANDO

### Teste 1: Ping entre máquinas

Na **Operação**, teste se consegue acessar as outras:
```bash
ping -c 1 dev01
ping -c 1 dev02
ping -c 1 homologacao
```

Se aparecer "64 bytes from..." está funcionando.

### Teste 2: SSH (acesso remoto)

Na **Operação**, acesse a Dev01 remotamente:
```bash
ssh sysadmin@dev01 hostname
```

Se aparecer "dev01" é porque funcionou.

### Teste 3: Aplicação de Homologação

1. Abra o navegador no seu computador (fora das máquinas virtuais)
2. Acesse: `http://192.168.13.150`
3. Deve aparecer a página da TechCorp com os projetos

### Teste 4: API Backend

No navegador, acesse:
```
http://192.168.13.150:8080/api/health
```

Deve aparecer algo assim:
```json
{"status":"healthy","version":"1.0.0","deployTime":"2024-..."}
```

---

## COMO SIMULAR UM DEPLOY (PARA MOSTRAR AO PROFESSOR)

### Passo 1: Fazer o deploy da versão 2.0.0

Na **máquina Homologação**:
```bash
cd ~
./atualizar-app.sh v2.0.0
```

### Passo 2: Verificar que mudou

1. Abra o navegador em `http://192.168.13.150`
2. Veja que a versão mudou para `v2.0.0`
3. Veja que apareceu um badge "NOVO!"

### Passo 3: Testar a API

No navegador, acesse:
```
http://192.168.13.150:8080/api/projects
```

Deve listar os projetos do banco de dados.

---

## COMANDOS ÚTEIS

### Na Operação (para verificar tudo)

```bash
# Verificar se as máquinas estão respondendo
ping -c 1 dev01
ping -c 1 dev02

# Acessar remotamente
ssh sysadmin@dev01

# Ver inventário do Ansible
cat ~/ansible/inventory
```

### Na Homologação (para gerenciar a aplicação)

```bash
# Ver status dos containers
docker ps

# Reiniciar a aplicação
cd /opt/app-homologacao
docker compose restart

# Ver logs do backend
docker logs techcorp-backend -f

# Parar tudo
docker compose down

# Subir tudo de novo
docker compose up -d
```

### Na Dev01 ou Dev02

```bash
# Ver se Docker está rodando
docker ps

# Ver se Java está instalado
java --version

# Ver se Git está configurado
git config --list
```

---

## SE ALGO DER ERRADO

### "Ping não funciona"
1. Verifique se a máquina está ligada
2. Verifique se o IP está correto: `ip a`
3. Verifique se o script de rede rodou: `cat /etc/network/interfaces`

### "SSH não funciona"
1. Verifique se o SSH está rodando: `systemctl status ssh`
2. Verifique se a chave está no lugar: `ls ~/.ssh/`
3. Tente copiar a chave manualmente: `ssh-copy-id sysadmin@dev01`

### "Docker não funciona"
1. Verifique se está rodando: `systemctl status docker`
2. Reinicie: `sudo systemctl restart docker`

### "Aplicação não aparece"
1. Verifique se os containers estão rodando: `docker ps`
2. Veja os logs: `docker logs techcorp-backend`
3. Reinicie: `cd /opt/app-homologacao && docker compose restart`

---

## MAPA DE ARQUIVOS

```
devops-workstation/
├── setup-gateway.sh        # Executar no Gateway
├── setup-dns.sh            # Executar no DNS
├── setup-gitlab.sh         # Executar no GitLab
├── setup-operacao.sh       # Executar na Operação
├── setup-webserver.sh      # Executar no Webserver
├── setup-dbserver.sh       # Executar no DB Server
├── setup-homologacao.sh    # Executar na Homologação
├── setup-dev01.sh          # Executar no Dev01 (backend)
├── setup-dev02.sh          # Executar no Dev02 (frontend)
├── master-setup.sh         # Configura todas as VMs de uma vez
├── verificar-tudo.sh       # Verificar tudo
├── atualizar-app.sh        # Fazer deploy (só na Homologação)
└── README.md               # Este guia
```

---

## RESUMO RÁPIDO

1. **Copie** a pasta `devops-workstation` para dentro de cada máquina
2. **Execute** os scripts na ordem: gateway → dns → dbserver → gitlab → webserver → operacao → dev01 → dev02 → homologacao
3. **Verifique** com `verificar-tudo.sh`
4. **Teste** a aplicação em `http://192.168.13.150`
5. **Simule deploy** com `./atualizar-app.sh v2.0.0`

Pronto! Sua empresa DevOps está funcionando! 🚀
