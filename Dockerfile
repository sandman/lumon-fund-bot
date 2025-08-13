FROM python:3.12-slim

WORKDIR /app

# Install dependencies first for better layer caching
COPY docling/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all repo files
COPY . .

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
mkdir -p /data\n\
\n\
# First run marker\n\
if [ ! -f /data/.initialized ]; then\n\
    echo "📦 First run: initializing /data volume..."\n\
    touch /data/.initialized\n\
fi\n\
\n\
# Function to run rsync with nice logging\n\
sync_files() {\n\
    local mode="$1"\n\
    echo "🔄 Sync mode: $mode"\n\
    if [ "$mode" = "force" ]; then\n\
        rsync -av --delete /app/data/ /data/ | grep -E "^deleting|/$|^>f"\n\
    else\n\
        rsync -av --ignore-existing /app/data/ /data/ | grep -E "/$|^>f"\n\
    fi\n\
}\n\
\n\
# Check for FORCE_SEED env var\n\
if [ "$FORCE_SEED" = "true" ]; then\n\
    echo "⚠️  FORCE_SEED enabled — overwriting existing /data files..."\n\
    sync_files force\n\
else\n\
    if [ -d /app/data ]; then\n\
        echo "💾 Normal seeding: adding only new files to /data..."\n\
        sync_files normal\n\
    fi\n\
fi\n\
\n\
echo "✅ Data volume ready."\n\
\n\
# Start Streamlit from repo code location\n\
cd /app/docling\n\
exec streamlit run 5-chat.py --server.port="$PORT" --server.address=0.0.0.0\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

# Expose Streamlit default port
EXPOSE 8501

ENTRYPOINT ["/entrypoint.sh"]
