const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.POSTGRES_USER || 'user',
  host: process.env.POSTGRES_HOST || 'db', // 'db' is the service name in docker-compose
  database: process.env.POSTGRES_DB || 'sovr_payroll',
  password: process.env.POSTGRES_PASSWORD || 'password',
  port: process.env.POSTGRES_PORT || 5432,
});

const initializeDb = async () => {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS events (
        id SERIAL PRIMARY KEY,
        claim_tx_hash VARCHAR(66) UNIQUE NOT NULL,
        employee_address VARCHAR(42) NOT NULL,
        amount_usd NUMERIC(18, 2) NOT NULL,
        status VARCHAR(50) NOT NULL,
        stripe_transfer_id VARCHAR(255),
        stripe_mode VARCHAR(10),
        reconcile_tx_hash VARCHAR(66),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('[DB] "events" table initialized.');

    await client.query(`
      CREATE TABLE IF NOT EXISTS proofs (
        id SERIAL PRIMARY KEY,
        file_name VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('[DB] "proofs" table initialized.');

  } catch (err) {
    console.error('[DB] Error initializing database schema:', err);
  } finally {
    client.release();
  }
};

module.exports = {
  query: (text, params) => pool.query(text, params),
  initializeDb,
};