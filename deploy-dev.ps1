# Development Auto-scaling Backend Deployment Script
# This script deploys a simplified version for development and testing

param(
    [switch]$Force,
    [switch]$Build
)

Write-Host "Auto-scaling Backend - Development Mode" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "This is a simplified version for easier Docker Desktop management" -ForegroundColor Yellow
Write-Host ""

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

# Check Docker
try {
    $dockerVersion = docker --version
    Write-Status "Docker: $dockerVersion"
} catch {
    Write-Error "Docker not found. Please install Docker Desktop."
    exit 1
}

# Check Docker Compose
try {
    $composeVersion = docker-compose --version
    Write-Status "Docker Compose: $composeVersion"
} catch {
    Write-Error "Docker Compose not found."
    exit 1
}

# Create .env if needed
if (-not (Test-Path ".env")) {
    Write-Status "Creating .env file..."
    Copy-Item "env.example" ".env"
    Write-Success ".env file created"
}

# Stop any existing deployment
Write-Status "Stopping any existing containers..."
docker-compose -f docker-compose.dev.yml down --remove-orphans 2>$null

# Build if requested
if ($Build) {
    Write-Status "Building custom images..."
    docker-compose -f docker-compose.dev.yml build
}

# Start the development environment
Write-Status "Starting development environment..."
docker-compose -f docker-compose.dev.yml up -d

# Wait for services
Write-Status "Waiting for services to start..."
Start-Sleep -Seconds 10

# Check API health
Write-Status "Testing API health..."
$maxRetries = 10
$retryCount = 0

while ($retryCount -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost/api/health" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Success "API is healthy!"
            break
        }
    } catch {
        Write-Warning "API not ready yet... (attempt $($retryCount + 1)/$maxRetries)"
        Start-Sleep -Seconds 5
        $retryCount++
    }
}

if ($retryCount -eq $maxRetries) {
    Write-Error "API failed to start properly"
    Write-Status "Checking logs..."
    docker-compose -f docker-compose.dev.yml logs api
    exit 1
}

# Display information
Write-Host ""
Write-Success "Development Environment Ready!"
Write-Host ""

Write-Host "Services:" -ForegroundColor Cyan
docker-compose -f docker-compose.dev.yml ps

Write-Host ""
Write-Host "Available Endpoints:" -ForegroundColor Cyan
Write-Host "   • API: http://localhost/api/health"
Write-Host "   • API Direct: http://localhost:3000/api/health"
Write-Host "   • Autoscaler: http://localhost:8080/health"
Write-Host "   • Metrics: http://localhost:8090/metrics"
Write-Host "   • Database: localhost:5432"
Write-Host "   • Redis: localhost:6379"

Write-Host ""
Write-Host "Docker Desktop:" -ForegroundColor Cyan
Write-Host "   • All containers are grouped under 'auto-scaling-backend' project"
Write-Host "   • Look for containers with prefix 'autoscaling_'"
Write-Host "   • Use Docker Desktop's 'Containers' tab for easy management"

Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "   • View logs: docker-compose -f docker-compose.dev.yml logs -f"
Write-Host "   • Stop all: docker-compose -f docker-compose.dev.yml down"
Write-Host "   • Restart: docker-compose -f docker-compose.dev.yml restart"
Write-Host "   • Rebuild: docker-compose -f docker-compose.dev.yml up --build -d"

Write-Host ""
Write-Host "Testing:" -ForegroundColor Cyan
Write-Host "   • Register user: curl -X POST http://localhost/api/users/register -H 'Content-Type: application/json' -d '{\"email\":\"test@test.com\",\"username\":\"test\",\"password\":\"password123\"}'"
Write-Host "   • Load test: .\stress-test-simple.ps1 -MaxConcurrentUsers 10 -TestDurationMinutes 1"

Write-Host ""
Write-Host "Development Notes:" -ForegroundColor Yellow
Write-Host "   • This is a single-instance setup (no auto-scaling)"
Write-Host "   • For production auto-scaling, use: .\deploy-autoscaling.ps1"
Write-Host "   • All data persists in Docker volumes"
Write-Host "   • Check Docker Desktop for container grouping"

Write-Host ""
Write-Success "Happy developing!" 