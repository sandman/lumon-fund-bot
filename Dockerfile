FROM python:3.12-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY docling/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the entire project
COPY . .

# Create entrypoint script that seeds data only once
RUN echo '#!/bin/bash\n\
if [ ! -f /data/.initialized ]; then\n\
    echo "Initializing data volume..."\n\
    cp -r /app/data/* /data/ 2>/dev/null || true\n\
    touch /data/.initialized\n\
    echo "Data volume initialized."\n\
fi\n\
\n\
cd /app/docling\n\
streamlit run 5-chat.py --server.port=$PORT --server.address=0.0.0.0' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Expose port for Railway
EXPOSE 8501

# Use the data volume at runtime
# VOLUME ["/data"]
# Uncomment the above line if you are not using Railway. For Railway, we use the data volume from the Railway dashboard.

ENTRYPOINT ["/entrypoint.sh"]