# GUIA RÁPIDO - Copie e Cole

Abra o terminal em cada VM e cole os comandos na ordem.

---

## 1. GATEWAY (abra a VM "gateway")

Cole este bloco COMPLETO no terminal:

```bash
sudo bash -c '
IP="192.168.13.101"
NETMASK="255.255.255.0"

# Rede
LAN_IFACE=$(ip -4 addr show | grep -oP "en\w+|eth\w+" | head -1)
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback
auto ${LAN_IFACE}
iface ${LAN_IFACE} inet static
    address ${IP}
    netmask ${NETMASK}
EOF

# Hostname
echo "gateway" > /etc/hostname
hostname gateway

# /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1   localhost
192.168.13.101   gateway
192.168.13.151   operacao
192.168.13.201   dev01
192.168.13.202   dev02
192.168.13.150   homologacao
EOF

# DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Usuário
useradd -m -s /bin/bash sysadmin 2>/dev/null
echo "sysadmin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sysadmin

# SSH
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server curl iptables nginx >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null

# NAT
mkdir -p /etc/firewall
cat > /etc/firewall/internet.sh << FIREWALL
#!/bin/bash
ETH=\$(ip route | grep default | awk "{print \$5}" | head -1)
LAN="192.168.13.0/24"
for TABELA in filter nat mangle; do iptables -t \$TABELA -F; done
case \$1 in
  start) echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -s \$LAN -o \$ETH -j MASQUERADE;;
  stop) echo 0 > /proc/sys/net/ipv4/ip_forward;;
esac
FIREWALL
chmod +x /etc/firewall/internet.sh
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-techcorp.conf
sysctl -p /etc/sysctl.d/99-techcorp.conf >/dev/null 2>&1
/etc/firewall/internet.sh start

# Load Balancer
cat > /etc/nginx/sites-available/lb << NGINX
upstream backends {
    # Servidor web dedicado (webserver)
    server 192.168.13.140:80;
}
server {
    listen 80 default_server;
    server_name _;
    location / {
        proxy_pass http://backends;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGINX
ln -sf /etc/nginx/sites-available/lb /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo "=========================================="
echo "  GATEWAY CONFIGURADO!"
echo "  IP: 192.168.13.101"
echo "=========================================="
'
```

---

## 2. OPERAÇÃO (abra a VM "operacao")

Cole este bloco COMPLETO no terminal:

```bash
sudo bash -c '
IP="192.168.13.151"
GW="192.168.13.101"

# Rede
LAN_IFACE=$(ip -4 addr show | grep -oP "en\w+|eth\w+" | head -1)
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback
auto ${LAN_IFACE}
iface ${LAN_IFACE} inet static
    address ${IP}
    netmask 255.255.255.0
    gateway ${GW}
EOF

# Hostname
echo "operacao" > /etc/hostname
hostname operacao

# /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1   localhost
192.168.13.101   gateway
192.168.13.151   operacao
192.168.13.201   dev01
192.168.13.202   dev02
192.168.13.150   homologacao
EOF

# DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Usuário
useradd -m -s /bin/bash sysadmin 2>/dev/null
echo "sysadmin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sysadmin

# SSH + Docker + Ansible
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server curl git docker.io ansible >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null
systemctl enable --now docker
usermod -aG docker sysadmin

# Gerar chave SSH
mkdir -p /home/sysadmin/.ssh
chmod 700 /home/sysadmin/.ssh
if [ ! -f /home/sysadmin/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -C "operacao@techcorp.com.br" -f /home/sysadmin/.ssh/id_rsa -N ""
fi
chown -R sysadmin:sysadmin /home/sysadmin/.ssh

echo "=========================================="
echo "  OPERAÇÃO CONFIGURADA!"
echo "  IP: 192.168.13.151"
echo "  Ansible: $(ansible --version | head -1)"
echo "=========================================="
'
```

---

## 3. DEV01 (abra a VM "dev01")

Cole este bloco COMPLETO no terminal:

