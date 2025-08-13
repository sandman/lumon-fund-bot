FROM python:3.12-slim

WORKDIR /app

COPY docling/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Entrypoint script
RUN echo '#!/bin/bash\n\
if [ ! -f /data/.initialized ]; then\n\
    echo "Initializing data volume..."\n\
    cp -r /app/data/* /data/ 2>/dev/null || true\n\
    touch /data/.initialized\n\
    echo "Data volume initialized."\n\
fi\n\
cd /app/docling\n\
streamlit run 5-chat.py --server.port="$PORT" --server.address=0.0.0.0' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

EXPOSE 8501

ENTRYPOINT ["/entrypoint.sh"]
