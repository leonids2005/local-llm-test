environment        = "dev"
instance_name      = "llm-server"
machine_type       = "n1-standard-4"
boot_disk_size     = 100  # Increased for LLM models
boot_disk_type     = "pd-standard"
termination_action = "STOP" # Preserve GPU setup and downloaded models (manually stop when not in use)

# Zone selection: Use less busy zones for better GPU spot availability
# If you get ZONE_RESOURCE_POOL_EXHAUSTED, try: us-west1-b, us-east4-c, europe-west4-a
zone = "us-central1-c"

# Security: No public IP, use IAP tunneling + Cloud NAT for outbound access
assign_external_ip = false
enable_cloud_nat   = true  # ~$5-6/month for secure outbound internet access

# T4 GPU for LLM inference
guest_accelerator = {
  type  = "nvidia-tesla-t4"
  count = 1
}

# LLM-specific startup script with GPU support
startup_script = <<-EOF
  #!/bin/bash
  set -e
  export DEBIAN_FRONTEND=noninteractive

  # Update system
  apt-get update
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    pciutils

  # Install NVIDIA drivers for T4 GPU (skip if already installed)
  if ! command -v nvidia-smi &> /dev/null; then
    echo "Installing NVIDIA drivers..."
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | \
      gpg --dearmor -o /usr/share/keyrings/cuda-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64 /" > /etc/apt/sources.list.d/cuda.list
    apt-get update
    apt-get install -y cuda-drivers
  else
    echo "NVIDIA drivers already installed, skipping"
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

  # Pull and run Ollama with GPU support (skip if already running)
  if ! docker ps | grep -q ollama; then
    echo "Starting Ollama container..."
    # Remove stopped container if it exists
    docker rm -f ollama 2>/dev/null || true
    docker run -d \
      --gpus all \
      --name ollama \
      --restart always \
      -p 11434:11434 \
      -v /var/lib/ollama:/root/.ollama \
      ollama/ollama
    # Wait for Ollama to start
    sleep 15
  else
    echo "Ollama container already running, skipping"
  fi

  # Pull a model for testing only if not already present (saves bandwidth on recreates)
  if ! docker exec ollama ollama list | grep -q llama2; then
    echo "Pulling llama2 model (first boot only)..."
    docker exec ollama ollama pull llama2
  else
    echo "llama2 model already present, skipping download"
  fi

  # Optional: Install nginx as reverse proxy (skip if already installed)
  if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
  else
    echo "nginx already installed, skipping"
  fi

  # Log completion
  echo "LLM server with GPU setup completed at $(date)" >> /var/log/llm-setup.log
  echo "GPU Info:" >> /var/log/llm-setup.log
  nvidia-smi >> /var/log/llm-setup.log
EOF

# Allow IAP access (Google's IP range for IAP)
firewall_rules = [
  {
    protocol = "tcp"
    ports    = ["22"]  # SSH via IAP
  }
]

# IAP IP range (required for IAP TCP forwarding)
# This is Google's official IAP range, not public internet
firewall_source_ranges = ["35.235.240.0/20"]

labels = {
  team        = "engineering"
  purpose     = "llm-development"
  cost_center = "research"
}
