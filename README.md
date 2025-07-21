# Scalable Backend with Docker

A comprehensive example of a scalable backend architecture using Docker containers for learning purposes. This project demonstrates microservices architecture, containerization, load balancing, and caching strategies.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Nginx       │    │    Node.js      │    │   PostgreSQL    │
│  Load Balancer  │────│   API Server    │────│    Database     │
│   (Port 80)     │    │   (Port 3000)   │    │   (Port 5432)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │              ┌─────────────────┐
         │                       └──────────────│     Redis       │
         │                                      │     Cache       │
         └──────────────────────────────────────│   (Port 6379)   │
                                                └─────────────────┘
```

## Features

- **RESTful API** with user authentication and task management
- **PostgreSQL** database with automatic migrations
- **Redis** caching for improved performance
- **Nginx** reverse proxy with load balancing
- **JWT** authentication with secure password hashing
- **Rate limiting** and security headers
- **Health checks** and monitoring endpoints
- **Docker Compose** orchestration
- **Data persistence** with Docker volumes

## Prerequisites

- **Docker Desktop** or **Docker Engine** with Docker Compose
- **Minimum System Requirements:**
  - 4GB RAM (8GB recommended for auto-scaling)
  - 2 CPU cores (4+ recommended)
  - 10GB free disk space
- **Available Ports:** 80, 3000, 5432, 6379, 8080, 8090
- **Operating System:** Windows 10/11, macOS, or Linux

## Getting Started

### **Choose Your Deployment Mode**

This project offers two deployment modes:

1. ** Development Mode** - Single instances, easy Docker Desktop management
2. ** Production Auto-scaling** - Docker Swarm with intelligent auto-scaling

---

### **Option 1: Development Mode (Recommended for Learning)**

Perfect for learning, testing, and development work.

#### **Step 1: Setup Environment**
```powershell
# Copy environment template
Copy-Item env.example .env

# Edit .env file with your preferred text editor
notepad .env  # Windows
# Set your database passwords and JWT secret
```

#### **Step 2: Deploy Development Environment**
```powershell
# Deploy with automatic image building
.\deploy-dev.ps1 -Build
```

#### **Step 3: Verify Deployment**
```powershell
# Check all services are running
docker-compose -f docker-compose.dev.yml ps

# Test API health
curl http://localhost/api/health
```

#### **What You Get:**
- ✅ Single API instance (easy to debug)
- ✅ PostgreSQL database with sample data
- ✅ Redis cache
- ✅ Nginx load balancer
- ✅ Monitoring services
- ✅ Clean container names in Docker Desktop
- ✅ All grouped under "autoscaling_" prefix

---

### **Option 2: Production Auto-scaling Mode**

Experience real auto-scaling with Docker Swarm orchestration.

#### **Step 1: Setup Environment**
```powershell
# Copy and configure environment
Copy-Item env.example .env

# Edit scaling parameters (optional)
# MIN_REPLICAS=2
# MAX_REPLICAS=10
# SCALE_UP_THRESHOLD=80
```

#### **Step 2: Deploy Auto-scaling Stack**
```powershell
# Deploy full auto-scaling system
.\deploy-autoscaling.ps1
```

#### **Step 3: Verify Auto-scaling**
```powershell
# Watch services scale
docker service ls

# Check autoscaler logs
docker service logs -f scalable-backend-production_autoscaler

# Test scaling with load
.\testing\stress-test-simple.ps1 -MaxConcurrentUsers 50 -TestDurationMinutes 3
```

#### **What You Get:**
- ✅ 2-10 API instances (auto-scaling based on load)
- ✅ PostgreSQL with read replicas (auto-scaling)
- ✅ Redis clustering (auto-scaling)
- ✅ Advanced load balancing with service discovery
- ✅ Comprehensive monitoring and metrics
- ✅ Production-ready configuration
- ✅ **Docker Desktop Grouping**: All containers organized under "scalable-backend-production" project

---

### **Quick Test Commands**

After deployment, test your setup:

```powershell
# 1. Test API health
curl http://localhost/api/health

