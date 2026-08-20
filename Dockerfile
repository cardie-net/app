# syntax=docker/dockerfile:1

ARG FRONTEND_IMAGE=ghcr.io/cardie-net/frontend:latest
ARG BACKEND_IMAGE=ghcr.io/cardie-net/backend:latest

# Stage 1: Prebuilt frontend stage
FROM ${FRONTEND_IMAGE} AS frontend-stage

# Stage 2: Prebuilt backend stage
FROM ${BACKEND_IMAGE} AS backend-stage

# Stage 3: Final unified runtime image
FROM python:3.11-slim
WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js, Caddy, Supervisor, and dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    supervisor \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https && \
    curl -1sLF 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
    curl -1sLF 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && apt-get install -y nodejs caddy && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy backend Python dependencies, binaries, and source code
COPY --from=backend-stage /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=backend-stage /usr/local/bin /usr/local/bin
COPY --from=backend-stage /app /app/backend

# Copy frontend Node.js application
COPY --from=frontend-stage /app /app/frontend

# Copy supervisor and Caddy configurations
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY Caddyfile /etc/caddy/Caddyfile

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
