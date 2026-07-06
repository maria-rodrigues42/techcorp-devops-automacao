#!/usr/bin/env bash
#
# database.sh - Setup de Banco de Dados (Docker)
#
# Instala: MySQL 8, MariaDB, Redis, Adminer, pgAdmin (para referência)
#
set -uo pipefail

log()  { echo -e "\033[1;34m[database]\033[0m $*"; }
ok()   { echo -e "  \033[1;32m✓\033[0m $*"; }
warn() { echo -e "  \033[1;33m⚠\033[0m $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ================== Docker Compose para bancos ==================
log "Criando Docker Compose para bancos de dados..."

mkdir -p "${PROJECT_DIR}/docker"

cat > "${PROJECT_DIR}/docker/docker-compose.yml" <<'COMPOSE'
version: "3.9"

services:
  # ================== MySQL 8 ==================
  mysql:
    image: mysql:8.0
    container_name: techcorp-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: techcorp_root_2024
      MYSQL_DATABASE: techcorp_main
      MYSQL_USER: dev
      MYSQL_PASSWORD: dev_password_2024
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./init/mysql:/docker-entrypoint-initdb.d
    networks:
      - db-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ================== MariaDB 11 ==================
  mariadb:
    image: mariadb:11
    container_name: techcorp-mariadb
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: techcorp_root_2024
      MYSQL_DATABASE: techcorp_legacy
      MYSQL_USER: dev_legacy
      MYSQL_PASSWORD: dev_password_2024
    ports:
      - "3307:3306"
    volumes:
      - mariadb_data:/var/lib/mysql
      - ./init/mariadb:/docker-entrypoint-initdb.d
    networks:
      - db-network
    healthcheck:
      test: ["CMD", "mariadb-admin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ================== Redis ==================
  redis:
    image: redis:7-alpine
    container_name: techcorp-redis
    restart: always
    command: redis-server --requirepass redis_password_2024 --maxmemory 256mb --maxmemory-policy allkeys-lru
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
      - ./config/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - db-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "redis_password_2024", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ================== Adminer (UI web para MySQL/MariaDB) ==================
  adminer:
    image: adminer:latest
    container_name: techcorp-adminer
    restart: always
    ports:
      - "8080:8080"
    environment:
      ADMINER_DEFAULT_SERVER: mysql
      ADMINER_DESIGN: dracula
    networks:
      - db-network

  # ================== Redis Insight (UI Redis) ==================
  redis-insight:
    image: redis/redisinsight:latest
    container_name: techcorp-redis-insight
    restart: always
    ports:
      - "5540:5540"
    volumes:
      - redis_insight_data:/data
    networks:
      - db-network

volumes:
  mysql_data:
  mariadb_data:
  redis_data:
  redis_insight_data:

networks:
  db-network:
    driver: bridge
COMPOSE

# ================== Scripts de init MySQL ==================
log "Criando scripts de inicialização..."

mkdir -p "${PROJECT_DIR}/docker/init/mysql"
cat > "${PROJECT_DIR}/docker/init/mysql/01-schema.sql" <<'SQL'
-- TechCorp Schema - MySQL
USE techcorp_main;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    role ENUM('admin', 'dev', 'ops', 'viewer') DEFAULT 'dev',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    repo_url VARCHAR(255),
    status ENUM('active', 'archived', 'draft') DEFAULT 'draft',
    created_by INT,
    FOREIGN KEY (created_by) REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS deployments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    version VARCHAR(50) NOT NULL,
    environment ENUM('dev', 'staging', 'prod') DEFAULT 'dev',
    status ENUM('pending', 'running', 'success', 'failed') DEFAULT 'pending',
    deployed_by INT,
    FOREIGN KEY (project_id) REFERENCES projects(id),
    FOREIGN KEY (deployed_by) REFERENCES users(id),
    deployed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dados de exemplo
INSERT INTO users (name, email, role) VALUES
('João Silva', 'joao@techcorp.com.br', 'admin'),
('Maria Santos', 'maria@techcorp.com.br', 'dev'),
('Pedro Costa', 'pedro@techcorp.com.br', 'ops');

INSERT INTO projects (name, description, repo_url, status, created_by) VALUES
('Portal Clientes', 'Sistema de gestão de clientes', 'https://gitlab.techcorp.com.br/devops/portal-clientes', 'active', 1),
('API Gateway', 'Gateway de APIs internas', 'https://gitlab.techcorp.com.br/devops/api-gateway', 'active', 2),
('Dashboard Ops', 'Painel de monitoramento', 'https://gitlab.techcorp.com.br/devops/dashboard', 'draft', 3);
SQL

# ================== Scripts de init MariaDB ==================
mkdir -p "${PROJECT_DIR}/docker/init/mariadb"
cat > "${PROJECT_DIR}/docker/init/mariadb/01-legacy-schema.sql" <<'SQL'
-- TechCorp Legacy - MariaDB
USE techcorp_legacy;

CREATE TABLE IF NOT EXISTS legacy_orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100),
    product VARCHAR(100),
    amount DECIMAL(10,2),
    order_date DATE,
    status ENUM('pending', 'shipped', 'delivered') DEFAULT 'pending'
);

