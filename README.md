# VLLM Multi-GPU Setup with Nginx Load Balancer

This project provides a Docker-based solution for running multiple VLLM instances (one per GPU) with nginx as a load balancer, providing OpenAI API compatibility.

## Features

- **Multi-GPU Support**: Automatically detects and utilizes all available GPUs
- **Load Balancing**: Nginx load balancer distributes requests across VLLM instances  
- **OpenAI API Compatible**: Drop-in replacement for OpenAI API endpoints
- **Docker-based**: Easy deployment with Docker and docker-compose
- **Audio Model**: Pre-configured for Mistral Voxtral-Mini-3B-2507 (audio transcription)

## Quick Start

### Prerequisites

- Docker with NVIDIA Container Toolkit
- NVIDIA GPUs with CUDA support

### Build and Test

```bash
# Build the Docker image
sudo docker build -t vllm-multi-gpu .

# Run the container (only expose load balancer)
sudo docker run --gpus all -p 8080:80 vllm-multi-gpu

# Or use docker-compose
sudo docker-compose up --build
```

## API Usage

### cURL Examples

```bash
# List available models
curl http://localhost:8080/v1/models

# Audio transcription (upload an audio file)
curl -X POST http://localhost:8080/v1/audio/transcriptions \
  -H "Content-Type: multipart/form-data" \
  -F "file=@audio.wav" \
  -F "model=mistralai/Voxtral-Mini-3B-2507"
```

### Python with OpenAI Client

```python
from openai import OpenAI

# Configure client to use your VLLM instance
client = OpenAI(
    api_key="cant-be-empty",  # VLLM requires a non-empty API key
    base_url="http://localhost:8080/v1/"
)

# Transcribe audio file
audio_file = open("audio.wav", "rb")
transcript = client.audio.transcriptions.create(
    model="mistralai/Voxtral-Mini-3B-2507", 
    file=audio_file
)
print(transcript.text)
```

## Architecture

```
Client --> [Nginx Load Balancer :80] --> [VLLM Instance 1 :8001] --> GPU 0
                                    --> [VLLM Instance 2 :8002] --> GPU 1
                                    --> [VLLM Instance N :800N] --> GPU N-1
```

### Direct Instance Access (Optional)

By default, only the load balancer is exposed. For debugging, you can expose individual instances:

```bash
# Expose individual instances for debugging
sudo docker run --gpus all -p 8080:80 -p 8001-8008:8001-8008 vllm-multi-gpu
```

## Files

- `Dockerfile`: NVIDIA CUDA base image with VLLM and nginx
- `start.sh`: Auto-detects GPUs and starts instances  
- `nginx.conf`: Load balancer configuration with least_conn
- `docker-compose.yml`: Easy deployment
- `pyproject.toml`: Python dependencies with vllm[audio]