# 2. Register a test user
$userData = @{
    email = "test@example.com"
    username = "testuser"
    password = "password123"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost/api/users/register" -Method POST -Headers @{"Content-Type"="application/json"} -Body $userData

# 3. Login and get token
$loginData = @{
    email = "test@example.com"
    password = "password123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "http://localhost/api/users/login" -Method POST -Headers @{"Content-Type"="application/json"} -Body $loginData

# 4. Create a task (save token from login)
$taskData = @{
    title = "Learn Docker Auto-scaling"
    description = "Master container orchestration"
    priority = "high"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost/api/tasks" -Method POST -Headers @{"Content-Type"="application/json"; "Authorization"="Bearer $($loginResponse.token)"} -Body $taskData
```

---

### **Verify Everything is Working**

#### **Health Checks:**
```powershell
# API Health
curl http://localhost/api/health/detailed

# Autoscaler Status (if using auto-scaling mode)
curl http://localhost:8080/health

# Metrics (if using auto-scaling mode)
curl http://localhost:8090/metrics
```

#### **Docker Desktop Verification:**
1. Open Docker Desktop
2. Go to **Containers** tab
3. Look for containers grouped by project:
   - **Development Mode**: `auto-scaling-backend` project group (containers with `autoscaling_` prefix)
   - **Production Mode**: `scalable-backend-production` project group (containers with `scalable-backend_` prefix)
4. All containers should show "Running" status
5. Services are organized by type: API (multiple instances), Database, Cache, Load Balancer, Monitoring

#### **Database Verification:**
```powershell
# Connect to PostgreSQL
docker-compose exec postgres psql -U postgres -d scalable_backend

# In PostgreSQL shell:
# \dt                 -- List tables
# SELECT * FROM users; -- View users
# \q                  -- Quit
```

---

### **Development Workflow**

#### **View Logs:**
```powershell
# All services
docker-compose -f docker-compose.dev.yml logs -f

# Specific service
docker-compose -f docker-compose.dev.yml logs -f api
```

#### **Restart Services:**
```powershell
# Restart all
docker-compose -f docker-compose.dev.yml restart

# Restart specific service
docker-compose -f docker-compose.dev.yml restart api
```

#### **Stop Everything:**
```powershell
# Development mode
docker-compose -f docker-compose.dev.yml down

# Auto-scaling mode
docker stack rm scalable-backend-production
```

---

### **Next Steps**

1. ** Read the Documentation:**
   - `AUTOSCALING_GUIDE.md` - Comprehensive auto-scaling guide
   - `testing/TESTING_GUIDE.md` - API testing guide
   - `testing/STRESS_TEST_README.md` - Load testing guide

2. ** Try Load Testing:**
   ```powershell
   .\testing\stress-test-simple.ps1 -MaxConcurrentUsers 25 -TestDurationMinutes 1
   ```

3. ** Explore the API:**
   - Open http://localhost/ in your browser
   - Use the API endpoints listed below

4. ** Scale and Monitor:**
   - Watch containers scale with load
   - Monitor resource usage with `docker stats`

5. ** Docker Desktop Management:**
   - **Development Mode**: Look for "auto-scaling-backend" project group
   - **Production Mode**: Look for "scalable-backend-production" project group
   - Use project filters to view only your containers
   - Each service type is labeled for easy identification

---

## API Endpoints

### Authentication
- `POST /api/users/register` - Register new user
- `POST /api/users/login` - User login
- `GET /api/users/profile` - Get user profile (auth required)
- `POST /api/users/logout` - Logout user (auth required)

### Tasks
- `GET /api/tasks` - Get user tasks (with pagination and filters)
- `POST /api/tasks` - Create new task (auth required)
- `GET /api/tasks/:id` - Get specific task (auth required)
- `PUT /api/tasks/:id` - Update task (auth required)
- `DELETE /api/tasks/:id` - Delete task (auth required)
- `GET /api/tasks/stats/summary` - Get task statistics (auth required)

### Health & Monitoring
- `GET /api/health` - Basic health check
- `GET /api/health/detailed` - Detailed health with dependencies
- `GET /api/health/ready` - Kubernetes readiness probe
- `GET /api/health/live` - Kubernetes liveness probe

## Testing the API

### Register a new user:
```bash
curl -X POST http://localhost/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "testuser",
    "password": "password123"
  }'
```

### Login:
```bash
curl -X POST http://localhost/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

### Create a task (using token from login):
```bash
curl -X POST http://localhost/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "title": "Learn Docker",
    "description": "Master Docker containerization",
    "priority": "high"
  }'
```

## Docker Commands

### Development workflow:
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f api

# Restart a specific service
docker-compose restart api

# Stop all services
docker-compose down

# Stop and remove volumes (deletes data)
docker-compose down -v

# Rebuild and start
docker-compose up --build -d
```

### Individual service management:
```bash
# Scale API instances
docker-compose up -d --scale api=3

# Execute commands in running containers
docker-compose exec api npm run dev
docker-compose exec postgres psql -U postgres -d scalable_backend
docker-compose exec redis redis-cli
```

## Monitoring & Logs

### View service logs:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
docker-compose logs -f postgres
docker-compose logs -f redis
docker-compose logs -f nginx
```

### Check service status:
```bash
docker-compose ps
```

### Monitor resource usage:
```bash
docker stats
```

## Database

### Sample users (for testing):
- Email: `demo@example.com`, Password: `demo123`
- Email: `test@example.com`, Password: `demo123`

### Connect to database:
```bash
docker-compose exec postgres psql -U postgres -d scalable_backend
```

### Useful SQL queries:
```sql
-- View all users
SELECT id, email, username, created_at FROM users;

-- View task statistics
SELECT * FROM task_stats;

-- Check recent tasks
SELECT * FROM tasks ORDER BY created_at DESC LIMIT 5;
```

## Security Features

- **JWT Authentication** with configurable secret
- **Password Hashing** using bcrypt
- **Rate Limiting** (100 requests/minute, 5 login attempts/minute)
- **Security Headers** via Nginx
- **Input Validation** using Joi
- **Non-root Container** execution

## Learning Objectives

This project teaches:

1. **Docker Fundamentals**:
   - Dockerfile best practices
   - Multi-stage builds
   - Container networking
   - Volume management

2. **Docker Compose**:
   - Service orchestration
   - Environment variables
   - Health checks
   - Scaling strategies

3. **Microservices Architecture**:
   - Service separation
   - Database per service
   - Inter-service communication

4. **Production Readiness**:
   - Load balancing
   - Caching strategies
   - Monitoring & logging
   - Security best practices

## Scaling Strategies

### Horizontal Scaling:
```bash
# Scale API servers
docker-compose up -d --scale api=3

# Scale with custom compose file
docker-compose -f docker-compose.yml -f docker-compose.scale.yml up -d
```

### Load Testing:
```bash
# Use the included PowerShell stress test script
.\testing\stress-test-simple.ps1 -MaxConcurrentUsers 25 -TestDurationMinutes 2
```

## Troubleshooting

### Common issues:

1. **Port conflicts**:
   ```bash
   # Check what's using ports
   netstat -tulpn | grep :80
   netstat -tulpn | grep :3000
   ```

2. **Container won't start**:
   ```bash
   # Check logs
   docker-compose logs service_name
   
   # Check container status
   docker-compose ps
   ```

3. **Database connection issues**:
   ```bash
   # Wait for PostgreSQL to be ready
   docker-compose exec postgres pg_isready -U postgres
   ```

4. **Clear everything and restart**:
   ```bash
   docker-compose down -v
   docker system prune -f
   docker-compose up -d
   ```

## Stopping Auto-scaling Services

If autoscaler is active, **Docker Swarm will automatically recreate containers** to maintain the desired replica count. Simply deleting individual containers won't work because Swarm will immediately recreate them. Here's how to properly stop the autoscaler:

### **Stop Docker Swarm Stack (Recommended)**

If you deployed using `deploy-autoscaling.ps1`, you're running Docker Swarm mode:

```powershell
# Stop the entire auto-scaling stack
docker stack rm scalable-backend-production
```

This will:
- Stop all services (API, autoscaler, PostgreSQL, Redis, Nginx, metrics)
- Remove all containers
- Remove the stack network
- **Keep your data volumes intact**

### **Check What's Running**

If that doesn't work, let's see what deployment method you used:

```powershell
# Check if Docker Swarm stack is running
docker stack ls

# Check Docker Swarm services
docker service ls

# Check regular Docker Compose containers
docker-compose ps
```

### **Stop Based on Deployment Method**

#### Option 1: If Using Docker Swarm (deploy-autoscaling.ps1)
```powershell
# Stop everything
docker stack rm scalable-backend-production

# Verify it's stopped
docker service ls
```

#### Option 2: If Using Docker Compose (deploy-dev.ps1)
```powershell
# Stop development environment
docker-compose -f docker-compose.dev.yml down

# Or stop original compose setup
docker-compose down
```

#### Option 3: Nuclear Option (Stop Everything)
```powershell
# Stop ALL Docker containers
docker stop $(docker ps -q)

# Remove ALL containers
docker rm $(docker ps -aq)

# Leave Docker Swarm (if needed)
docker swarm leave --force
```

### **Emergency Stop for Runaway Autoscaler**

If the autoscaler is creating too many containers:

```powershell
# 1. Stop the autoscaler service immediately
docker service rm scalable-backend-production_autoscaler

# 2. Scale down API instances
docker service scale scalable-backend-production_api=1

# 3. Stop the entire stack
docker stack rm scalable-backend-production
```

### **Check for Remaining Processes**

After stopping, verify everything is clean:

```powershell
# Check for any remaining services
docker service ls

# Check for any remaining containers
docker ps -a

# Check for any remaining stacks
docker stack ls

# Check Docker Swarm status
docker info | findstr "Swarm"
```

### **Monitor Resource Usage**

While stopping, monitor your system:

```powershell
# Monitor Docker resource usage
docker stats

# Check system processes
Get-Process | Where-Object {$_.ProcessName -like "*docker*"}
```

### **Prevent Future Issues**

To avoid runaway scaling in the future:

#### 1. **Use Development Mode for Testing**
```powershell
# Use this for testing instead of production Swarm
.\deploy-dev.ps1 -Build
```

#### 2. **Set Conservative Scaling Limits**
Create a `.env` file with:
```bash
MIN_REPLICAS=1
MAX_REPLICAS=3
SCALE_UP_THRESHOLD=90
CHECK_INTERVAL=60
COOLDOWN_PERIOD=300
```

#### 3. **Monitor Before Heavy Load Testing**
```powershell
# Always monitor when load testing
docker stats
```

### **Clean Restart**

If you want to start fresh:

```powershell
# 1. Stop everything
docker stack rm scalable-backend-production
docker-compose down

# 2. Wait for cleanup
Start-Sleep -Seconds 10

# 3. Clean images (optional)
docker image prune -f

# 4. Restart with development mode
.\deploy-dev.ps1 -Build
```

### **Quick Commands Summary**

```powershell
# STOP EVERYTHING NOW:
docker stack rm scalable-backend-production

# If that doesn't work:
docker service rm $(docker service ls -q)
docker stop $(docker ps -q)

# Nuclear option:
docker system prune -af --volumes
```

The key is using `docker stack rm scalable-backend-production` instead of trying to delete individual containers. Docker Swarm will keep recreating them until you remove the entire stack service definition.

## Advanced Configuration

### Environment Variables:
Copy `env.example` to `.env` and customize:
- `JWT_SECRET` - Change for production
- `DB_PASSWORD` - Use strong password
- `NODE_ENV` - Set to `production` for production

### Custom Networks:
The setup creates an isolated network for all services to communicate securely.

### Data Persistence:
- PostgreSQL data: `postgres_data` volume
- Redis data: `redis_data` volume
