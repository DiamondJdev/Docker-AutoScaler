import os

class AutoscalerConfig:
    """Configuration for the autoscaler service"""
    
    # Docker settings
    DOCKER_API_VERSION = os.getenv('DOCKER_API_VERSION', '1.41')
    DOCKER_SOCKET = '/var/run/docker.sock'
    
    # Scaling thresholds (percentages)
    SCALE_UP_THRESHOLD = int(os.getenv('SCALE_UP_THRESHOLD', 80))
    SCALE_DOWN_THRESHOLD = int(os.getenv('SCALE_DOWN_THRESHOLD', 30))
    
    # Instance limits
    MIN_REPLICAS = int(os.getenv('MIN_REPLICAS', 2))
    MAX_REPLICAS = int(os.getenv('MAX_REPLICAS', 10))
    
    # Timing settings (seconds)
    CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', 30))
    COOLDOWN_PERIOD = int(os.getenv('COOLDOWN_PERIOD', 120))
    
    # Service names (Docker Swarm stack format)
    API_SERVICE_NAME = 'scalable-backend-production_api'
    POSTGRES_SERVICE_NAME = 'scalable-backend-production_postgres'
    REDIS_SERVICE_NAME = 'scalable-backend-production_redis'
    
    # Monitoring endpoints
    API_HEALTH_URL = 'http://api:3000/api/health/detailed'
    NGINX_STATUS_URL = 'http://nginx/nginx/status'
    
    # Database scaling settings
    POSTGRES_SCALE_UP_CONNECTIONS = 500  # Scale up postgres when connections > this
    POSTGRES_MAX_REPLICAS = 3  # Maximum postgres read replicas
    
    # Redis scaling settings
    REDIS_SCALE_UP_MEMORY = 80  # Scale up redis when memory usage > 80%
    REDIS_MAX_REPLICAS = 2  # Maximum redis instances
    
    # Metrics collection
    METRICS_PORT = 8090
    HEALTH_PORT = 8080
    METRICS_ENABLED = True
    
    # Logging
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    
    # Advanced scaling algorithms
    SCALING_ALGORITHM = os.getenv('SCALING_ALGORITHM', 'linear')  # linear, exponential, predictive
    
    # CPU and Memory thresholds for different scaling algorithms
    CPU_SCALE_UP_THRESHOLD = int(os.getenv('CPU_SCALE_UP_THRESHOLD', 70))
    CPU_SCALE_DOWN_THRESHOLD = int(os.getenv('CPU_SCALE_DOWN_THRESHOLD', 20))
    
    MEMORY_SCALE_UP_THRESHOLD = int(os.getenv('MEMORY_SCALE_UP_THRESHOLD', 80))
    MEMORY_SCALE_DOWN_THRESHOLD = int(os.getenv('MEMORY_SCALE_DOWN_THRESHOLD', 40))
    
    # Response time thresholds (milliseconds)
    RESPONSE_TIME_SCALE_UP_THRESHOLD = int(os.getenv('RESPONSE_TIME_SCALE_UP_THRESHOLD', 1000))
    RESPONSE_TIME_SCALE_DOWN_THRESHOLD = int(os.getenv('RESPONSE_TIME_SCALE_DOWN_THRESHOLD', 200))
    
    # Error rate thresholds (percentages)
    ERROR_RATE_SCALE_UP_THRESHOLD = int(os.getenv('ERROR_RATE_SCALE_UP_THRESHOLD', 5))
    
    # Predictive scaling settings
    PREDICTION_WINDOW = int(os.getenv('PREDICTION_WINDOW', 300))  # 5 minutes
    PREDICTION_SAMPLES = int(os.getenv('PREDICTION_SAMPLES', 10))  # Number of samples for prediction 