FROM python:3.11-alpine

# Install required packages
RUN apk add --no-cache \
    curl \
    postgresql-client \
    && pip install --no-cache-dir \
    psycopg2-binary \
    redis \
    requests \
    prometheus_client \
    influxdb-client

# Create app directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy metrics collector code
COPY metrics_collector.py .

# Create non-root user
RUN adduser -D metrics
USER metrics

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9090/health || exit 1

# Start metrics collector
CMD ["python", "metrics_collector.py"] 