```bash
sudo bash -c '
IP="192.168.13.201"
GW="192.168.13.101"

# Rede
LAN_IFACE=$(ip -4 addr show | grep -oP "en\w+|eth\w+" | head -1)
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback
auto ${LAN_IFACE}
iface ${LAN_IFACE} inet static
    address ${IP}
    netmask 255.255.255.0
    gateway ${GW}
EOF

# Hostname
echo "dev01" > /etc/hostname
hostname dev01

# /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1   localhost
192.168.13.101   gateway
192.168.13.151   operacao
192.168.13.201   dev01
192.168.13.202   dev02
192.168.13.150   homologacao
EOF

# DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Usuário
useradd -m -s /bin/bash sysadmin 2>/dev/null
echo "sysadmin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sysadmin

# SSH + Docker + Java 17 + Git
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server curl docker.io git openjdk-17-jdk >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null
systemctl enable --now docker
usermod -aG docker sysadmin

# Gerar chave SSH
mkdir -p /home/sysadmin/.ssh
chmod 700 /home/sysadmin/.ssh
if [ ! -f /home/sysadmin/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -C "dev01@techcorp.com.br" -f /home/sysadmin/.ssh/id_rsa -N ""
fi
chown -R sysadmin:sysadmin /home/sysadmin/.ssh

echo "=========================================="
echo "  DEV01 CONFIGURADO!"
echo "  IP: 192.168.13.201"
echo "  Docker: $(docker --version)"
echo "  Java: $(java --version 2>&1 | head -1)"
echo "=========================================="
'
```

---

## 4. DEV02 (abra a VM "dev02")

Cole este bloco COMPLETO no terminal:

```bash
sudo bash -c '
IP="192.168.13.202"
GW="192.168.13.101"

# Rede
LAN_IFACE=$(ip -4 addr show | grep -oP "en\w+|eth\w+" | head -1)
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback
auto ${LAN_IFACE}
iface ${LAN_IFACE} inet static
    address ${IP}
    netmask 255.255.255.0
    gateway ${GW}
EOF

# Hostname
echo "dev02" > /etc/hostname
hostname dev02

# /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1   localhost
192.168.13.101   gateway
192.168.13.151   operacao
192.168.13.201   dev01
192.168.13.202   dev02
192.168.13.150   homologacao
EOF

# DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Usuário
useradd -m -s /bin/bash sysadmin 2>/dev/null
echo "sysadmin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sysadmin

# SSH + Docker + Node.js + Git (dev02 = frontend)
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server curl docker.io git nodejs npm >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null
systemctl enable --now docker
usermod -aG docker sysadmin

# Gerar chave SSH
mkdir -p /home/sysadmin/.ssh
chmod 700 /home/sysadmin/.ssh
if [ ! -f /home/sysadmin/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -C "dev02@techcorp.com.br" -f /home/sysadmin/.ssh/id_rsa -N ""
fi
chown -R sysadmin:sysadmin /home/sysadmin/.ssh

echo "=========================================="
echo "  DEV02 CONFIGURADO!"
echo "  IP: 192.168.13.202"
echo "  Docker: $(docker --version)"
echo "  Node: $(node --version 2>&1)"
echo "=========================================="
'
```

---

## 5. HOMOLOGAÇÃO (abra a VM "homologação" ou use uma existente)

Cole este bloco COMPLETO no terminal:

```bash
sudo bash -c '
IP="192.168.13.150"
GW="192.168.13.101"

# Rede
LAN_IFACE=$(ip -4 addr show | grep -oP "en\w+|eth\w+" | head -1)
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback
auto ${LAN_IFACE}
iface ${LAN_IFACE} inet static
    address ${IP}
    netmask 255.255.255.0
    gateway ${GW}
EOF

# Hostname
echo "homologacao" > /etc/hostname
hostname homologacao

# /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1   localhost
192.168.13.101   gateway
192.168.13.151   operacao
192.168.13.201   dev01
192.168.13.202   dev02
192.168.13.150   homologacao
EOF

# DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Usuário
useradd -m -s /bin/bash sysadmin 2>/dev/null
echo "sysadmin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sysadmin

# SSH + Docker + Git
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server curl docker.io git >/dev/null 2>&1
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null
systemctl enable --now docker
usermod -aG docker sysadmin

# Criar aplicação
APP_DIR="/opt/app-homologacao"
mkdir -p $APP_DIR/backend $APP_DIR/frontend

# Backend
cat > $APP_DIR/backend/package.json << PACKAGE
{"name":"techcorp-backend","version":"1.0.0","main":"server.js","dependencies":{"express":"^4.18.2","mysql2":"^3.6.0"}}
PACKAGE

cat > $APP_DIR/backend/server.js << SERVER
const express = require("express");
const app = express();
const PORT = 8080;
const VERSION = process.env.APP_VERSION || "1.0.0";
app.get("/api/health", (req, res) => res.json({status:"healthy",version:VERSION}));
app.get("/api/projects", (req, res) => res.json({version:VERSION,projects:[{name:"Portal Clientes",status:"active"},{name:"API Gateway",status:"active"}]}));
app.listen(PORT, () => console.log("Backend v"+VERSION+" na porta "+PORT));
SERVER

cat > $APP_DIR/backend/Dockerfile << DOCKERFILE
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
DOCKERFILE

# Frontend
cat > $APP_DIR/frontend/index.html << HTML
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>TechCorp</title>
<style>body{font-family:Arial;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;display:flex;align-items:center;justify-content:center;margin:0}
.card{background:white;padding:40px;border-radius:16px;box-shadow:0 10px 40px rgba(0,0,0,0.2);text-align:center}
h1{color:#667eea}.ver{background:#667eea;color:white;padding:8px 16px;border-radius:20px;display:inline-block;margin:10px 0}</style></head>
<body><div class="card"><h1>TechCorp</h1><p>Homologação</p><div class="ver" id="v">v1.0.0</div>
<script>fetch("http://"+location.hostname+":8080/api/health").then(r=>r.json()).then(d=>{document.getElementById("v").textContent="v"+d.version})</script>
</div></body></html>
HTML

cat > $APP_DIR/frontend/Dockerfile << DOCKERFILE2
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
DOCKERFILE2

# Docker Compose
cat > $APP_DIR/docker-compose.yml << COMPOSE
version: "3.9"
services:
  backend:
    build: ./backend
    restart: always
    ports: ["8080:8080"]
    environment:
      APP_VERSION: "1.0.0"
  frontend:
    build: ./frontend
    restart: always
    ports: ["80:80"]
    depends_on: [backend]
COMPOSE

# Subir containers
cd $APP_DIR
docker compose up -d --build

echo "=========================================="
echo "  HOMOLOGAÇÃO CONFIGURADA!"
echo "  IP: 192.168.13.150"
echo "  Frontend: http://192.168.13.150"
echo "  Backend: http://192.168.13.150:8080/api/health"
echo "=========================================="
'
```

