const express = require('express');
const Joi = require('joi');
const jwt = require('jsonwebtoken');
const { query } = require('../config/database');
const { setCache, getCache, deleteCachePattern } = require('../config/redis');

const router = express.Router();

// Validation schemas
const taskSchema = Joi.object({
  title: Joi.string().min(1).max(255).required(),
  description: Joi.string().max(1000).optional(),
  status: Joi.string().valid('pending', 'in_progress', 'completed', 'cancelled').optional(),
  priority: Joi.string().valid('low', 'medium', 'high', 'urgent').optional()
});

const updateTaskSchema = Joi.object({
  title: Joi.string().min(1).max(255).optional(),
  description: Joi.string().max(1000).optional(),
  status: Joi.string().valid('pending', 'in_progress', 'completed', 'cancelled').optional(),
  priority: Joi.string().valid('low', 'medium', 'high', 'urgent').optional()
});

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'fallback-secret', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// Create a new task
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { error, value } = taskSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    const { title, description = '', status = 'pending', priority = 'medium' } = value;
    const userId = req.user.userId;

    const result = await query(
      'INSERT INTO tasks (user_id, title, description, status, priority) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [userId, title, description, status, priority]
    );

    const task = result.rows[0];

    // Clear user's task cache
    await deleteCachePattern(`tasks:user:${userId}:*`);

    res.status(201).json({
      message: 'Task created successfully',
      task: task
    });
  } catch (error) {
    console.error('Task creation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all tasks for the authenticated user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const status = req.query.status;
    const priority = req.query.priority;
    const offset = (page - 1) * limit;

    const cacheKey = `tasks:user:${userId}:page:${page}:limit:${limit}:status:${status || 'all'}:priority:${priority || 'all'}`;
    
    // Try to get from cache first
    let cachedResult = await getCache(cacheKey);
    
    if (cachedResult) {
      return res.json(cachedResult);
    }

    // Build query based on filters
    let baseQuery = 'FROM tasks WHERE user_id = $1';
    let queryParams = [userId];
    let paramIndex = 2;

    if (status) {
      baseQuery += ` AND status = $${paramIndex}`;
      queryParams.push(status);
      paramIndex++;
    }

    if (priority) {
      baseQuery += ` AND priority = $${paramIndex}`;
      queryParams.push(priority);
      paramIndex++;
    }

    // Get total count
    const countResult = await query(`SELECT COUNT(*) ${baseQuery}`, queryParams);
    const totalTasks = parseInt(countResult.rows[0].count);

    // Get tasks with pagination
    const tasksQuery = `SELECT * ${baseQuery} ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    queryParams.push(limit, offset);
    
    const result = await query(tasksQuery, queryParams);

    const responseData = {
      tasks: result.rows,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalTasks / limit),
        totalTasks: totalTasks,
        hasNext: page * limit < totalTasks,
        hasPrev: page > 1
      },
      filters: {
        status: status || null,
        priority: priority || null
      }
    };

    // Cache the result for 5 minutes
    await setCache(cacheKey, responseData, 300);

    res.json(responseData);
  } catch (error) {
    console.error('Tasks fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get a specific task
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const taskId = parseInt(req.params.id);
    const userId = req.user.userId;

    if (isNaN(taskId)) {
      return res.status(400).json({ error: 'Invalid task ID' });
    }

    const cacheKey = `task:${taskId}:user:${userId}`;
    
    // Try to get from cache first
    let task = await getCache(cacheKey);
    
    if (!task) {
      const result = await query(
        'SELECT * FROM tasks WHERE id = $1 AND user_id = $2',
        [taskId, userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Task not found' });
      }

      task = result.rows[0];
      
      // Cache the task
      await setCache(cacheKey, task, 600);
    }

    res.json({ task });
  } catch (error) {
    console.error('Task fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update a task
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const taskId = parseInt(req.params.id);
    const userId = req.user.userId;

    if (isNaN(taskId)) {
      return res.status(400).json({ error: 'Invalid task ID' });
    }

    const { error, value } = updateTaskSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // Check if task exists and belongs to user
    const existingTask = await query(
      'SELECT id FROM tasks WHERE id = $1 AND user_id = $2',
      [taskId, userId]
    );

    if (existingTask.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Build update query
    const updateFields = [];
    const queryParams = [];
    let paramIndex = 1;

    Object.keys(value).forEach(key => {
      updateFields.push(`${key} = $${paramIndex}`);
      queryParams.push(value[key]);
      paramIndex++;
    });

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    updateFields.push(`updated_at = CURRENT_TIMESTAMP`);
    queryParams.push(taskId, userId);

    const updateQuery = `
      UPDATE tasks 
      SET ${updateFields.join(', ')} 
      WHERE id = $${paramIndex} AND user_id = $${paramIndex + 1}
      RETURNING *
    `;

    const result = await query(updateQuery, queryParams);
    const updatedTask = result.rows[0];

    // Clear caches
    await deleteCachePattern(`task:${taskId}:*`);
    await deleteCachePattern(`tasks:user:${userId}:*`);

    res.json({
      message: 'Task updated successfully',
      task: updatedTask
    });
  } catch (error) {
    console.error('Task update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete a task
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const taskId = parseInt(req.params.id);
    const userId = req.user.userId;

    if (isNaN(taskId)) {
      return res.status(400).json({ error: 'Invalid task ID' });
    }

    const result = await query(
      'DELETE FROM tasks WHERE id = $1 AND user_id = $2 RETURNING *',
      [taskId, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Clear caches
    await deleteCachePattern(`task:${taskId}:*`);
    await deleteCachePattern(`tasks:user:${userId}:*`);

    res.json({
      message: 'Task deleted successfully',
      task: result.rows[0]
    });
  } catch (error) {
    console.error('Task deletion error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get task statistics for the user
router.get('/stats/summary', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const cacheKey = `task:stats:user:${userId}`;
    
    // Try to get from cache first
    let stats = await getCache(cacheKey);
    
    if (!stats) {
      const result = await query(`
        SELECT 
          COUNT(*) as total_tasks,
          COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_tasks,
          COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as in_progress_tasks,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_tasks,
          COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_tasks,
          COUNT(CASE WHEN priority = 'urgent' THEN 1 END) as urgent_tasks,
          COUNT(CASE WHEN priority = 'high' THEN 1 END) as high_priority_tasks
        FROM tasks 
        WHERE user_id = $1
      `, [userId]);

      stats = result.rows[0];
      
      // Cache the stats for 10 minutes
      await setCache(cacheKey, stats, 600);
    }

    res.json({ stats });
  } catch (error) {
    console.error('Task stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router; 