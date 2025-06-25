# 🔥 EXTREME STRESS TEST DOCUMENTATION

## ⚠️ WARNING: THIS WILL PUSH YOUR SYSTEM TO ITS LIMITS!

The `stress-test.ps1` script is designed to test the **maximum capacity** of your scalable backend. This is not a gentle load test - it's an all-out assault on your system designed to find breaking points and performance limits.

## 🎯 What This Test Does

### Phase 1: System Warm-up (Health Check Bombardment)
- Launches 50 concurrent jobs
- Each job performs 20 rapid health checks
- **Total**: 1,000 health check requests in ~30 seconds
- Purpose: Prime the system and caches

### Phase 2: User Registration Tsunami
- Creates up to 100 concurrent user registrations
- Uses realistic wave patterns (20 users per wave)
- Tests database write performance under load
- Measures registration success/failure rates

### Phase 3: Authentication Storm
- Rapid authentication for all successful registrations
- Tests JWT token generation under load
- Validates login system performance
- Collects authentication tokens for next phase

### Phase 4: MAXIMUM LOAD - Task Creation Apocalypse 🔥
**This is where things get INTENSE:**
- Each authenticated user runs a continuous session
- **Per user, per minute**: 
  - 10 task creations
  - 15 paginated task queries
  - 20 mixed API calls (profile, stats, health)
- Expected load: **1000+ requests per minute per user**
- For 50 users: **~50,000 requests per minute**
- **Total expected requests in 5 minutes: ~250,000+**

### Phase 5: System Recovery Test
- Tests if the system can recover after extreme load
- Performs 10 health checks with 30-second timeouts
- Measures recovery rate

## 🚀 How to Run

### Basic Usage
```powershell
# Default: 100 users, 5 minutes
.\stress-test.ps1
```

### Customized Testing
```powershell
# Moderate stress test
.\stress-test.ps1 -MaxConcurrentUsers 50 -TestDurationMinutes 3

# EXTREME stress test (WARNING: Very intense!)
.\stress-test.ps1 -MaxConcurrentUsers 200 -TestDurationMinutes 10

# Quick burst test
.\stress-test.ps1 -MaxConcurrentUsers 25 -TestDurationMinutes 1
```

### Custom Base URL
```powershell
# Test against different environment
.\stress-test.ps1 -BaseUrl "http://localhost:8080"
```

## 📊 Performance Expectations

### Light Load (25 users, 1 minute)
- ~25,000 total requests
- Should maintain 95%+ success rate
- API should remain responsive

### Medium Load (50 users, 3 minutes)
- ~150,000 total requests
- Should maintain 90%+ success rate
- Some response time degradation expected

### Heavy Load (100 users, 5 minutes - DEFAULT)
- ~250,000 total requests
- Should maintain 70%+ success rate
- Significant resource usage expected

### EXTREME Load (200 users, 10 minutes)
- ~1,000,000+ total requests
- May push system to breaking point
- Use only if you want to find absolute limits

## 🖥️ System Requirements

### Minimum for Testing
- 8GB RAM
- 4 CPU cores
- Docker with 4GB allocated memory

### Recommended for Heavy Load
- 16GB+ RAM
- 8+ CPU cores
- Docker with 8GB+ allocated memory
- SSD storage for database

## 📈 Monitoring During Test

The script provides real-time monitoring:
- Active/completed/failed job counts
- Live API health status
- Elapsed time tracking

### Additional Monitoring Commands
```powershell
# Monitor Docker resources in separate terminal
docker stats

# Monitor API logs
docker-compose logs -f api

# Monitor database connections
docker-compose exec postgres psql -U postgres -d scalable_backend -c "SELECT count(*) FROM pg_stat_activity;"

# Monitor Redis performance
docker-compose exec redis redis-cli info stats
```

## 🎯 Interpreting Results

### Success Metrics
- **Registration Success**: >90% = Excellent, >70% = Good, <50% = Needs work
- **Authentication Success**: >95% = Excellent, >80% = Good, <70% = Needs work
- **Overall Success Rate**: >80% = Excellent, >60% = Good, <40% = Needs optimization
- **Recovery Rate**: >90% = Excellent, >70% = Good, <50% = System struggling

### Performance Metrics
- **Requests/Second**: Higher is better (depends on complexity)
- **Requests/User/Minute**: Consistent = Good, Dropping over time = Performance degradation

### System Health Indicators
```
🏥 API Status: healthy = Good
🏥 API: STRUGGLING = System under extreme load
```

## 🔧 Troubleshooting

### Common Issues

#### High Error Rates
```bash
# Check API logs for errors
docker-compose logs api | grep ERROR

# Check if containers are healthy
docker-compose ps
```

#### Database Connection Issues
```bash
# Check PostgreSQL connections
docker-compose exec postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Check PostgreSQL logs
docker-compose logs postgres
```

#### Memory Issues
```bash
# Check container memory usage
docker stats

# Increase Docker memory allocation
# Docker Desktop > Settings > Resources > Memory
```

#### Redis Connection Issues
```bash
# Check Redis status
docker-compose exec redis redis-cli ping

# Check Redis memory usage
docker-compose exec redis redis-cli info memory
```

## 🛡️ Safety Measures

### Built-in Protections
- 15-second timeouts on all requests
- Graceful error handling
- Automatic job cleanup
- Progressive load ramping

### When to Stop the Test
- CPU usage consistently >95%
- Memory usage >90%
- Error rates >80%
- System becomes unresponsive

### Emergency Stop
```powershell
# If script gets stuck, force stop all jobs
Get-Job | Stop-Job
Get-Job | Remove-Job
```

## 📝 Post-Test Analysis

### Essential Commands
```bash
# Check final system state
docker-compose ps
docker stats --no-stream

# Analyze API performance
docker-compose logs api | grep -E "(ERROR|WARN|took|ms)"

# Check database performance
docker-compose exec postgres psql -U postgres -d scalable_backend -c "
SELECT schemaname,tablename,n_tup_ins,n_tup_upd,n_tup_del 
FROM pg_stat_user_tables 
ORDER BY n_tup_ins DESC;"

# Redis statistics
docker-compose exec redis redis-cli info stats | grep -E "(total_commands_processed|keyspace_hits|keyspace_misses)"
```

### Performance Optimization Tips
1. **Database**: Add indexes, optimize queries, connection pooling
2. **Caching**: Implement Redis caching for frequently accessed data
3. **Rate Limiting**: Add rate limiting to prevent abuse
4. **Horizontal Scaling**: Add more API containers
5. **Load Balancing**: Optimize Nginx configuration

## 🎖️ Stress Test Badges

Based on your results, you can claim these badges:

- 🥉 **Bronze**: 50+ users, 70%+ success rate
- 🥈 **Silver**: 100+ users, 80%+ success rate  
- 🥇 **Gold**: 200+ users, 85%+ success rate
- 💎 **Diamond**: 500+ users, 90%+ success rate
- 🔥 **Apocalypse Survivor**: 1000+ users, any success rate

## ⚡ Pro Tips

1. **Start Small**: Begin with 25 users to establish baseline
2. **Monitor Resources**: Keep Docker stats open during test
3. **Save Results**: Screenshot or save the final output
4. **Incremental Testing**: Gradually increase load to find limits
5. **Cool Down**: Let system rest between extreme tests

---

**Remember**: This is an EXTREME stress test. It's designed to find your system's breaking point, not to simulate normal usage. Use responsibly! 🔥 