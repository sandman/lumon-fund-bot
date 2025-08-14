FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    rsync \
 && rm -rf /var/lib/apt/lists/*

# Install Python dependencies first
COPY docling/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all project files
COPY . .

# Create entrypoint script using here-doc
RUN cat <<'EOF' > /entrypoint.sh
#!/bin/bash
set -e

# Ensure /data exists
mkdir -p /data

# First-run marker
if [ ! -f /data/.initialized ]; then
    echo "📦 First run: initializing /data volume..."
    touch /data/.initialized
fi

# File sync function
sync_files() {
    local mode="$1"
    echo "🔄 Sync mode: $mode"
    if [ "$mode" = "force" ]; then
        rsync -av --delete /app/data/ /data/ | grep -E "^deleting|/$|^>f"
    else
        rsync -av --ignore-existing /app/data/ /data/ | grep -E "/$|^>f"
    fi
}

# Seeding logic
if [ "$FORCE_SEED" = "true" ]; then
    echo "⚠️  FORCE_SEED enabled — overwriting existing /data files..."
    sync_files force
else
    if [ -d /app/data ]; then
        echo "💾 Normal seeding: adding only new files to /data..."
        sync_files normal
    fi
fi

echo "✅ Data volume ready."

# Start Streamlit on provided $PORT or default 8501
echo "🚀 Starting Streamlit on port ${PORT:-8080}..."
exec streamlit run /app/docling/5-chat.py --server.port=${PORT:-8501} --server.address=0.0.0.0
EOF

RUN chmod +x /entrypoint.sh

ARG PORT=8080
EXPOSE ${PORT}

ENTRYPOINT ["/entrypoint.sh"]
