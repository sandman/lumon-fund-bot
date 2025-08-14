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

CMD streamlit run /app/docling/5-chat.py --server.address 0.0.0.0 --server.port $PORT --server.headless true