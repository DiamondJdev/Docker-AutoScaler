const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'scalable_backend',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  max: 10000,                     // Reduced to 10000 to avoid overwhelming PostgreSQL
  min: 10,                     // Increased minimum connections for faster response
  idleTimeoutMillis: 30000,    // Reduced idle timeout for better connection turnover
  connectionTimeoutMillis: 200000, // Increased connection timeout to 20 seconds
  acquireTimeoutMillis: 60000, // Increased acquire timeout to 60 seconds
  allowExitOnIdle: false,      // Keep pool alive
  maxUses: 7500,              // Rotate connections to prevent memory leaks
});

async function initDatabase() {
  try {
    // Test connection
    await pool.query('SELECT NOW()');
    
    // Create tables if they don't exist
    await createTables();
    
    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Database initialization failed:', error);
    throw error;
  }
}

async function createTables() {
  const createUsersTable = `
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) UNIQUE NOT NULL,
      username VARCHAR(100) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;

  const createTasksTable = `
    CREATE TABLE IF NOT EXISTS tasks (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      title VARCHAR(255) NOT NULL,
      description TEXT,
      status VARCHAR(50) DEFAULT 'pending',
      priority VARCHAR(20) DEFAULT 'medium',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;

  const createIndexes = `
    CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);
    CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
  `;

  await pool.query(createUsersTable);
  await pool.query(createTasksTable);
  await pool.query(createIndexes);
}

// Query helper function with retry logic
async function query(text, params, retries = 3) {
  const start = Date.now();
  
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await pool.query(text, params);
      const duration = Date.now() - start;
      console.log('Executed query', { text, duration, rows: res.rowCount, attempt });
      return res;
    } catch (error) {
      const duration = Date.now() - start;
      
      // If it's a connection timeout or pool exhaustion, retry
      if ((error.message.includes('timeout') || error.message.includes('Connection terminated')) && attempt < retries) {
        console.log(`Query attempt ${attempt} failed (${duration}ms), retrying...`, { text: text.substring(0, 50), error: error.message });
        await new Promise(resolve => setTimeout(resolve, Math.min(1000 * attempt, 5000))); // Exponential backoff
        continue;
      }
      
      console.error('Query failed after all retries', { text, duration, attempt, error: error.message });
      throw error;
    }
  }
}

module.exports = {
  initDatabase,
  query,
  pool
}; 