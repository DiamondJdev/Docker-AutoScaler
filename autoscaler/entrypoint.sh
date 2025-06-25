#!/bin/sh

# Entrypoint script for autoscaler
# Handles Docker socket permissions gracefully

set -e

echo "Starting autoscaler with Docker socket permission handling..."

# Check if Docker socket exists and is accessible
if [ -S /var/run/docker.sock ]; then
    echo "Docker socket found at /var/run/docker.sock"
    
    # Get the group ID of the docker socket
    DOCKER_SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
    echo "Docker socket group ID: $DOCKER_SOCK_GID"
    
    # Try to create docker group with the socket's GID
    if ! getent group docker > /dev/null 2>&1; then
        echo "Creating docker group with GID $DOCKER_SOCK_GID"
        if addgroup -g $DOCKER_SOCK_GID docker 2>/dev/null; then
            echo "Docker group created successfully"
        else
            echo "Failed to create docker group with specific GID, trying without GID"
            addgroup docker || echo "Docker group creation failed"
        fi
    else
        echo "Docker group already exists"
    fi
    
    # Add autoscaler user to docker group
    if getent group docker > /dev/null 2>&1; then
        echo "Adding autoscaler user to docker group"
        adduser autoscaler docker 2>/dev/null || echo "User already in docker group or add failed"
    fi
    
    # Test Docker access as autoscaler user
    echo "Testing Docker socket access..."
    if su-exec autoscaler docker version > /dev/null 2>&1; then
        echo "✅ Docker access test successful - running as autoscaler user"
        exec su-exec autoscaler python autoscaler.py
    else
        echo "⚠️  Docker access test failed - checking root access"
        if docker version > /dev/null 2>&1; then
            echo "✅ Root Docker access works - running as root (less secure but functional)"
            exec python autoscaler.py
        else
            echo "❌ No Docker access available - running in monitoring-only mode"
            export DOCKER_UNAVAILABLE=true
            exec python autoscaler.py
        fi
    fi
else
    echo "⚠️  Docker socket not found - running in development/monitoring mode"
    export DOCKER_UNAVAILABLE=true
    exec python autoscaler.py
fi 