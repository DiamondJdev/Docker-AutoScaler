#!/usr/bin/env python3
"""
Auto-scaling service for the scalable backend
Monitors API instances and automatically scales based on load metrics
"""

import time
import logging
import json
import os
import statistics
from datetime import datetime, timedelta
from threading import Thread
from collections import defaultdict, deque

import docker
import requests
from prometheus_client import start_http_server, Gauge, Counter
import schedule

from config import AutoscalerConfig

# Configure logging
logging.basicConfig(
    level=getattr(logging, AutoscalerConfig.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
api_replicas_gauge = Gauge('api_replicas_current', 'Current number of API replicas')
postgres_replicas_gauge = Gauge('postgres_replicas_current', 'Current number of PostgreSQL replicas')
redis_replicas_gauge = Gauge('redis_replicas_current', 'Current number of Redis replicas')
scaling_decisions_counter = Counter('scaling_decisions_total', 'Total scaling decisions', ['service', 'direction'])
cpu_usage_gauge = Gauge('api_cpu_usage_percent', 'API CPU usage percentage')
memory_usage_gauge = Gauge('api_memory_usage_percent', 'API memory usage percentage')
response_time_gauge = Gauge('api_response_time_ms', 'API response time in milliseconds')
error_rate_gauge = Gauge('api_error_rate_percent', 'API error rate percentage')

class MetricsCollector:
    """Collects and stores metrics for scaling decisions"""
    
    def __init__(self):
        self.metrics_history = defaultdict(lambda: deque(maxlen=AutoscalerConfig.PREDICTION_SAMPLES))
        self.last_scaling_action = {}
        
    def add_metric(self, service: str, metric_type: str, value: float):
        """Add a metric value to the history"""
        self.metrics_history[f"{service}_{metric_type}"].append({
            'timestamp': datetime.now(),
            'value': value
        })
        
    def get_trend(self, service: str, metric_type: str) -> str:
        """Analyze trend for a specific metric"""
        key = f"{service}_{metric_type}"
        if len(self.metrics_history[key]) < 3:
            return "stable"
            
        values = [m['value'] for m in list(self.metrics_history[key])[-5:]]
        if len(values) < 3:
            return "stable"
            
        # Simple trend analysis
        recent_avg = statistics.mean(values[-3:])
        older_avg = statistics.mean(values[:-3]) if len(values) > 3 else values[0]
        
        if recent_avg > older_avg * 1.1:
            return "increasing"
        elif recent_avg < older_avg * 0.9:
            return "decreasing"
        else:
            return "stable"
            
    def can_scale(self, service: str) -> bool:
        """Check if enough time has passed since last scaling action"""
        if service not in self.last_scaling_action:
            return True
            
        time_since_last = datetime.now() - self.last_scaling_action[service]
        return time_since_last.seconds >= AutoscalerConfig.COOLDOWN_PERIOD
        
    def record_scaling_action(self, service: str):
        """Record that a scaling action was taken"""
        self.last_scaling_action[service] = datetime.now()

class AutoScaler:
    """Main auto-scaling service"""
    
    def __init__(self):
        self.metrics_collector = MetricsCollector()
        self.running = True
        self.docker_available = False
        
        # Check if Docker is explicitly unavailable
        if os.getenv('DOCKER_UNAVAILABLE'):
            logger.info("Docker explicitly marked as unavailable - running in monitoring-only mode")
            self.docker_client = None
        else:
            # Try to initialize Docker client
            try:
                self.docker_client = docker.from_env(version=AutoscalerConfig.DOCKER_API_VERSION)
                # Test Docker connection
                self.docker_client.ping()
                self.docker_available = True
                logger.info("AutoScaler initialized with Docker access")
            except Exception as e:
                logger.warning(f"Docker access not available: {e}")
                logger.info("Running in monitoring-only mode")
                self.docker_client = None
        
        logger.info(f"Scale up threshold: {AutoscalerConfig.SCALE_UP_THRESHOLD}%")
        logger.info(f"Scale down threshold: {AutoscalerConfig.SCALE_DOWN_THRESHOLD}%")
        logger.info(f"Min replicas: {AutoscalerConfig.MIN_REPLICAS}")
        logger.info(f"Max replicas: {AutoscalerConfig.MAX_REPLICAS}")
        
    def get_service_replicas(self, service_name: str) -> int:
        """Get current number of replicas for a service"""
        if not self.docker_available:
            logger.debug(f"Docker not available, simulating 1 replica for {service_name}")
            return 1
            
        try:
            service = self.docker_client.services.get(service_name)
            return service.attrs['Spec']['Mode']['Replicated']['Replicas']
        except Exception as e:
            logger.error(f"Error getting replicas for {service_name}: {e}")
            return 0
            
    def scale_service(self, service_name: str, target_replicas: int) -> bool:
        """Scale a service to target number of replicas"""
        if not self.docker_available:
            logger.info(f"Would scale {service_name} to {target_replicas} replicas (Docker not available)")
            return False
            
        try:
            service = self.docker_client.services.get(service_name)
            current_replicas = service.attrs['Spec']['Mode']['Replicated']['Replicas']
            
            if current_replicas == target_replicas:
                return True
                
            logger.info(f"Scaling {service_name} from {current_replicas} to {target_replicas} replicas")
            
            service.update(mode={'Replicated': {'Replicas': target_replicas}})
            
            # Record scaling action
            direction = "up" if target_replicas > current_replicas else "down"
            scaling_decisions_counter.labels(service=service_name, direction=direction).inc()
            
            return True
            
        except Exception as e:
            logger.error(f"Error scaling {service_name}: {e}")
            return False
            
    def collect_api_metrics(self) -> dict:
        """Collect metrics from API instances"""
        try:
            response = requests.get(AutoscalerConfig.API_HEALTH_URL, timeout=10)
            if response.status_code == 200:
                health_data = response.json()
                
                # Extract metrics
                metrics = {
                    'healthy': health_data.get('status') == 'healthy',
                    'response_time': response.elapsed.total_seconds() * 1000,  # Convert to ms
                    'memory_usage': 0,  # Will be calculated from container stats
                    'cpu_usage': 0,     # Will be calculated from container stats
                    'error_rate': 0     # Will be calculated from container logs
                }
                
                # Get container stats for CPU and memory (only if Docker is available)
                if self.docker_available:
                    api_containers = self.docker_client.containers.list(
                        filters={'label': 'com.docker.swarm.service.name=scalable-backend-production_api'}
                    )
                else:
                    api_containers = []
                
                if api_containers:
                    total_cpu = 0
                    total_memory = 0
                    
                    for container in api_containers:
                        try:
                            stats = container.stats(stream=False)
                            
                            # Calculate CPU usage
                            cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                                       stats['precpu_stats']['cpu_usage']['total_usage']
                            system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                                          stats['precpu_stats']['system_cpu_usage']
                            
                            if system_delta > 0:
                                cpu_percent = (cpu_delta / system_delta) * 100
                                total_cpu += cpu_percent
                                
                            # Calculate memory usage
                            memory_usage = stats['memory_stats']['usage']
                            memory_limit = stats['memory_stats']['limit']
                            memory_percent = (memory_usage / memory_limit) * 100
                            total_memory += memory_percent
                            
                        except Exception as e:
                            logger.warning(f"Error getting stats for container {container.id}: {e}")
                            
                    if len(api_containers) > 0:
                        metrics['cpu_usage'] = total_cpu / len(api_containers)
                        metrics['memory_usage'] = total_memory / len(api_containers)
                
                return metrics
                
        except Exception as e:
            logger.error(f"Error collecting API metrics: {e}")
            return {
                'healthy': False,
                'response_time': 0,
                'memory_usage': 0,
                'cpu_usage': 0,
                'error_rate': 0
            }
            
    def collect_postgres_metrics(self) -> dict:
        """Collect PostgreSQL metrics"""
        try:
            # For PostgreSQL, we'll check connection count and performance
            # This would typically connect to postgres and run queries
            # For now, we'll simulate based on API load
            
            api_replicas = self.get_service_replicas(AutoscalerConfig.API_SERVICE_NAME)
            estimated_connections = api_replicas * 50  # Estimate based on API instances
            
            return {
                'connections': estimated_connections,
                'connection_utilization': min(estimated_connections / 1000 * 100, 100)  # Max 1000 connections
            }
            
        except Exception as e:
            logger.error(f"Error collecting PostgreSQL metrics: {e}")
            return {'connections': 0, 'connection_utilization': 0}
            
    def collect_redis_metrics(self) -> dict:
        """Collect Redis metrics"""
        try:
            # For Redis, we'll check memory usage and hit rate
            # This would typically connect to redis and get info
            # For now, we'll simulate based on API load
            
            api_replicas = self.get_service_replicas(AutoscalerConfig.API_SERVICE_NAME)
            estimated_memory_usage = min(api_replicas * 10, 80)  # Estimate memory usage
            
            return {
                'memory_usage': estimated_memory_usage,
                'hit_rate': 85  # Simulated hit rate
            }
            
        except Exception as e:
            logger.error(f"Error collecting Redis metrics: {e}")
            return {'memory_usage': 0, 'hit_rate': 0}
            
    def make_scaling_decision(self, metrics: dict, current_replicas: int) -> int:
        """Make scaling decision based on metrics and algorithm"""
        
        if AutoscalerConfig.SCALING_ALGORITHM == "linear":
            return self._linear_scaling_decision(metrics, current_replicas)
        elif AutoscalerConfig.SCALING_ALGORITHM == "exponential":
            return self._exponential_scaling_decision(metrics, current_replicas)
        elif AutoscalerConfig.SCALING_ALGORITHM == "predictive":
            return self._predictive_scaling_decision(metrics, current_replicas)
        else:
            return self._linear_scaling_decision(metrics, current_replicas)
            
    def _linear_scaling_decision(self, metrics: dict, current_replicas: int) -> int:
        """Simple linear scaling based on thresholds"""
        
        cpu_usage = metrics.get('cpu_usage', 0)
        memory_usage = metrics.get('memory_usage', 0)
        response_time = metrics.get('response_time', 0)
        
        # Scale up conditions
        scale_up = (
            cpu_usage > AutoscalerConfig.CPU_SCALE_UP_THRESHOLD or
            memory_usage > AutoscalerConfig.MEMORY_SCALE_UP_THRESHOLD or
            response_time > AutoscalerConfig.RESPONSE_TIME_SCALE_UP_THRESHOLD
        )
        
        # Scale down conditions
        scale_down = (
            cpu_usage < AutoscalerConfig.CPU_SCALE_DOWN_THRESHOLD and
            memory_usage < AutoscalerConfig.MEMORY_SCALE_DOWN_THRESHOLD and
            response_time < AutoscalerConfig.RESPONSE_TIME_SCALE_DOWN_THRESHOLD
        )
        
        if scale_up and current_replicas < AutoscalerConfig.MAX_REPLICAS:
            return current_replicas + 1
        elif scale_down and current_replicas > AutoscalerConfig.MIN_REPLICAS:
            return current_replicas - 1
        else:
            return current_replicas
            
    def _exponential_scaling_decision(self, metrics: dict, current_replicas: int) -> int:
        """Exponential scaling for rapid response to high load"""
        
        cpu_usage = metrics.get('cpu_usage', 0)
        memory_usage = metrics.get('memory_usage', 0)
        
        max_usage = max(cpu_usage, memory_usage)
        
        if max_usage > 90:  # Critical load
            scale_factor = 2
        elif max_usage > AutoscalerConfig.SCALE_UP_THRESHOLD:
            scale_factor = 1.5
        elif max_usage < AutoscalerConfig.SCALE_DOWN_THRESHOLD:
            scale_factor = 0.7
        else:
            return current_replicas
            
        new_replicas = int(current_replicas * scale_factor)
        return max(AutoscalerConfig.MIN_REPLICAS, 
                  min(AutoscalerConfig.MAX_REPLICAS, new_replicas))
                  
    def _predictive_scaling_decision(self, metrics: dict, current_replicas: int) -> int:
        """Predictive scaling based on trends"""
        
        cpu_trend = self.metrics_collector.get_trend('api', 'cpu_usage')
        memory_trend = self.metrics_collector.get_trend('api', 'memory_usage')
        
        cpu_usage = metrics.get('cpu_usage', 0)
        memory_usage = metrics.get('memory_usage', 0)
        
        # Proactive scaling based on trends
        if (cpu_trend == "increasing" or memory_trend == "increasing") and \
           (cpu_usage > 60 or memory_usage > 60):
            return min(current_replicas + 1, AutoscalerConfig.MAX_REPLICAS)
        elif (cpu_trend == "decreasing" and memory_trend == "decreasing") and \
             (cpu_usage < 40 and memory_usage < 40):
            return max(current_replicas - 1, AutoscalerConfig.MIN_REPLICAS)
        else:
            return current_replicas
            
    def scale_api_instances(self):
        """Scale API instances based on metrics"""
        try:
            metrics = self.collect_api_metrics()
            current_replicas = self.get_service_replicas(AutoscalerConfig.API_SERVICE_NAME)
            
            logger.info(f"API Metrics - CPU: {metrics['cpu_usage']:.1f}%, Memory: {metrics['memory_usage']:.1f}%, Response Time: {metrics['response_time']:.1f}ms, Current Replicas: {current_replicas}")
            
            # Store metrics for analysis
            self.metrics_collector.add_metric('api', 'cpu_usage', metrics['cpu_usage'])
            self.metrics_collector.add_metric('api', 'memory_usage', metrics['memory_usage'])
            self.metrics_collector.add_metric('api', 'response_time', metrics['response_time'])
            
            # Update Prometheus metrics
            cpu_usage_gauge.set(metrics['cpu_usage'])
            memory_usage_gauge.set(metrics['memory_usage'])
            response_time_gauge.set(metrics['response_time'])
            api_replicas_gauge.set(current_replicas)
            
            if not self.metrics_collector.can_scale('api'):
                logger.info("API scaling in cooldown period")
                return
                
            target_replicas = self.make_scaling_decision(metrics, current_replicas)
            
            if target_replicas != current_replicas:
                if self.scale_service(AutoscalerConfig.API_SERVICE_NAME, target_replicas):
                    self.metrics_collector.record_scaling_action('api')
                    logger.info(f"API scaled to {target_replicas} replicas (was {current_replicas})")
            else:
                logger.info(f"API scaling: no action needed (current: {current_replicas})")
                
        except Exception as e:
            logger.error(f"Error in API scaling: {e}")
            
    def scale_postgres_instances(self):
        """Scale PostgreSQL instances if needed"""
        try:
            metrics = self.collect_postgres_metrics()
            current_replicas = self.get_service_replicas(AutoscalerConfig.POSTGRES_SERVICE_NAME)
            
            postgres_replicas_gauge.set(current_replicas)
            
            # PostgreSQL scaling is more conservative
            if metrics['connection_utilization'] > 80 and \
               current_replicas < AutoscalerConfig.POSTGRES_MAX_REPLICAS and \
               self.metrics_collector.can_scale('postgres'):
                
                if self.scale_service(AutoscalerConfig.POSTGRES_SERVICE_NAME, current_replicas + 1):
                    self.metrics_collector.record_scaling_action('postgres')
                    logger.info(f"PostgreSQL scaled to {current_replicas + 1} replicas")
                    
        except Exception as e:
            logger.error(f"Error in PostgreSQL scaling: {e}")
            
    def scale_redis_instances(self):
        """Scale Redis instances if needed"""
        try:
            metrics = self.collect_redis_metrics()
            current_replicas = self.get_service_replicas(AutoscalerConfig.REDIS_SERVICE_NAME)
            
            redis_replicas_gauge.set(current_replicas)
            
            # Redis scaling based on memory usage
            if metrics['memory_usage'] > AutoscalerConfig.REDIS_SCALE_UP_MEMORY and \
               current_replicas < AutoscalerConfig.REDIS_MAX_REPLICAS and \
               self.metrics_collector.can_scale('redis'):
               
                if self.scale_service(AutoscalerConfig.REDIS_SERVICE_NAME, current_replicas + 1):
                    self.metrics_collector.record_scaling_action('redis')
                    logger.info(f"Redis scaled to {current_replicas + 1} replicas")
                    
        except Exception as e:
            logger.error(f"Error in Redis scaling: {e}")
            
    def health_check_handler(self):
        """Health check endpoint for the autoscaler"""
        from http.server import HTTPServer, BaseHTTPRequestHandler
        import json
        import socket
        
        class HealthHandler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/health':
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    
                    status = {
                        'status': 'healthy',
                        'timestamp': datetime.now().isoformat(),
                        'services_monitored': [
                            AutoscalerConfig.API_SERVICE_NAME,
                            AutoscalerConfig.POSTGRES_SERVICE_NAME,
                            AutoscalerConfig.REDIS_SERVICE_NAME
                        ],
                        'scaling_algorithm': AutoscalerConfig.SCALING_ALGORITHM,
                        'docker_available': self.server.autoscaler.docker_available,
                        'metrics_port': AutoscalerConfig.METRICS_PORT
                    }
                    
                    self.wfile.write(json.dumps(status).encode())
                else:
                    self.send_response(404)
                    self.end_headers()
                    
            def log_message(self, format, *args):
                pass  # Suppress HTTP logs
        
        max_retries = 5
        retry_delay = 2
        
        for attempt in range(max_retries):
            try:
                # Check if port is available
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(1)
                result = sock.connect_ex(('localhost', AutoscalerConfig.HEALTH_PORT))
                sock.close()
                
                if result == 0:
                    logger.warning(f"Health port {AutoscalerConfig.HEALTH_PORT} is in use, retrying in {retry_delay}s... (attempt {attempt + 1}/{max_retries})")
                    time.sleep(retry_delay)
                    retry_delay *= 2  # Exponential backoff
                    continue
                
                server = HTTPServer(('0.0.0.0', AutoscalerConfig.HEALTH_PORT), HealthHandler)
                server.autoscaler = self
                logger.info(f"Health check server started on port {AutoscalerConfig.HEALTH_PORT}")
                server.serve_forever()
                break
                
            except Exception as e:
                logger.error(f"Health check server attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    logger.error("Failed to start health check server after all retries")
                    # Don't fail the entire autoscaler, just log and continue
                    break
            
    def run_monitoring_cycle(self):
        """Run one monitoring and scaling cycle"""
        logger.info("Running monitoring cycle")
        
        # Scale services
        self.scale_api_instances()
        self.scale_postgres_instances()
        self.scale_redis_instances()
        
    def run(self):
        """Main run loop"""
        logger.info("Starting AutoScaler")
        
        # Start Prometheus metrics server with retry logic
        if AutoscalerConfig.METRICS_ENABLED:
            metrics_started = False
            max_retries = 5
            retry_delay = 2
            
            for attempt in range(max_retries):
                try:
                    start_http_server(AutoscalerConfig.METRICS_PORT)
                    logger.info(f"Metrics server started on port {AutoscalerConfig.METRICS_PORT}")
                    metrics_started = True
                    break
                except Exception as e:
                    logger.error(f"Failed to start metrics server (attempt {attempt + 1}/{max_retries}): {e}")
                    if attempt < max_retries - 1:
                        logger.info(f"Retrying in {retry_delay} seconds...")
                        time.sleep(retry_delay)
                        retry_delay *= 2
                    else:
                        logger.warning("Failed to start metrics server after all retries, continuing without metrics")
            
            if not metrics_started:
                logger.warning("AutoScaler running without Prometheus metrics")
        
        # Start health check server in separate thread
        health_thread = Thread(target=self.health_check_handler, daemon=True)
        health_thread.start()
        
        # Give health server time to start
        time.sleep(2)
        
        # Schedule monitoring cycles
        schedule.every(AutoscalerConfig.CHECK_INTERVAL).seconds.do(self.run_monitoring_cycle)
        
        logger.info("AutoScaler fully initialized and running")
        
        try:
            while self.running:
                schedule.run_pending()
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Shutting down AutoScaler")
            self.running = False
            
        except Exception as e:
            logger.error(f"AutoScaler error: {e}")
            raise

if __name__ == "__main__":
    autoscaler = AutoScaler()
    autoscaler.run() 