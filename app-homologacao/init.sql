-- TechCorp Homologação - Schema inicial
CREATE DATABASE IF NOT EXISTS techcorp_homologacao;
USE techcorp_homologacao;

-- Tabela de usuários
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    role ENUM('admin', 'dev', 'ops', 'viewer') DEFAULT 'dev',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de projetos
CREATE TABLE IF NOT EXISTS projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    status ENUM('active', 'archived', 'draft') DEFAULT 'draft',
    created_by INT,
    FOREIGN KEY (created_by) REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de deploys
CREATE TABLE IF NOT EXISTS deployments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    version VARCHAR(50) NOT NULL,
    environment ENUM('dev', 'staging', 'prod') DEFAULT 'staging',
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

INSERT INTO projects (name, description, status, created_by) VALUES
('Portal Clientes', 'Sistema de gestão de clientes', 'active', 1),
('API Gateway', 'Gateway de APIs internas', 'active', 2),
('Dashboard Ops', 'Painel de monitoramento', 'draft', 3);

INSERT INTO deployments (project_id, version, environment, status, deployed_by) VALUES
(1, 'v1.0.0', 'staging', 'success', 1),
(2, 'v1.2.0', 'staging', 'success', 2),
(1, 'v1.1.0', 'staging', 'running', 1);
