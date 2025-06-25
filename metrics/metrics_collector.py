#!/usr/bin/env python3
"""
Metrics collector for the auto-scaling backend
Collects performance metrics from API, PostgreSQL, and Redis
"""

import time
import logging
import json
import os
from datetime import datetime
from threading import Thread
from http.server import HTTPServer, BaseHTTPRequestHandler

import psycopg2
import redis
import requests
from prometheus_client import start_http_server, Gauge, Counter, Histogram
import schedule

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
api_response_time = Histogram('api_response_time_seconds', 'API response time')
api_requests_total = Counter('api_requests_total', 'Total API requests', ['endpoint', 'method', 'status'])
api_cpu_usage = Gauge('api_cpu_usage_percent', 'API CPU usage percentage')
api_memory_usage = Gauge('api_memory_usage_percent', 'API memory usage percentage')

postgres_connections = Gauge('postgres_connections_active', 'Active PostgreSQL connections')
postgres_max_connections = Gauge('postgres_max_connections', 'Maximum PostgreSQL connections')
postgres_query_time = Histogram('postgres_query_time_seconds', 'PostgreSQL query time')
postgres_locks = Gauge('postgres_locks_total', 'PostgreSQL locks')

redis_memory_usage = Gauge('redis_memory_usage_bytes', 'Redis memory usage in bytes')
redis_keys_total = Gauge('redis_keys_total', 'Total Redis keys')
redis_hit_rate = Gauge('redis_hit_rate_percent', 'Redis cache hit rate')
redis_connected_clients = Gauge('redis_connected_clients', 'Redis connected clients')

