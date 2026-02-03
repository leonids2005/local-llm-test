# Examples

This directory contains example configurations for running local LLMs.

## Docker Compose Setup

The [docker-compose.yml](docker-compose.yml) file provides a complete setup with:

- **Ollama**: LLM runtime for running models like Llama 2, Mistral, etc.
- **Open WebUI**: User-friendly web interface for interacting with LLMs
- **Nginx**: Reverse proxy (optional, for production)

### Quick Start

```bash
# Start all services
docker-compose up -d

# Pull a model
docker exec ollama ollama pull llama2

# Access the web interface
# Open http://localhost:3000 in your browser

# Test the API
curl http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Why is the sky blue?"
}'

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Available Models

```bash
# Small models (good for testing)
docker exec ollama ollama pull llama2         # 7B parameters
docker exec ollama ollama pull mistral        # 7B parameters
docker exec ollama ollama pull phi            # 2.7B parameters

# Medium models (better quality)
docker exec ollama ollama pull llama2:13b     # 13B parameters
docker exec ollama ollama pull codellama      # Code-specialized

# Large models (requires more RAM)
docker exec ollama ollama pull llama2:70b     # 70B parameters (needs 64GB+ RAM)

# List installed models
docker exec ollama ollama list
```

### Custom Startup Script

To use this docker-compose setup in your GCP instance, add this to your `.tfvars`:

```hcl
startup_script = <<-EOF
  #!/bin/bash
  apt-get update
  apt-get install -y docker.io docker-compose
  systemctl start docker
  systemctl enable docker

  # Download and start docker-compose
  mkdir -p /opt/llm
  cd /opt/llm

  # Create docker-compose.yml (inline)
  cat > docker-compose.yml <<'COMPOSE'
  # Paste the docker-compose.yml content here
  COMPOSE

  docker-compose up -d
EOF
```

## API Examples

### Python Client

```python
import requests
import json

def query_llm(prompt, model="llama2"):
    url = "http://localhost:11434/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False
    }

    response = requests.post(url, json=payload)
    return response.json()['response']

# Example usage
result = query_llm("Explain quantum computing in simple terms")
print(result)
```

### JavaScript/Node.js Client

```javascript
const axios = require('axios');

async function queryLLM(prompt, model = 'llama2') {
  const response = await axios.post('http://localhost:11434/api/generate', {
    model: model,
    prompt: prompt,
    stream: false
  });

  return response.data.response;
}

// Example usage
queryLLM('What is machine learning?')
  .then(result => console.log(result))
  .catch(err => console.error(err));
```

### cURL Example

```bash
# Simple query
curl http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Write a haiku about clouds",
  "stream": false
}'

# With streaming
curl http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Tell me a story",
  "stream": true
}'

# Check available models
curl http://localhost:11434/api/tags
```

## Production Deployment

For production deployments on GCP:

1. **Use the Terraform configuration** in the root directory
2. **Configure firewall rules** to restrict access
3. **Enable HTTPS** with Let's Encrypt or Cloud Load Balancer
4. **Set up monitoring** with Cloud Monitoring
5. **Implement authentication** (OAuth, API keys, etc.)
6. **Configure auto-restart** for services
7. **Set up backups** for model data and configurations

## Model Selection Guide

| Model | Parameters | RAM Required | Use Case |
|-------|-----------|--------------|----------|
| phi | 2.7B | 4GB | Quick tests, simple tasks |
| llama2 | 7B | 8GB | General purpose |
| mistral | 7B | 8GB | Better reasoning |
| llama2:13b | 13B | 16GB | Higher quality |
| codellama | 7B | 8GB | Code generation |
| llama2:70b | 70B | 64GB+ | Maximum quality |

## Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs ollama

# Restart services
docker-compose restart

# Full reset
docker-compose down -v
docker-compose up -d
```

### Out of memory
```bash
# Use smaller model
docker exec ollama ollama pull phi

# Or upgrade instance type in your .tfvars
machine_type = "n1-highmem-8"
```

### Connection refused
```bash
# Check if service is running
docker ps

# Check firewall rules
sudo ufw status

# Test locally first
curl http://localhost:11434/api/tags
```
