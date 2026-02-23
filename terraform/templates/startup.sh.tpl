#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Force IPv4 for apt (Cloud NAT doesn't support IPv6)
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# Update system
apt-get update
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  pciutils \
  linux-headers-$(uname -r)

# Install NVIDIA drivers for A100 GPU (skip if already working)
if ! nvidia-smi &> /dev/null; then
  echo "NVIDIA drivers not loaded, installing/configuring..."

  # Add CUDA repository if not present
  if [ ! -f /etc/apt/sources.list.d/cuda.list ]; then
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | \
      gpg --dearmor -o /usr/share/keyrings/cuda-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64 /" > /etc/apt/sources.list.d/cuda.list
    apt-get update
  fi

  # Install drivers if not present
  if ! dpkg -l | grep -q nvidia-driver; then
    echo "Installing NVIDIA drivers..."
    apt-get install -y cuda-drivers
  fi

  # Load the nvidia kernel module if not loaded
  if ! lsmod | grep -q nvidia; then
    echo "Loading NVIDIA kernel modules..."
    modprobe nvidia
  fi
else
  echo "NVIDIA drivers already loaded and working"
fi

# Install NVIDIA Container Toolkit for Docker GPU support (skip if already installed)
if ! command -v nvidia-ctk &> /dev/null; then
  echo "Installing NVIDIA Container Toolkit..."
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  LIST_FILE="/etc/apt/sources.list.d/nvidia-container-toolkit.list"
  TMP_LIST="$(mktemp)"

  curl -fsSL "https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list" \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > "$TMP_LIST"

  if ! grep -qE '^deb\s' "$TMP_LIST"; then
    echo "ERROR: NVIDIA repo list download did not look like an apt source list (possible HTML/error page)." >&2
    head -n 20 "$TMP_LIST" >&2 || true
    exit 1
  fi

  mv "$TMP_LIST" "$LIST_FILE"
  apt-get update
  apt-get install -y nvidia-container-toolkit
else
  echo "NVIDIA Container Toolkit already installed, skipping"
fi

# Install Docker (skip if already installed)
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
else
  echo "Docker already installed, skipping"
fi

# Configure Docker to use NVIDIA runtime (idempotent)
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# Verify GPU is accessible (wait for drivers to load)
echo "Waiting for GPU drivers to initialize..."
for i in {1..30}; do
  if nvidia-smi; then
    echo "GPU initialized successfully"
    break
  fi
  echo "Waiting for GPU drivers to load... ($i/30)"
  sleep 2
done

# Optional: fetch Hugging Face token from Secret Manager for gated/private models.
HF_TOKEN=""
if [ -n "${hf_token_secret_name}" ]; then
  echo "Fetching Hugging Face token from Secret Manager: ${hf_token_secret_name}"
  ACCESS_TOKEN="$(curl -fsS -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
    | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

  if [ -n "$ACCESS_TOKEN" ]; then
    SECRET_RESPONSE="$(curl -fsS \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      "https://secretmanager.googleapis.com/v1/projects/${project_id}/secrets/${hf_token_secret_name}/versions/latest:access" || true)"
    HF_TOKEN="$(printf '%s' "$SECRET_RESPONSE" | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr '_-' '/+' | base64 -d 2>/dev/null || true)"
  fi

  if [ -z "$HF_TOKEN" ]; then
    echo "WARN: Could not fetch hf token from Secret Manager. Continuing without token."
  fi
fi

%{ if inference_engine == "ollama" }
# Pull and run Ollama with GPU support (skip if already running)
if ! docker ps | grep -q ollama; then
  echo "Starting Ollama container..."
  docker rm -f ollama 2>/dev/null || true
  docker run -d \
    --gpus all \
    --name ollama \
    --restart always \
    -p 11434:11434 \
    -v /var/lib/ollama:/root/.ollama \
    ollama/ollama
  sleep 15
else
  echo "Ollama container already running, skipping"
fi

echo "Instance ready. Pull model manually:"
echo "  docker exec ollama ollama pull ${ollama_model}"
%{ endif }

%{ if inference_engine == "vllm" }
# Pull and run vLLM with GPU support (skip if already running)
if ! docker ps | grep -q vllm; then
  echo "Starting vLLM container..."
  docker rm -f vllm 2>/dev/null || true

  mkdir -p /var/cache/huggingface

  if [ -n "$HF_TOKEN" ]; then
    docker run -d \
      --gpus all \
      --name vllm \
      --restart always \
      -p 8000:8000 \
      --ipc=host \
      -v /var/cache/huggingface:/root/.cache/huggingface \
      -e HF_TOKEN="$HF_TOKEN" \
      -e HUGGING_FACE_HUB_TOKEN="$HF_TOKEN" \
      vllm/vllm-openai:nightly \
      ${vllm_model} \
      --tensor-parallel-size ${vllm_tensor_parallel_size} \
      --gpu-memory-utilization ${vllm_gpu_memory_utilization} \
      --max-model-len ${vllm_max_model_len} \
      --trust-remote-code \
      --enable-auto-tool-choice \
      --tool-call-parser ${vllm_tool_call_parser} \
      --reasoning-parser ${vllm_reasoning_parser}
  else
    docker run -d \
      --gpus all \
      --name vllm \
      --restart always \
      -p 8000:8000 \
      --ipc=host \
      -v /var/cache/huggingface:/root/.cache/huggingface \
      vllm/vllm-openai:nightly \
      ${vllm_model} \
      --tensor-parallel-size ${vllm_tensor_parallel_size} \
      --gpu-memory-utilization ${vllm_gpu_memory_utilization} \
      --max-model-len ${vllm_max_model_len} \
      --trust-remote-code \
      --enable-auto-tool-choice \
      --tool-call-parser ${vllm_tool_call_parser} \
      --reasoning-parser ${vllm_reasoning_parser}
  fi
else
  echo "vLLM container already running, skipping"
fi

echo "vLLM API should be available on localhost:8000"
%{ endif }

# Log completion
echo "LLM server with A100 GPU setup completed at $(date)" >> /var/log/llm-setup.log
echo "GPU Info:" >> /var/log/llm-setup.log
nvidia-smi >> /var/log/llm-setup.log
