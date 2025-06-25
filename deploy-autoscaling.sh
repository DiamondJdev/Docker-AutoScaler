#!/bin/bash

# Auto-scaling Backend Deployment Script
# This script sets up Docker Swarm and deploys the auto-scaling backend

set -e

echo "Auto-scaling Backend Deployment"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_status "Docker and Docker Compose are available"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    print_status "Creating .env file from template..."
    cp env.example .env
    print_success ".env file created"
else
    print_status ".env file already exists"
fi

# Initialize Docker Swarm if not already initialized
if ! docker info | grep -q "Swarm: active"; then
    print_status "Initializing Docker Swarm..."
    docker swarm init
    print_success "Docker Swarm initialized"
else
    print_status "Docker Swarm is already active"
fi

# Create necessary directories
print_status "Creating required directories..."
mkdir -p logs
mkdir -p autoscaler
mkdir -p metrics
mkdir -p nginx

# Build custom images
print_status "Building custom images..."

# Build API image
print_status "Building API image..."
docker build -t scalable_backend_api:latest .

# Build autoscaler image
if [ -d "autoscaler" ]; then
    print_status "Building autoscaler image..."
    docker build -t autoscaler:latest ./autoscaler
fi

# Build metrics collector image
if [ -d "metrics" ]; then
    print_status "Building metrics collector image..."
    docker build -t metrics_collector:latest ./metrics
fi

print_success "All images built successfully"

# Deploy the stack
print_status "Deploying auto-scaling stack..."
docker stack deploy -c docker-compose.swarm.yml scalable-backend

print_success "Stack deployed successfully"

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 15

# Check service status
print_status "Checking service status..."
docker service ls

# Check if API is responding
print_status "Testing API health..."
max_retries=12
retry_count=0

while [ $retry_count -lt $max_retries ]; do
    if curl -f http://localhost/api/health &> /dev/null; then
        print_success "API is healthy and responding"
        break
    else
        print_warning "API not ready yet, waiting... (attempt $((retry_count + 1))/$max_retries)"
        sleep 10
        retry_count=$((retry_count + 1))
    fi
done

if [ $retry_count -eq $max_retries ]; then
    print_error "API failed to become healthy within expected time"
    print_status "Checking service logs..."
    docker service logs scalable-backend_api
    exit 1
fi

# Test autoscaler health
print_status "Testing autoscaler health..."
if curl -f http://localhost:8080/health &> /dev/null; then
    print_success "Autoscaler is healthy"
else
    print_warning "Autoscaler may not be ready yet"
fi

# Display deployment information
echo ""
print_success "Auto-scaling Backend Deployment Complete!"
echo ""

echo "Services Status:"
docker service ls

echo ""
echo "Available Endpoints:"
echo "   • API Health: http://localhost/api/health"
echo "   • API Detailed Health: http://localhost/api/health/detailed"
echo "   • Load Balancer Status: http://localhost/nginx/status"
echo "   • Autoscaler Health: http://localhost:8080/health"
echo "   • Metrics (Prometheus): http://localhost:8090/metrics"

echo ""
echo "Monitoring Commands:"
echo "   • View all services: docker service ls"
echo "   • View API logs: docker service logs scalable-backend_api"
echo "   • View autoscaler logs: docker service logs scalable-backend_autoscaler"
echo "   • View nginx logs: docker service logs scalable-backend_nginx"
echo "   • Scale API manually: docker service scale scalable-backend_api=5"

echo ""
echo "Auto-scaling Configuration:"
echo "   • Min API replicas: 2"
echo "   • Max API replicas: 10"
echo "   • Scale up threshold: 80% CPU/Memory"
echo "   • Scale down threshold: 30% CPU/Memory"
echo "   • Check interval: 30 seconds"
echo "   • Cooldown period: 120 seconds"

echo ""
echo "Load Testing:"
echo "   • Run load test: ./stress-test-simple.ps1"
echo "   • Watch scaling: watch 'docker service ls'"

echo ""
echo "Management Commands:"
echo "   • Stop all services: docker stack rm scalable-backend"
echo "   • Update service: docker service update scalable-backend_api"
echo "   • View swarm nodes: docker node ls"

echo ""
print_success "Your auto-scaling backend is ready!" 