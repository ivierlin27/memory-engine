# Official Docker Hub image mem0/mem0-api-server is arm64-only.
# Build the Mem0 REST API from source for linux/amd64 (and others).
FROM python:3.12-slim AS prepare
WORKDIR /src
ARG MEM0_GIT_REF=main
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${MEM0_GIT_REF}" https://github.com/mem0ai/mem0.git .

FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=prepare /src/server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir "psycopg[binary]>=3.2" psycopg2-binary
COPY --from=prepare /src/server .
ENV PYTHONUNBUFFERED=1
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
