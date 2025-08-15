# Use NVIDIA CUDA base image with Ubuntu
FROM nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y nginx software-properties-common net-tools curl && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3.12 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy uv from official image
COPY --from=ghcr.io/astral-sh/uv:0.4.11 /uv /bin/uv

# Create app directory
WORKDIR /app

# Install dependencies using cache mount
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project

COPY ./pyproject.toml ./uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

# Copy the rest of the application
COPY . .

# Create directories for nginx and scripts
RUN mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /app/scripts

# Remove default nginx site
RUN rm -f /etc/nginx/sites-enabled/default

# Copy nginx configuration
COPY nginx.conf /etc/nginx/sites-available/vllm
RUN ln -s /etc/nginx/sites-available/vllm /etc/nginx/sites-enabled/

# Copy startup script
COPY start.sh /app/scripts/start.sh
RUN chmod +x /app/scripts/start.sh

# Expose port
EXPOSE 80

# Start script
CMD ["/app/scripts/start.sh"]