class MetricsCollector:
    """Collects metrics from all services"""
    
    def __init__(self):
        self.api_endpoints = os.getenv('API_ENDPOINTS', 'http://api:3000').split(',')
        self.postgres_host = os.getenv('POSTGRES_HOST', 'postgres')
        self.redis_host = os.getenv('REDIS_HOST', 'redis')
        self.collection_interval = int(os.getenv('COLLECTION_INTERVAL', 15))
        
        self.postgres_connection = None
        self.redis_client = None
        
        self._setup_connections()
        
    def _setup_connections(self):
        """Setup database connections"""
        try:
            # PostgreSQL connection
            self.postgres_connection = psycopg2.connect(
                host=self.postgres_host,
                port=5432,
                database=os.getenv('POSTGRES_DB', 'scalable_backend'),
                user=os.getenv('POSTGRES_USER', 'postgres'),
                password=os.getenv('POSTGRES_PASSWORD', 'postgres_password')
            )
            logger.info("Connected to PostgreSQL")
            
        except Exception as e:
            logger.error(f"Failed to connect to PostgreSQL: {e}")
            
        try:
            # Redis connection
            self.redis_client = redis.Redis(
                host=self.redis_host,
                port=6379,
                decode_responses=True
            )
            self.redis_client.ping()
            logger.info("Connected to Redis")
            
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            
    def collect_api_metrics(self):
        """Collect API performance metrics"""
        try:
            for endpoint in self.api_endpoints:
                # Health check
                start_time = time.time()
                try:
                    response = requests.get(f"{endpoint}/api/health", timeout=5)
                    response_time = time.time() - start_time
                    
                    api_response_time.observe(response_time)
                    api_requests_total.labels(
                        endpoint='/api/health',
                        method='GET',
                        status=response.status_code
                    ).inc()
                    
                    if response.status_code == 200:
                        logger.debug(f"API health check successful: {response_time:.3f}s")
                    else:
                        logger.warning(f"API health check failed: {response.status_code}")
                        
                except requests.RequestException as e:
                    logger.error(f"API health check failed: {e}")
                    api_requests_total.labels(
                        endpoint='/api/health',
                        method='GET',
                        status='error'
                    ).inc()
                    
                # Detailed health check
                try:
                    response = requests.get(f"{endpoint}/api/health/detailed", timeout=5)
                    if response.status_code == 200:
                        health_data = response.json()
                        
                        # Extract memory usage if available
                        if 'checks' in health_data and 'memory' in health_data['checks']:
                            memory_info = health_data['checks']['memory']
                            # This would need to be parsed from the actual memory format
                            # For now, we'll simulate
                            
                except requests.RequestException as e:
                    logger.warning(f"Detailed health check failed: {e}")
                    
        except Exception as e:
            logger.error(f"Error collecting API metrics: {e}")
            
    def collect_postgres_metrics(self):
        """Collect PostgreSQL performance metrics"""
        if not self.postgres_connection:
            return
            
        try:
            cursor = self.postgres_connection.cursor()
            
            # Active connections
            cursor.execute("SELECT count(*) FROM pg_stat_activity WHERE state = 'active'")
            active_connections = cursor.fetchone()[0]
            postgres_connections.set(active_connections)
            
            # Max connections
            cursor.execute("SELECT setting FROM pg_settings WHERE name = 'max_connections'")
            max_connections = cursor.fetchone()[0]
            postgres_max_connections.set(int(max_connections))
            
            # Database locks
            cursor.execute("SELECT count(*) FROM pg_locks")
            locks_count = cursor.fetchone()[0]
            postgres_locks.set(locks_count)
            
            # Query performance
            start_time = time.time()
            cursor.execute("SELECT 1")
            query_time = time.time() - start_time
            postgres_query_time.observe(query_time)
            
            cursor.close()
            
            logger.debug(f"PostgreSQL metrics: {active_connections} active connections, {locks_count} locks")
            
        except Exception as e:
            logger.error(f"Error collecting PostgreSQL metrics: {e}")
            # Try to reconnect
            try:
                self.postgres_connection.rollback()
            except:
                self._setup_connections()
                
    def collect_redis_metrics(self):
        """Collect Redis performance metrics"""
        if not self.redis_client:
            return
            
        try:
            # Redis info
            info = self.redis_client.info()
            
            # Memory usage
            used_memory = info.get('used_memory', 0)
            redis_memory_usage.set(used_memory)
            
            # Connected clients
            connected_clients = info.get('connected_clients', 0)
            redis_connected_clients.set(connected_clients)
            
            # Key count
            try:
                db_info = self.redis_client.info('keyspace')
                total_keys = 0
                for db, db_info in db_info.items():
                    if db.startswith('db'):
                        keys = int(db_info.split(',')[0].split('=')[1])
                        total_keys += keys
                redis_keys_total.set(total_keys)
            except:
                redis_keys_total.set(0)
                
            # Cache hit rate
            keyspace_hits = info.get('keyspace_hits', 0)
            keyspace_misses = info.get('keyspace_misses', 0)
            total_requests = keyspace_hits + keyspace_misses
            
            if total_requests > 0:
                hit_rate = (keyspace_hits / total_requests) * 100
                redis_hit_rate.set(hit_rate)
            else:
                redis_hit_rate.set(0)
                
            logger.debug(f"Redis metrics: {used_memory} bytes memory, {connected_clients} clients, {total_keys} keys")
            
        except Exception as e:
            logger.error(f"Error collecting Redis metrics: {e}")
            # Try to reconnect
            try:
                self.redis_client = redis.Redis(
                    host=self.redis_host,
                    port=6379,
                    decode_responses=True
                )
            except:
                pass
                
    def collect_system_metrics(self):
        """Collect system-level metrics"""
        try:
            # This would collect CPU, memory, disk metrics from the host
            # For Docker Swarm, we'd get these from Docker API
            pass
            
        except Exception as e:
            logger.error(f"Error collecting system metrics: {e}")
            
    def collect_all_metrics(self):
        """Collect all metrics in one cycle"""
        logger.debug("Collecting metrics cycle")
        
        self.collect_api_metrics()
        self.collect_postgres_metrics()
        self.collect_redis_metrics()
        self.collect_system_metrics()
        
    def health_check_handler(self):
        """Health check endpoint"""
        class HealthHandler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/health':
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    
                    status = {
                        'status': 'healthy',
                        'timestamp': datetime.now().isoformat(),
                        'service': 'metrics-collector',
                        'collection_interval': self.server.collector.collection_interval
                    }
                    
                    self.wfile.write(json.dumps(status).encode())
                elif self.path == '/metrics/summary':
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    
                    # Return current metrics summary
                    summary = {
                        'timestamp': datetime.now().isoformat(),
                        'api': {
                            'endpoints_monitored': len(self.server.collector.api_endpoints)
                        },
                        'postgres': {
                            'connected': self.server.collector.postgres_connection is not None
                        },
                        'redis': {
                            'connected': self.server.collector.redis_client is not None
                        }
                    }
                    
                    self.wfile.write(json.dumps(summary).encode())
                else:
                    self.send_response(404)
                    self.end_headers()
                    
            def log_message(self, format, *args):
                pass  # Suppress HTTP logs
                
        try:
            server = HTTPServer(('0.0.0.0', 9090), HealthHandler)
            server.collector = self
            server.serve_forever()
        except Exception as e:
            logger.error(f"Health check server error: {e}")
            
    def run(self):
        """Main run loop"""
        logger.info("Starting Metrics Collector")
        logger.info(f"API endpoints: {self.api_endpoints}")
        logger.info(f"Collection interval: {self.collection_interval} seconds")
        
        # Start Prometheus metrics server
        start_http_server(8090)
        logger.info("Prometheus metrics server started on port 8090")
        
        # Start health check server in separate thread
        health_thread = Thread(target=self.health_check_handler, daemon=True)
        health_thread.start()
        
        # Schedule metrics collection
        schedule.every(self.collection_interval).seconds.do(self.collect_all_metrics)
        
        try:
            while True:
                schedule.run_pending()
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Shutting down Metrics Collector")
            
        except Exception as e:
            logger.error(f"Metrics Collector error: {e}")
            raise
        finally:
            # Cleanup connections
            if self.postgres_connection:
                self.postgres_connection.close()
            if self.redis_client:
                self.redis_client.close()

if __name__ == "__main__":
    collector = MetricsCollector()
    collector.run() 