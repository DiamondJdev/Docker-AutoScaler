# 🚀 Auto-scaling Load Balancer Guide

## Overview

This auto-scaling load balancer system automatically scales your `scalable_backend_api` instances (and database services when beneficial) based on real-time load metrics. It uses Docker Swarm for orchestration and custom monitoring services for intelligent scaling decisions.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Nginx       │    │    API (2-10)   │    │   PostgreSQL    │
│  Load Balancer  │────│   Instances     │────│    (1-3)        │
│   (Port 80)     │    │   Auto-scaled   │    │   Auto-scaled   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                     │
         │              ┌─────────────────┐            │
         │              │   Autoscaler    │            │
         │              │   Monitoring    │            │
         │              │   (Port 8080)   │            │
         │              └─────────────────┘            │
         │                                      ┌─────────────────┐
         │                                      │     Redis       │
         └──────────────────────────────────────│    (1-2)        │
                                 |              │   Auto-scaled   │
                                 |              └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │ Metrics         │
                        │ Collector       │
                        │ (Port 8090)     │
                        └─────────────────┘
```

## 🎯 Key Features

### Intelligent Auto-scaling
- **API Instances**: 2-10 replicas based on CPU, memory, and response times
- **PostgreSQL**: 1-3 replicas based on connection load
- **Redis**: 1-2 replicas based on memory usage
- **Multiple Algorithms**: Linear, exponential, and predictive scaling

### Advanced Load Balancing
- **Service Discovery**: Automatic detection of new API instances
- **Health Checks**: Automatic removal of unhealthy instances
- **Retry Logic**: Intelligent request routing and failover
- **Rate Limiting**: Adaptive limits based on current capacity

### Comprehensive Monitoring
- **Real-time Metrics**: CPU, memory, response times, error rates
- **Prometheus Integration**: Standard metrics format
- **Trend Analysis**: Predictive scaling based on historical data
- **Health Monitoring**: All services continuously monitored

## 🚀 Quick Start

### 1. Deploy the Auto-scaling System

```bash
# Make deployment script executable
chmod +x deploy-autoscaling.sh

# Deploy the system
./deploy-autoscaling.sh
```

### 2. Verify Deployment

```bash
# Check all services are running
docker service ls

# Test API health
curl http://localhost/api/health

# Check autoscaler status
curl http://localhost:8080/health
```

### 3. Monitor Auto-scaling

```bash
# Watch services scale in real-time
watch 'docker service ls'

# View autoscaler logs
docker service logs -f scalable-backend_autoscaler
```

## 📊 Scaling Configuration

### Default Thresholds

| Metric | Scale Up | Scale Down |
|--------|----------|------------|
| CPU Usage | > 70% | < 20% |
| Memory Usage | > 80% | < 40% |
| Response Time | > 1000ms | < 200ms |
| Error Rate | > 5% | N/A |

### Replica Limits

| Service | Minimum | Maximum |
|---------|---------|---------|
| API | 2 | 10 |
| PostgreSQL | 1 | 3 |
| Redis | 1 | 2 |

### Timing Settings

- **Check Interval**: 30 seconds
- **Cooldown Period**: 120 seconds
- **Health Check Interval**: 10 seconds

## 🛠️ Customization

### Environment Variables

Create a `.env` file or modify the existing one:

```bash
# Scaling thresholds
SCALE_UP_THRESHOLD=80
SCALE_DOWN_THRESHOLD=30
CPU_SCALE_UP_THRESHOLD=70
MEMORY_SCALE_UP_THRESHOLD=80

# Replica limits
MIN_REPLICAS=2
MAX_REPLICAS=10

# Timing
CHECK_INTERVAL=30
COOLDOWN_PERIOD=120

# Algorithm selection
SCALING_ALGORITHM=linear  # linear, exponential, predictive
```

### Scaling Algorithms

#### Linear Scaling (Default)
- Simple threshold-based scaling
- Adds/removes one replica at a time
- Conservative and predictable

```bash
SCALING_ALGORITHM=linear
```

#### Exponential Scaling
- Rapid response to high load
- Multiplies replicas by 1.5-2x under stress
- Best for traffic spikes

```bash
SCALING_ALGORITHM=exponential
```

#### Predictive Scaling
- Uses trend analysis
- Proactive scaling before thresholds are hit
- Best for gradual load increases

```bash
SCALING_ALGORITHM=predictive
```

## 📈 Monitoring and Metrics

### Service Endpoints

| Service | Health Check | Metrics |
|---------|-------------|---------|
| API | `http://localhost/api/health` | Built-in |
| Autoscaler | `http://localhost:8080/health` | `http://localhost:8080/metrics` |
| Metrics Collector | `http://localhost:9090/health` | `http://localhost:8090/metrics` |
| Nginx | `http://localhost/nginx/status` | Access logs |

### Prometheus Metrics

The system exposes comprehensive metrics in Prometheus format:

```bash
# View all metrics
curl http://localhost:8090/metrics

# Key metrics include:
# - api_replicas_current
# - api_cpu_usage_percent
# - api_memory_usage_percent
# - api_response_time_ms
# - postgres_connections_active
# - redis_memory_usage_bytes
```

### Real-time Monitoring

