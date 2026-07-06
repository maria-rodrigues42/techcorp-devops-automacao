const express = require('express');
const mysql = require('mysql2/promise');
const app = express();
const PORT = process.env.APP_PORT || 8080;

// Configuração do banco de dados
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'app_user',
  password: process.env.DB_PASSWORD || 'secure_password_2024',
  database: process.env.DB_NAME || 'techcorp_homologacao'
};

// Versão da aplicação (mudará a cada deploy)
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const DEPLOY_TIME = new Date().toISOString();

// Middleware
app.use(express.json());

// CORS para o frontend
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  next();
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    version: APP_VERSION,
    deployTime: DEPLOY_TIME,
    hostname: require('os').hostname(),
    uptime: process.uptime()
  });
});

// Rota principal - informações da aplicação
app.get('/api/info', (req, res) => {
  res.json({
    app: 'TechCorp Portal',
    version: APP_VERSION,
    environment: 'homologacao',
    deployTime: DEPLOY_TIME,
    features: [
      'Gestão de Projetos',
      'Deploy Automatizado',
      'Monitoramento em Tempo Real'
    ]
  });
});

// Rota de exemplo - listar projetos do banco
app.get('/api/projects', async (req, res) => {
  try {
    const connection = await mysql.createConnection(dbConfig);
    const [rows] = await connection.execute('SELECT * FROM projects LIMIT 10');
    await connection.end();
    res.json({
      version: APP_VERSION,
      projects: rows
    });
  } catch (error) {
    res.status(500).json({
      error: 'Erro ao conectar com o banco de dados',
      message: error.message,
      dbHost: dbConfig.host
    });
  }
});

// Rota de exemplo - listar usuários
app.get('/api/users', async (req, res) => {
  try {
    const connection = await mysql.createConnection(dbConfig);
    const [rows] = await connection.execute('SELECT id, name, email, role FROM users LIMIT 10');
    await connection.end();
    res.json({
      version: APP_VERSION,
      users: rows
    });
  } catch (error) {
    res.status(500).json({
      error: 'Erro ao conectar com o banco de dados',
      message: error.message
    });
  }
});

// Rota de exemplo - deploys recentes
app.get('/api/deploys', async (req, res) => {
  try {
    const connection = await mysql.createConnection(dbConfig);
    const [rows] = await connection.execute(`
      SELECT d.*, p.name as project_name
      FROM deployments d
      JOIN projects p ON d.project_id = p.id
      ORDER BY d.deployed_at DESC
      LIMIT 10
    `);
    await connection.end();
    res.json({
      version: APP_VERSION,
      deploys: rows
    });
  } catch (error) {
    res.status(500).json({
      error: 'Erro ao buscar deploys',
      message: error.message
    });
  }
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 TechCorp Backend v${APP_VERSION} rodando na porta ${PORT}`);
  console.log(`📦 Deploy em: ${DEPLOY_TIME}`);
  console.log(`🗄️  Banco: ${dbConfig.host}:${dbConfig.port}/${dbConfig.database}`);
});
