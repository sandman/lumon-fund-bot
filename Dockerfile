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


ARG PORT=8080
EXPOSE ${PORT}

RUN echo -e '#!/bin/bash
if [ ! -f "/data/.initialized" ]; then
    echo "Copying database to persistent volume..."
    cp -ar data/* /data/ 2>/dev/null || true
    touch /data/.initialized
fi
exec streamlit run /app/docling/5-chat.py --server.address 0.0.0.0 --server.port ${PORT} --server.headless true
' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]