INSERT INTO legacy_orders (customer_name, product, amount, order_date, status) VALUES
('Empresa A', 'Licença Enterprise', 15000.00, '2024-01-15', 'delivered'),
('Empresa B', 'Suporte Anual', 8000.00, '2024-02-20', 'shipped'),
('Startup X', 'Plano Pro', 2500.00, '2024-03-10', 'pending');
SQL

# ================== Config Redis ==================
mkdir -p "${PROJECT_DIR}/docker/config"
cat > "${PROJECT_DIR}/docker/config/redis.conf" <<'REDISCONF'
# TechCorp Redis Configuration
bind 0.0.0.0
protected-mode yes
port 6379
databases 16
save 900 1
save 300 10
save 60 10000
rdbcompression yes
rdbchecksum yes
appendonly yes
appendfsync everysec
maxmemory 256mb
maxmemory-policy allkeys-lru
REDISCONF

# ================== Scripts auxiliares ==================
log "Criando scripts de gerenciamento..."

# Script para subir tudo
cat > "${PROJECT_DIR}/docker/start.sh" <<'STARTSCRIPT'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🚀 TechCorp - Subindo bancos de dados..."
cd "$SCRIPT_DIR"
docker compose up -d
echo
echo "✅ Serviços rodando:"
echo "   MySQL:      localhost:3306  (user: dev / pass: dev_password_2024)"
echo "   MariaDB:    localhost:3307  (user: dev_legacy / pass: dev_password_2024)"
echo "   Redis:      localhost:6379  (pass: redis_password_2024)"
echo "   Adminer:    http://localhost:8080"
echo "   Redis Insight: http://localhost:5540"
echo
echo "📊 Status:"
docker compose ps
STARTSCRIPT
chmod +x "${PROJECT_DIR}/docker/start.sh"

# Script para parar
cat > "${PROJECT_DIR}/docker/stop.sh" <<'STOPSCRIPT'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "⏹️  TechCorp - Parando bancos de dados..."
cd "$SCRIPT_DIR"
docker compose down
echo "✅ Todos os serviços parados."
STOPSCRIPT
chmod +x "${PROJECT_DIR}/docker/stop.sh"

# Script para backup
cat > "${PROJECT_DIR}/docker/backup.sh" <<'BACKUPSCRIPT'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "💾 TechCorp - Backup dos bancos de dados..."

echo "  📦 MySQL..."
docker exec techcorp-mysql mysqldump -u root -ptechcorp_root_2024 --all-databases > "$BACKUP_DIR/mysql_all.sql" 2>/dev/null

echo "  📦 MariaDB..."
docker exec techcorp-mariadb mysqldump -u root -ptechcorp_root_2024 --all-databases > "$BACKUP_DIR/mariadb_all.sql" 2>/dev/null

echo "  📦 Redis..."
docker exec techcorp-redis redis-cli -a redis_password_2024 BGSAVE 2>/dev/null
sleep 2
docker cp techcorp-redis:/data/dump.rdb "$BACKUP_DIR/redis_dump.rdb" 2>/dev/null || true

echo "✅ Backup completo em: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
BACKUPSCRIPT
chmod +x "${PROJECT_DIR}/docker/backup.sh"

ok "Scripts de gerenciamento criados"

# ================== Subir os containers ==================
log "Iniciando containers de banco de dados..."
cd "${PROJECT_DIR}/docker"
docker compose up -d

# Aguardar MySQL ficar pronto
log "Aguardando MySQL..."
for i in $(seq 30); do
  if docker exec techcorp-mysql mysqladmin ping -h localhost -u root -ptechcorp_root_2024 2>/dev/null | grep -q alive; then
    ok "MySQL pronto"
    break
  fi
  sleep 2
done

log "Aguardando MariaDB..."
for i in $(seq 30); do
  if docker exec techcorp-mariadb mariadb-admin ping -h localhost -u root -ptechcorp_root_2024 2>/dev/null | grep -q alive; then
    ok "MariaDB pronto"
    break
  fi
  sleep 2
done

log "Aguardando Redis..."
for i in $(seq 10); do
  if docker exec techcorp-redis redis-cli -a redis_password_2024 ping 2>/dev/null | grep -q PONG; then
    ok "Redis pronto"
    break
  fi
  sleep 1
done

echo
ok "Banco de dados configurados!"
echo
