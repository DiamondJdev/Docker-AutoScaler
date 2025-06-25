const express = require('express');
const { pool } = require('../config/database');
const { getClient } = require('../config/redis');

const router = express.Router();

// Basic health check
router.get('/', async (req, res) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'scalable-backend-api',
      version: process.env.npm_package_version || '1.0.0',
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development'
    };

    res.status(200).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Detailed health check with dependencies
router.get('/detailed', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'scalable-backend-api',
    checks: {}
  };

  let overallHealthy = true;

  // Check database
  try {
    const start = Date.now();
    await pool.query('SELECT 1');
    health.checks.database = {
      status: 'healthy',
      responseTime: Date.now() - start,
      message: 'PostgreSQL connection successful'
    };
  } catch (error) {
    overallHealthy = false;
    health.checks.database = {
      status: 'unhealthy',
      error: error.message,
      message: 'PostgreSQL connection failed'
    };
  }

  // Check Redis
  try {
    const redisClient = getClient();
    if (redisClient && redisClient.isOpen) {
      const start = Date.now();
      await redisClient.ping();
      health.checks.redis = {
        status: 'healthy',
        responseTime: Date.now() - start,
        message: 'Redis connection successful'
      };
    } else {
      throw new Error('Redis client not connected');
    }
  } catch (error) {
    overallHealthy = false;
    health.checks.redis = {
      status: 'unhealthy',
      error: error.message,
      message: 'Redis connection failed'
    };
  }

  // Check memory usage
  const memUsage = process.memoryUsage();
  health.checks.memory = {
    status: 'healthy',
    heapUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)}MB`,
    heapTotal: `${Math.round(memUsage.heapTotal / 1024 / 1024)}MB`,
    external: `${Math.round(memUsage.external / 1024 / 1024)}MB`
  };

  health.status = overallHealthy ? 'healthy' : 'unhealthy';
  
  res.status(overallHealthy ? 200 : 503).json(health);
});

// Readiness probe (for Kubernetes)
router.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    const redisClient = getClient();
    if (redisClient && redisClient.isOpen) {
      await redisClient.ping();
    }
    res.status(200).json({ status: 'ready' });
  } catch (error) {
    res.status(503).json({ status: 'not ready', error: error.message });
  }
});

// Liveness probe (for Kubernetes)
router.get('/live', (req, res) => {
  res.status(200).json({ status: 'alive' });
});

module.exports = router; 