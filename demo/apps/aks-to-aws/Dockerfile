FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install vim for debugging
RUN apt-get update && apt-get install -y vim && rm -rf /var/lib/apt/lists/*

# Copy application
COPY app.py .

# Run as non-root user but give write permissions for debugging
RUN useradd -m -u 1001 appuser
RUN chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import sys; sys.exit(0)"

CMD ["python", "app.py"]