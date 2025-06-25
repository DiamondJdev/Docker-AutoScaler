# Auto-scaling Backend Deployment Script (PowerShell)
# This script sets up Docker Swarm and deploys the auto-scaling backend

param(
    [switch]$Force,
    [string]$ScalingAlgorithm = "linear"
)

Write-Host "Auto-scaling Backend Deployment" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-ServiceHealth {
    param([string]$Url, [string]$ServiceName, [int]$MaxRetries = 12, [int]$RetryDelaySeconds = 10)
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Success "$ServiceName is healthy and responding"
                return $true
            }
        } catch {
            Write-Warning "$ServiceName not ready yet, waiting... (attempt $i/$MaxRetries)"
            if ($i -lt $MaxRetries) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    Write-Warning "$ServiceName failed to become healthy within expected time"
    return $false
}

# Check if Docker is installed
try {
    $dockerVersion = docker --version
    Write-Status "Docker is available: $dockerVersion"
} catch {
    Write-Error "Docker is not installed or not accessible. Please install Docker Desktop."
    exit 1
}

# Check if Docker Compose is installed
try {
    $composeVersion = docker-compose --version
    Write-Status "Docker Compose is available: $composeVersion"
} catch {
    Write-Error "Docker Compose is not installed. Please install Docker Compose."
    exit 1
}

# Create .env file if it doesn't exist
if (-not (Test-Path ".env")) {
    Write-Status "Creating .env file from template..."
    Copy-Item "env.example" ".env"
    Write-Success ".env file created"
} else {
    Write-Status ".env file already exists"
}

# Load .env file and export variables for Docker Swarm
Write-Status "Loading environment variables from .env file..."
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^#][^=]*?)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Remove quotes if present
            $value = $value -replace '^[''"]|[''"]$', ''
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
    Write-Success "Environment variables loaded"
} else {
    Write-Warning "No .env file found, using default values"
}

# Check for port conflicts
Write-Status "Checking for port conflicts..."
$portsToCheck = @(80, 3000, 5432, 6379, 8080, 8090)
$conflictingPorts = @()

foreach ($port in $portsToCheck) {
    try {
        $connection = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet
        if ($connection.TcpTestSucceeded) {
            $conflictingPorts += $port
        }
    } catch {
        # Port is available
    }
}

if ($conflictingPorts.Count -gt 0) {
    Write-Warning "The following ports are already in use: $($conflictingPorts -join ', ')"
    Write-Warning "This may cause deployment issues. Consider stopping conflicting services first."
    if (-not $Force) {
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -notmatch '^[Yy]') {
            Write-Host "Deployment cancelled. Use -Force to skip port checks."
            exit 1
        }
    }
}

# Initialize Docker Swarm if not already initialized
$swarmStatus = docker info --format "{{.Swarm.LocalNodeState}}" 2>$null
if ($swarmStatus -ne "active") {
    Write-Status "Initializing Docker Swarm..."
    try {
        docker swarm init 2>$null
        Write-Success "Docker Swarm initialized"
    } catch {
        Write-Warning "Docker Swarm initialization may have failed, but continuing..."
    }
} else {
    Write-Status "Docker Swarm is already active"
}

# Create necessary directories
Write-Status "Creating required directories..."
@("autoscaler", "metrics", "nginx") | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Check if files exist before building
$requiredFiles = @(
    "autoscaler/Dockerfile",
    "autoscaler/autoscaler.py",
    "autoscaler/config.py",
    "autoscaler/requirements.txt",
    "metrics/Dockerfile",
    "metrics/metrics_collector.py",
    "metrics/requirements.txt",
    "nginx/nginx.swarm.conf"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Error "Missing required files:"
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Please ensure all auto-scaling components are properly created." -ForegroundColor Yellow
    exit 1
}

# Build custom images
Write-Status "Building custom images..."

# Build API image
Write-Status "Building API image..."
try {
    docker build -t scalable_backend_api:latest . | Out-Null
    Write-Success "API image built successfully"
} catch {
    Write-Error "Failed to build API image"
    exit 1
}

# Build autoscaler image
if (Test-Path "autoscaler/Dockerfile") {
    Write-Status "Building autoscaler image..."
    try {
        docker build -t autoscaler:latest ./autoscaler | Out-Null
        Write-Success "Autoscaler image built successfully"
    } catch {
        Write-Error "Failed to build autoscaler image"
        exit 1
    }
}

