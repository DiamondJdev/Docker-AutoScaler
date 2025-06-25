FROM python:3.11-alpine

# Install required packages
RUN apk add --no-cache \
    curl \
    docker-cli \
    gcc \
    musl-dev \
    linux-headers \
    su-exec

# Create app directory
WORKDIR /app

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy autoscaler code
COPY autoscaler.py .
COPY config.py .
COPY entrypoint.sh .

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Create non-root user (we'll handle docker group in entrypoint)
RUN adduser -D -u 1000 autoscaler

# Don't create docker group here - entrypoint will handle it dynamically
# Don't switch to non-root user yet - we need Docker socket access
# USER autoscaler

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health', timeout=5)"

# Start autoscaler with entrypoint script
ENTRYPOINT ["./entrypoint.sh"] 