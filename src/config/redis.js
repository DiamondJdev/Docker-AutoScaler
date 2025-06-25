const { createClient } = require('redis');

let redisClient;

async function initRedis() {
  try {
    redisClient = createClient({
      socket: {
        host: process.env.REDIS_HOST || 'localhost',
        port: process.env.REDIS_PORT || 6379,
      },
      password: process.env.REDIS_PASSWORD || undefined,
    });

    redisClient.on('error', (err) => {
      console.error('Redis Client Error:', err);
    });

    redisClient.on('connect', () => {
      console.log('Redis Client Connected');
    });

    await redisClient.connect();
    
    // Test the connection
    await redisClient.ping();
    console.log('Redis connection tested successfully');
    
  } catch (error) {
    console.error('Redis initialization failed:', error);
    throw error;
  }
}

// Cache helper functions
async function setCache(key, value, expiration = 3600) {
  try {
    const serializedValue = JSON.stringify(value);
    await redisClient.setEx(key, expiration, serializedValue);
  } catch (error) {
    console.error('Redis SET error:', error);
  }
}

async function getCache(key) {
  try {
    const value = await redisClient.get(key);
    return value ? JSON.parse(value) : null;
  } catch (error) {
    console.error('Redis GET error:', error);
    return null;
  }
}

async function deleteCache(key) {
  try {
    await redisClient.del(key);
  } catch (error) {
    console.error('Redis DELETE error:', error);
  }
}

async function deleteCachePattern(pattern) {
  try {
    const keys = await redisClient.keys(pattern);
    if (keys.length > 0) {
      await redisClient.del(keys);
    }
  } catch (error) {
    console.error('Redis DELETE PATTERN error:', error);
  }
}

module.exports = {
  initRedis,
  setCache,
  getCache,
  deleteCache,
  deleteCachePattern,
  getClient: () => redisClient
}; 