---

## 5b. NOVAS VMs — DNS, GitLab, Webserver, DB Server

Essas VMs têm configuração mais longa (bind9, GitLab, MariaDB), então use os
**scripts dedicados** em vez de colar tudo no terminal. Em cada VM:

```bash
# Monte a pasta compartilhada e copie os scripts (uma vez por VM)
sudo mount -t vboxsf devops-workstation /mnt && cp /mnt/setup-*.sh ~/ && chmod +x ~/setup-*.sh

# DNS (192.168.13.53)
sudo ./setup-dns.sh

# GitLab (192.168.13.100) — leva alguns minutos no 1º boot
sudo ./setup-gitlab.sh

# Webserver (192.168.13.140)
sudo ./setup-webserver.sh

# DB Server (192.168.13.130)
sudo ./setup-dbserver.sh
```

---

## 6. VERIFICAR TUDO (na Operação ou qualquer VM)

Cole este bloco no terminal:

```bash
echo "=========================================="
echo "  Verificando todas as máquinas"
echo "=========================================="
echo

for IP in 192.168.13.101 192.168.13.53 192.168.13.100 192.168.13.151 192.168.13.140 192.168.13.130 192.168.13.201 192.168.13.202 192.168.13.150; do
  NOME=""
  case $IP in
    192.168.13.101) NOME="gateway" ;;
    192.168.13.53)  NOME="dns" ;;
    192.168.13.100) NOME="gitlab" ;;
    192.168.13.151) NOME="operacao" ;;
    192.168.13.140) NOME="webserver" ;;
    192.168.13.130) NOME="dbserver" ;;
    192.168.13.201) NOME="dev01" ;;
    192.168.13.202) NOME="dev02" ;;
    192.168.13.150) NOME="homologacao" ;;
  esac
  if ping -c1 -W2 $IP >/dev/null 2>&1; then
    echo "  ✓ $NOME ($IP)"
  else
    echo "  ✗ $NOME ($IP) - offline"
  fi
done

echo
echo "=========================================="
echo "  Testando API de Homologação"
echo "=========================================="
curl -s http://192.168.13.150:8080/api/health 2>/dev/null | python3 -m json.tool || echo "  API não respondeu"
echo
```

---

## COMO SIMULAR UM DEPLOY

Na **Homologação**, cole:

```bash
# Atualizar para versão 2.0.0
cd /opt/app-homologacao

# Alterar versão no backend
sed -i 's/1.0.0/2.0.0/g' backend/server.js

# Alterar versão no docker-compose
sed -i 's/1.0.0/2.0.0/g' docker-compose.yml

# Reconstruir e reiniciar
docker compose up -d --build

# Verificar
curl -s http://localhost:8080/api/health | python3 -m json.tool
```

Abra o navegador em `http://192.168.13.150` e veja a versão mudar para `v2.0.0`!
