#!/bin/bash

# Scalable Backend Docker Setup Script
# This script helps you quickly set up and run the scalable backend

set -e  # Exit on error

echo "Scalable Backend Docker Setup"
echo "================================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp env.example .env
    echo ".env file created. Please review and modify if needed."
else
    echo ".env file already exists."
fi

# Create necessary directories
echo "Creating required directories..."
mkdir -p logs
mkdir -p nginx/conf.d
mkdir -p scripts

# Stop any existing containers
echo "Stopping any existing containers..."
docker-compose down --remove-orphans 2>/dev/null || true

# Build and start services
echo "Building and starting services..."
docker-compose up -d --build

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check service health
echo "Checking service health..."

# Check if API is responding
if curl -f http://localhost/api/health &> /dev/null; then
    echo "API is healthy"
else
    echo "API is not responding"
    echo "Checking logs..."
    docker-compose logs api
fi

# Check if database is ready
if docker-compose exec -T postgres pg_isready -U postgres &> /dev/null; then
    echo "Database is ready"
else
    echo "Database is not ready"
fi

# Check if Redis is ready
if docker-compose exec -T redis redis-cli ping &> /dev/null; then
    echo "Redis is ready"
else
    echo "Redis is not ready"
fi

echo ""
echo "Setup completed!"
echo ""
echo "Service Status:"
docker-compose ps

echo ""
echo "Available endpoints:"
echo "   • API Health: http://localhost/api/health"
echo "   • API Documentation: http://localhost/"
echo "   • Detailed Health: http://localhost/api/health/detailed"

echo ""
echo "Test the API:"
echo "   Register user:"
echo "   curl -X POST http://localhost/api/users/register \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"email\":\"test@example.com\",\"username\":\"testuser\",\"password\":\"password123\"}'"

echo ""
echo "Useful commands:"
echo "   • View logs: docker-compose logs -f"
echo "   • Stop services: docker-compose down"
echo "   • Restart services: docker-compose restart"
echo "   • Scale API: docker-compose up -d --scale api=3"

echo ""
echo "Happy learning with Docker!" 