# Build metrics collector image
if (Test-Path "metrics/Dockerfile") {
    Write-Status "Building metrics collector image..."
    try {
        docker build -t metrics_collector:latest ./metrics | Out-Null
        Write-Success "Metrics collector image built successfully"
    } catch {
        Write-Error "Failed to build metrics collector image"
        exit 1
    }
}

Write-Success "All images built successfully"

# Deploy the stack
Write-Status "Deploying auto-scaling stack..."
try {
    $deployOutput = docker stack deploy -c docker-compose.swarm.yml scalable-backend-production 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Stack deployed successfully"
        Write-Host "Deploy output:" -ForegroundColor Gray
        Write-Host $deployOutput -ForegroundColor Gray
    } else {
        Write-Error "Stack deployment failed with exit code $LASTEXITCODE"
        Write-Host "Deploy output:" -ForegroundColor Red
        Write-Host $deployOutput -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Error "Failed to deploy stack: $($_.Exception.Message)"
    exit 1
}

# Wait for services to be ready
Write-Status "Waiting for services to start..."
Start-Sleep -Seconds 15

# Check service status
Write-Status "Checking service status..."
docker service ls --filter label=project=scalable-backend-production

# Check if API is responding
Write-Status "Testing API health..."
$apiHealthy = Test-ServiceHealth -Url "http://localhost/api/health" -ServiceName "API"

if (-not $apiHealthy) {
    Write-Error "API failed to become healthy within expected time"
    Write-Status "Checking service logs..."
    try {
        docker service logs --tail 20 scalable-backend-production_api
    } catch {
        Write-Warning "Could not retrieve API service logs"
    }
    exit 1
}

# Test autoscaler health with retry logic
Write-Status "Testing autoscaler health..."
$autoscalerHealthy = Test-ServiceHealth -Url "http://localhost:8080/health" -ServiceName "Autoscaler" -MaxRetries 15

if (-not $autoscalerHealthy) {
    Write-Warning "Autoscaler may not be fully ready, but continuing deployment"
    Write-Status "Checking autoscaler logs for diagnostics..."
    try {
        docker service logs --tail 30 scalable-backend-production_autoscaler
    } catch {
        Write-Warning "Could not retrieve autoscaler logs"
    }
    
    # Also check if metrics endpoint is available
    Write-Status "Testing autoscaler metrics endpoint..."
    try {
        $metricsResponse = Invoke-WebRequest -Uri "http://localhost:8090/metrics" -TimeoutSec 5 -UseBasicParsing
        if ($metricsResponse.StatusCode -eq 200) {
            Write-Success "Autoscaler metrics endpoint is responding"
        }
    } catch {
        Write-Warning "Autoscaler metrics endpoint not available yet"
    }
    
    # Verify autoscaler configuration
    Write-Status "Verifying autoscaler configuration..."
    try {
        $healthResponse = Invoke-WebRequest -Uri "http://localhost:8080/health" -TimeoutSec 5 -UseBasicParsing
        if ($healthResponse.StatusCode -eq 200) {
            $healthData = $healthResponse.Content | ConvertFrom-Json
            Write-Host "  Autoscaler Algorithm: $($healthData.scaling_algorithm)" -ForegroundColor Cyan
        }
    } catch {
        Write-Warning "Could not verify autoscaler configuration"
    }
}

# Display deployment information
Write-Host ""
Write-Success "Auto-scaling Backend Deployment Complete!"
Write-Host ""

Write-Host "Services Status:" -ForegroundColor Cyan
docker service ls --filter label=project=scalable-backend-production

Write-Host ""
Write-Host "Available Endpoints:" -ForegroundColor Cyan
Write-Host "   - API Health: http://localhost/api/health"
Write-Host "   - API Detailed Health: http://localhost/api/health/detailed"
Write-Host "   - Load Balancer Status: http://localhost/nginx/status"
Write-Host "   - Autoscaler Health: http://localhost:8080/health"
Write-Host "   - Autoscaler Metrics: http://localhost:8090/metrics"
Write-Host "   - Metrics Collector: http://localhost:8091/metrics"

Write-Host ""
Write-Host "Monitoring Commands:" -ForegroundColor Cyan
Write-Host "   - View all services: docker service ls --filter label=project=scalable-backend-production"
Write-Host "   - View API logs: docker service logs scalable-backend-production_api"
Write-Host "   - View autoscaler logs: docker service logs scalable-backend-production_autoscaler"
Write-Host "   - View nginx logs: docker service logs scalable-backend-production_nginx"
Write-Host "   - Scale API manually: docker service scale scalable-backend-production_api=5"

