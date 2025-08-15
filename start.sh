#!/bin/bash

set -e

echo "Starting VLLM multi-GPU setup..."

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found. This container requires NVIDIA GPU support."
    exit 1
fi

# Get number of GPUs
GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)
echo "Detected $GPU_COUNT GPU(s)"

if [ "$GPU_COUNT" -eq 0 ]; then
    echo "ERROR: No GPUs detected"
    exit 1
fi

# Model configuration
MODEL_NAME="mistralai/Voxtral-Mini-3B-2507"
BASE_PORT=8001

# Generate nginx upstream configuration
echo "Configuring nginx for $GPU_COUNT VLLM instances..."
NGINX_UPSTREAM="    least_conn;\n    \n"
for i in $(seq 0 $((GPU_COUNT - 1))); do
    PORT=$((BASE_PORT + i))
    NGINX_UPSTREAM="$NGINX_UPSTREAM    server 127.0.0.1:$PORT max_fails=3 fail_timeout=30s;\n"
done

# Update nginx configuration with dynamic upstream
# Replace everything between 'least_conn;' and the closing '}'
sed -i "/least_conn;/,/server 127.0.0.1:8001.*/{
    /least_conn;/!{
        /server 127.0.0.1:8001.*/!d
    }
    /server 127.0.0.1:8001.*/c\\
$NGINX_UPSTREAM
}" /etc/nginx/sites-available/vllm

# Start nginx
echo "Starting nginx..."
nginx -t
nginx

# Start VLLM instances
echo "Starting $GPU_COUNT VLLM instance(s)..."
for i in $(seq 0 $((GPU_COUNT - 1))); do
    PORT=$((BASE_PORT + i))
    echo "Starting VLLM instance $i on GPU $i, port $PORT"
    
    CUDA_VISIBLE_DEVICES=$i uv run vllm serve "$MODEL_NAME" \
        --tokenizer_mode mistral \
        --config_format mistral \
        --load_format mistral \
        --port $PORT \
        --host 0.0.0.0 &
    
    # Give each instance a moment to start
    sleep 10
done

echo "All VLLM instances started. Waiting for them to become ready..."

# Wait for all instances to be ready
for i in $(seq 0 $((GPU_COUNT - 1))); do
    PORT=$((BASE_PORT + i))
    echo "Waiting for instance on port $PORT..."
    
    # Check if VLLM is responding on the models endpoint
    while ! curl -f -s http://localhost:$PORT/v1/models > /dev/null 2>&1; do
        echo "Instance on port $PORT not ready yet..."
        # Debug: show what's actually running on this port
        echo "Checking if port $PORT is listening..."
        netstat -tuln | grep ":$PORT " || echo "Port $PORT not listening"
        sleep 10
    done
    
    echo "Instance on port $PORT is ready!"
done

echo "All VLLM instances are ready!"
echo "Load balancer is available on port 80"
echo "Direct access to instances available on ports $BASE_PORT-$((BASE_PORT + GPU_COUNT - 1))"

# Keep the container running
wait