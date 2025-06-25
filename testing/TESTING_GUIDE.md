# 🧪 Comprehensive Testing Guide for Scalable Backend

## 🎯 Overview
This guide provides complete testing instructions for your Docker-based scalable backend with Node.js, PostgreSQL, Redis, and Nginx.

## 🏥 Health & Status Checks

### Basic Health Check
```bash
curl http://localhost/api/health
```
**Expected Response:** `{"status":"healthy","timestamp":"...","service":"scalable-backend-api",...}`

### Detailed Health Check
```bash
curl http://localhost/api/health/detailed
```
**Expected Response:** Status of API, PostgreSQL, Redis, and memory usage

### Service Status
```bash
docker-compose ps
```
**Expected:** All services showing as "healthy" or "Up"

## 👤 User Authentication Testing

### 1. User Registration
```bash
curl -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "password123"
  }'
```

### 2. User Login
```bash
curl -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```
**Save the `token` from response for subsequent requests**

### 3. Get User Profile
```bash
curl -X GET http://localhost/api/users/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 📝 Task Management Testing

### 1. Create Task
```bash
curl -X POST http://localhost/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "title": "Learn Docker",
    "description": "Master container orchestration",
    "priority": "high",
    "status": "pending"
  }'
```

### 2. Get All Tasks
```bash
curl -X GET http://localhost/api/tasks \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 3. Get Specific Task
```bash
curl -X GET http://localhost/api/tasks/1 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 4. Update Task
```bash
curl -X PUT http://localhost/api/tasks/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "status": "completed"
  }'
```

### 5. Delete Task
```bash
curl -X DELETE http://localhost/api/tasks/1 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 6. Get Task Statistics
```bash
curl -X GET http://localhost/api/tasks/stats/summary \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 🔍 Advanced Testing

### Pagination Testing
```bash
curl -X GET "http://localhost/api/tasks?page=1&limit=5" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Filtering Testing
```bash
curl -X GET "http://localhost/api/tasks?status=pending&priority=high" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 🗄️ Database Testing

### Connect to PostgreSQL
```bash
docker-compose exec postgres psql -U postgres -d scalable_backend
```

### Common SQL Queries
```sql
-- View all users
SELECT id, email, username, created_at FROM users;

-- View all tasks
SELECT * FROM tasks ORDER BY created_at DESC;

-- View task statistics
SELECT * FROM task_stats;

-- Check recent tasks by user
SELECT u.username, t.title, t.status, t.created_at 
FROM users u 
JOIN tasks t ON u.id = t.user_id 
ORDER BY t.created_at DESC 
LIMIT 10;
```

## 🚀 Redis Testing

### Connect to Redis
```bash
docker-compose exec redis redis-cli
```

### Redis Commands
```redis
# Check if Redis is working
PING

# View all keys
KEYS *

# Check a cached user
GET user:1

# View Redis info
INFO memory
```

## 📊 Performance Testing

### Resource Monitoring
```bash
# Check container resource usage
docker stats

# Monitor logs in real-time
docker-compose logs -f api

# Check specific service logs
docker-compose logs postgres
docker-compose logs redis
docker-compose logs nginx
```

### Load Testing with PowerShell
```powershell
# Run the included load test script
.\test-api.ps1
```

## 🔧 Error Testing

### Test Rate Limiting
```bash
# Make rapid requests to trigger rate limiting
for i in {1..200}; do curl http://localhost/api/health; done
```

### Test Authentication Errors
```bash
# Request without token
curl -X GET http://localhost/api/tasks

# Request with invalid token
curl -X GET http://localhost/api/tasks \
  -H "Authorization: Bearer invalid_token"
```

### Test Validation Errors
```bash
# Register user with invalid data
curl -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email": "invalid-email", "password": "123"}'
```

## 🌐 Browser Testing

Open these URLs in your browser:
- **API Info:** http://localhost/
- **Health Check:** http://localhost/api/health
- **Detailed Health:** http://localhost/api/health/detailed

## 🛠️ Troubleshooting

### Check Service Health
```bash
# Verify all services are running
docker-compose ps

# Check service logs for errors
docker-compose logs [service_name]

# Restart a specific service
docker-compose restart [service_name]
```

### Common Issues

1. **503 Bad Gateway**
   ```bash
   docker-compose logs api
   docker-compose restart api
   ```

2. **Database Connection Issues**
   ```bash
   docker-compose exec postgres pg_isready -U postgres
   ```

3. **Redis Connection Issues**
   ```bash
   docker-compose exec redis redis-cli ping
   ```

## 📈 Performance Benchmarks

Your backend should handle:
- **Health checks:** < 50ms response time
- **User registration:** < 500ms response time
- **User login:** < 300ms response time
- **Task operations:** < 200ms response time
- **Concurrent requests:** 50+ requests/second

## 🎯 Success Criteria

✅ All health checks return 200 status
✅ User registration and login work
✅ JWT authentication functions properly
✅ CRUD operations on tasks work
✅ Database queries execute successfully
✅ Redis caching is functional
✅ Rate limiting is enforced
✅ Error handling returns appropriate status codes
✅ Resource usage stays under reasonable limits

## 🔗 Demo Data

The system includes demo users for testing:
- **Email:** demo@example.com, **Password:** demo123
- **Email:** test@example.com, **Password:** demo123

These users have sample tasks pre-loaded for testing.

---

**🎉 Congratulations!** Your scalable backend is ready for production deployment! 