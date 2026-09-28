# =========================
# Builder stage
# =========================
FROM python:3.11-slim AS builder

WORKDIR /app

# Copy dependency trước để tận dụng Docker cache
COPY requirements.txt .

# Cài dependency vào thư mục riêng
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Copy source code
COPY . .

# =========================
# Runtime stage
# =========================
FROM python:3.11-slim

WORKDIR /app

# Copy các package đã cài từ builder
COPY --from=builder /install /usr/local

# Copy source code
COPY --from=builder /app /app

# Tạo user không phải root
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app

USER appuser

# Cloud sẽ ghi đè biến này nếu cần
ENV PORT=8000

EXPOSE 8000

# Health check vào endpoint /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request, os; urllib.request.urlopen(f'http://127.0.0.1:{os.environ.get(\"PORT\",\"8000\")}/health')"

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