```bash
# Watch scaling decisions
docker service logs -f scalable-backend_autoscaler | grep "scaled"

# Monitor API performance
docker service logs -f scalable-backend_api | grep "request"

# Check system resources
docker stats

# View detailed service info
docker service inspect scalable-backend_api
```

## 🧪 Load Testing and Validation

### Trigger Auto-scaling

Use the included stress test to trigger scaling:

```powershell
# Light load test (should maintain 2 replicas)
.\stress-test-simple.ps1 -MaxConcurrentUsers 25 -TestDurationMinutes 2

# Medium load test (should scale to 3-5 replicas)
.\stress-test-simple.ps1 -MaxConcurrentUsers 50 -TestDurationMinutes 3

# Heavy load test (should scale to 8-10 replicas)
.\stress-test-simple.ps1 -MaxConcurrentUsers 100 -TestDurationMinutes 5
```

### Manual Scaling

```bash
# Manually scale API to test load balancer
docker service scale scalable-backend_api=5

# Scale back down
docker service scale scalable-backend_api=2

# Force update to restart all instances
docker service update --force scalable-backend_api
```

### Validation Checklist

✅ **API Scaling**
- [ ] Scales up under load (CPU > 70% or Memory > 80%)
- [ ] Scales down when load decreases
- [ ] Respects min/max replica limits
- [ ] Honors cooldown period

✅ **Load Balancing**
- [ ] Requests distributed across all healthy instances
- [ ] New instances automatically added to load balancer
- [ ] Unhealthy instances automatically removed
- [ ] No dropped requests during scaling

✅ **Database Scaling**
- [ ] PostgreSQL scales with API load
- [ ] Redis scales based on memory usage
- [ ] Database connections properly distributed

## 🔧 Troubleshooting

### Common Issues

#### Autoscaler Not Scaling

```bash
# Check autoscaler logs
docker service logs scalable-backend_autoscaler

# Common causes:
# 1. Still in cooldown period
# 2. Already at min/max replicas
# 3. Thresholds not met
# 4. Docker socket permission issues
```

#### API Instances Not Starting

```bash
# Check API service logs
docker service logs scalable-backend_api

# Check if images are built
docker images | grep scalable_backend

# Rebuild if necessary
docker build -t scalable_backend_api:latest .
```

#### Load Balancer Issues

```bash
# Check nginx logs
docker service logs scalable-backend_nginx

# Test nginx configuration
docker service update --force scalable-backend_nginx

# Check upstream health
curl http://localhost/nginx/upstream
```

#### Database Connection Issues

```bash
# Check PostgreSQL status
docker service logs scalable-backend_postgres

# Test database connection
docker exec -it $(docker ps -q -f name=scalable-backend_postgres) psql -U postgres -c "SELECT 1"

# Check Redis status
docker exec -it $(docker ps -q -f name=scalable-backend_redis) redis-cli ping
```

### Performance Tuning

#### Optimize for High Load

```bash
# Increase max replicas
docker service update --replicas-max-per-node 5 scalable-backend_api

# Faster scaling response
export CHECK_INTERVAL=15
export COOLDOWN_PERIOD=60

# More aggressive thresholds
export SCALE_UP_THRESHOLD=60
export CPU_SCALE_UP_THRESHOLD=60
```

#### Optimize for Stability

```bash
# Conservative scaling
export SCALING_ALGORITHM=linear
export SCALE_UP_THRESHOLD=85
export COOLDOWN_PERIOD=180

# Higher minimum replicas
export MIN_REPLICAS=3
```

## 🛡️ Security and Best Practices

### Production Deployment

1. **Change Default Secrets**
   ```bash
   # Generate strong JWT secret
   export JWT_SECRET=$(openssl rand -base64 32)
   
   # Use strong database passwords
   export DB_PASSWORD=$(openssl rand -base64 16)
   ```

2. **Resource Limits**
   ```yaml
   resources:
     limits:
       cpus: '1.0'
       memory: 512M
     reservations:
       cpus: '0.5'
       memory: 256M
   ```

3. **Health Check Configuration**
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
     interval: 30s
     timeout: 10s
     retries: 3
   ```

### Monitoring Alerts

Set up alerts for critical metrics:

- API response time > 2 seconds
- Error rate > 10%
- CPU usage > 90% for > 5 minutes
- Memory usage > 95%
- Database connections > 80% of max

## 🔄 Updates and Maintenance

### Zero-downtime Updates

```bash
# Rolling update of API instances
docker service update --image scalable_backend_api:v2.0 scalable-backend_api

# Update autoscaler
docker service update --image autoscaler:v2.0 scalable-backend_autoscaler

# Update nginx configuration
docker service update --config-rm nginx.conf --config-add nginx.conf.v2 scalable-backend_nginx
```

### Backup and Recovery

```bash
# Backup volumes
docker run --rm -v scalable-backend_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz /data

# Restore volumes
docker run --rm -v scalable-backend_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres-backup.tar.gz -C /
```

## 📚 Additional Resources

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Nginx Load Balancing](https://nginx.org/en/docs/http/load_balancing.html)
- [Prometheus Metrics](https://prometheus.io/docs/concepts/metric_types/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)

---

**🎉 Congratulations!** Your auto-scaling load balancer is now ready to handle any load while maintaining optimal performance and resource utilization! 