Write-Host ""
Write-Host "Auto-scaling Configuration:" -ForegroundColor Cyan
$minReplicas = [Environment]::GetEnvironmentVariable('MIN_REPLICAS')
if (-not $minReplicas) { $minReplicas = '2' }
$maxReplicas = [Environment]::GetEnvironmentVariable('MAX_REPLICAS')
if (-not $maxReplicas) { $maxReplicas = '10' }
$scaleUpThreshold = [Environment]::GetEnvironmentVariable('SCALE_UP_THRESHOLD')
if (-not $scaleUpThreshold) { $scaleUpThreshold = '60' }
$scaleDownThreshold = [Environment]::GetEnvironmentVariable('SCALE_DOWN_THRESHOLD')
if (-not $scaleDownThreshold) { $scaleDownThreshold = '20' }
$checkInterval = [Environment]::GetEnvironmentVariable('CHECK_INTERVAL')
if (-not $checkInterval) { $checkInterval = '30' }
$cooldownPeriod = [Environment]::GetEnvironmentVariable('COOLDOWN_PERIOD')
if (-not $cooldownPeriod) { $cooldownPeriod = '120' }
$cpuScaleUp = [Environment]::GetEnvironmentVariable('CPU_SCALE_UP_THRESHOLD')
if (-not $cpuScaleUp) { $cpuScaleUp = '60' }
$memoryScaleUp = [Environment]::GetEnvironmentVariable('MEMORY_SCALE_UP_THRESHOLD')
if (-not $memoryScaleUp) { $memoryScaleUp = '60' }
$scalingAlgorithm = [Environment]::GetEnvironmentVariable('SCALING_ALGORITHM')
if (-not $scalingAlgorithm) { $scalingAlgorithm = 'predictive' }

Write-Host "   - Min API replicas: $minReplicas"
Write-Host "   - Max API replicas: $maxReplicas"
Write-Host "   - Scale up threshold: $scaleUpThreshold% general / $cpuScaleUp% CPU / $memoryScaleUp% Memory"
Write-Host "   - Scale down threshold: $scaleDownThreshold%"
Write-Host "   - Check interval: $checkInterval seconds"
Write-Host "   - Cooldown period: $cooldownPeriod seconds"
Write-Host "   - Scaling algorithm: $scalingAlgorithm"

Write-Host ""
Write-Host "Load Testing:" -ForegroundColor Cyan
Write-Host "   - Run light load test: .\stress-test-simple.ps1 -MaxConcurrentUsers 25 -TestDurationMinutes 2"
Write-Host "   - Run medium load test: .\stress-test-simple.ps1 -MaxConcurrentUsers 50 -TestDurationMinutes 3"
Write-Host "   - Run heavy load test: .\stress-test-simple.ps1 -MaxConcurrentUsers 100 -TestDurationMinutes 5"
Write-Host "   - Watch scaling: docker service ls (run repeatedly)"

Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "   - Stop all services: docker stack rm scalable-backend-production"
Write-Host "   - Update service: docker service update scalable-backend-production_api"
Write-Host "   - View swarm nodes: docker node ls"
Write-Host "   - Manual scale up: docker service scale scalable-backend-production_api=5"
Write-Host "   - Manual scale down: docker service scale scalable-backend-production_api=2"

Write-Host ""
Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "   - Auto-scaling Guide: AUTOSCALING_GUIDE.md"
Write-Host "   - Stress Test Guide: STRESS_TEST_README.md"
Write-Host "   - General Testing: TESTING_GUIDE.md"

Write-Host ""
Write-Success "Your auto-scaling backend is ready!"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test the API: curl http://localhost/api/health"
Write-Host "2. Run a load test to see auto-scaling in action"
Write-Host "3. Monitor scaling: docker service ls"
Write-Host "4. Check logs: docker service logs scalable-backend-production_autoscaler"

Write-Host ""
Write-Host "Troubleshooting:" -ForegroundColor Yellow
Write-Host "   - If services aren't starting: docker service ls"
Write-Host "   - Check autoscaler logs: docker service logs -f scalable-backend-production_autoscaler"
Write-Host "   - Check API logs: docker service logs -f scalable-backend-production_api"
Write-Host "   - Restart failed service: docker service update --force [service-name]"
Write-Host "   - Stop everything: docker stack rm scalable-backend-production"
Write-Host "   - Port conflicts: Use -Force flag or stop conflicting services" 